import "dart:async";
import "dart:typed_data";

import "package:wamp/src/types.dart";
import "package:wampproto/idgen.dart";
import "package:wampproto/messages.dart" as msg;
import "package:wampproto/session.dart";

class Session {
  Session(this._baseSession) {
    _wampSession = WAMPSession(serializer: _baseSession.serializer);
    Future.microtask(() async {
      while (true) {
        var message = await _baseSession.receive();
        var decodedMessage = Uint8List.fromList((message as String).codeUnits);
        _processIncomingMessage(_wampSession.receive(decodedMessage));
      }
    });
  }

  final BaseSession _baseSession;
  late WAMPSession _wampSession;

  final SessionScopeIDGenerator _idGen = SessionScopeIDGenerator();

  int get _nextID => _idGen.next();

  Future<void> close() async {
    await _baseSession.close();
  }

  final Map<int, Completer<Result>> _callRequests = {};
  final Map<int, RegisterRequest> _registerRequests = {};
  final Map<int, Result Function(Invocation)> _registrations = {};
  final Map<int, UnregisterRequest> _unregisterRequests = {};
  final Map<int, Completer<Published>> _publishRequests = {};
  final Map<int, SubscribeRequest> _subscribeRequests = {};
  final Map<int, void Function(Event)> _subscriptions = {};

  void _processIncomingMessage(msg.Message message) {
    if (message is msg.Result) {
      var request = _callRequests.remove(message.requestID);
      if (request != null) {
        request.complete(Result(args: message.args, kwargs: message.kwargs, options: message.options));
      }
    } else if (message is msg.Registered) {
      var request = _registerRequests.remove(message.requestID);
      if (request != null) {
        _registrations[message.registrationID] = request.endpoint;
        request.future.complete(Registration(message.registrationID));
      }
    } else if (message is msg.Invocation) {
      var endpoint = _registrations[message.registrationID];
      if (endpoint != null) {
        Result result = endpoint(Invocation(args: message.args, kwargs: message.kwargs, options: message.options));
        Uint8List data = _wampSession.sendMessage(
          msg.Yield(message.requestID, args: result.args, kwargs: result.kwargs, options: result.options),
        );
        _baseSession.send(data);
      }
    } else if (message is msg.UnRegistered) {
      var request = _unregisterRequests.remove(message.requestID);
      if (request != null) {
        _registrations.remove(request.registrationID);
        request.future.complete();
      }
    } else if (message is msg.Published) {
      var request = _publishRequests.remove(message.requestID);
      if (request != null) {
        request.complete(Published());
      }
    } else if (message is msg.Subscribed) {
      var request = _subscribeRequests.remove(message.requestID);
      if (request != null) {
        _subscriptions[message.subscriptionID] = request.endpoint;
        request.future.complete(Subscription(message.subscriptionID));
      }
    } else if (message is msg.Event) {
      var endpoint = _subscriptions[message.subscriptionID];
      if (endpoint != null) {
        endpoint(Event(args: message.args, kwargs: message.kwargs, options: message.options));
      }
    }
  }

  Future<Result> call(
    String procedure, {
    List<dynamic>? args,
    Map<String, dynamic>? kwargs,
    Map<String, dynamic>? options,
  }) {
    var call = msg.Call(_nextID, procedure, args: args, kwargs: kwargs, options: options);

    var completer = Completer<Result>();
    _callRequests[call.requestID] = completer;

    _baseSession.send(_wampSession.sendMessage(call));

    return completer.future;
  }

  Future<Registration> register(String procedure, Result Function(Invocation) endpoint) {
    var register = msg.Register(_nextID, procedure);

    var completer = Completer<Registration>();
    _registerRequests[register.requestID] = RegisterRequest(completer, endpoint);

    _baseSession.send(_wampSession.sendMessage(register));

    return completer.future;
  }

  Future<void> unregister(Registration reg) {
    var unregister = msg.UnRegister(_nextID, reg.registrationID);

    var completer = Completer();
    _unregisterRequests[unregister.requestID] = UnregisterRequest(completer, reg.registrationID);

    _baseSession.send(_wampSession.sendMessage(unregister));

    return completer.future;
  }

  Future<Published>? publish(
    String topic, {
    List<dynamic>? args,
    Map<String, dynamic>? kwargs,
    Map<String, dynamic>? options,
  }) {
    var publish = msg.Publish(_nextID, topic, args: args, kwargs: kwargs, options: options);

    var completer = Completer<Published>();
    _publishRequests[publish.requestID] = completer;
    _baseSession.send(_wampSession.sendMessage(publish));

    if (options != null && options["acknowledge"]) {
      return completer.future;
    }

    return null;
  }

  Future<Subscription> subscribe(String topic, void Function(Event) endpoint) {
    var subscribe = msg.Subscribe(_nextID, topic);

    var completer = Completer<Subscription>();
    _subscribeRequests[subscribe.requestID] = SubscribeRequest(completer, endpoint);
    _baseSession.send(_wampSession.sendMessage(subscribe));

    return completer.future;
  }
}
