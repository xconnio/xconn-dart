import "dart:async";

import "package:wampproto/idgen.dart";
import "package:wampproto/messages.dart" as msg;
import "package:wampproto/session.dart";
import "package:wampproto/uris.dart";
import "package:xconn/src/exception.dart";

import "package:xconn/src/helpers.dart";
import "package:xconn/src/types.dart";

class Session {
  Session(this._baseSession) {
    _wampSession = WAMPSession(serializer: _baseSession.serializer());
    Future.microtask(() async {
      while (true) {
        var message = await _baseSession.receive();
        _processIncomingMessage(_wampSession.receive(message));
      }
    });
  }

  final IBaseSession _baseSession;
  late WAMPSession _wampSession;

  final SessionScopeIDGenerator _idGen = SessionScopeIDGenerator();

  int get _nextID => _idGen.next();

  Future<void> close() async {
    var goodbyeMsg = msg.Goodbye({}, closeRealm);
    var data = _wampSession.sendMessage(goodbyeMsg);
    _baseSession.send(data);

    return _goodbyeRequest.future
        .timeout(const Duration(seconds: 10), onTimeout: () async => _baseSession.close())
        .whenComplete(() async => _baseSession.close());
  }

  final Map<int, Completer<Result>> _callRequests = {};
  final Map<int, Function(Result result)> _progressHandlerByRequestID = {};
  final Map<int, RegisterRequest> _registerRequests = {};
  final Map<int, Result Function(Invocation)> _registrations = {};
  final Map<int, UnregisterRequest> _unregisterRequests = {};
  final Map<int, Completer<void>> _publishRequests = {};
  final Map<int, SubscribeRequest> _subscribeRequests = {};
  final Map<int, void Function(Event)> _subscriptions = {};
  final Map<int, UnsubscribeRequest> _unsubscribeRequests = {};
  final Completer<void> _goodbyeRequest = Completer();

  void _processIncomingMessage(msg.Message message) {
    if (message is msg.Result) {
      var progress = message.details["progress"] ?? false;
      if (progress) {
        var progressHandler = _progressHandlerByRequestID[message.requestID];
        if (progressHandler != null) {
          progressHandler(Result(args: message.args, kwargs: message.kwargs));
        }
      } else {
        var request = _callRequests.remove(message.requestID);
        if (request != null) {
          request.complete(Result(args: message.args, kwargs: message.kwargs, details: message.details));
        }
        _progressHandlerByRequestID.remove(message.requestID);
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
        var invocation = Invocation(args: message.args, kwargs: message.kwargs, details: message.details);
        if (message.details["receive_progress"] ?? false) {
          invocation.sendProgress = (args, kwargs) {
            var yield = msg.Yield(message.requestID, args: args, kwargs: kwargs, options: {"progress": true});
            var data = _wampSession.sendMessage(yield);
            _baseSession.send(data);
          };
        }
        msg.Message msgToSend;
        try {
          var result = endpoint(invocation);
          msgToSend = msg.Yield(message.requestID, args: result.args, kwargs: result.kwargs, options: result.details);
        } on ApplicationError catch (e) {
          msgToSend = msg.Error(message.messageType(), message.requestID, e.message, args: e.args, kwargs: e.kwargs);
        } on Exception catch (e) {
          msgToSend =
              msg.Error(message.messageType(), message.requestID, "wamp.error.runtime_error", args: [e.toString()]);
        }

        Object data = _wampSession.sendMessage(msgToSend);
        _baseSession.send(data);
      }
    } else if (message is msg.Unregistered) {
      var request = _unregisterRequests.remove(message.requestID);
      if (request != null) {
        _registrations.remove(request.registrationID);
        request.future.complete();
      }
    } else if (message is msg.Published) {
      var request = _publishRequests.remove(message.requestID);
      if (request != null) {
        request.complete();
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
        endpoint(Event(args: message.args, kwargs: message.kwargs, details: message.details));
      }
    } else if (message is msg.Unsubscribed) {
      var request = _unsubscribeRequests.remove(message.requestID);
      if (request != null) {
        _subscriptions.remove(request.subscriptionId);
        request.future.complete();
      }
    } else if (message is msg.Error) {
      switch (message.msgType) {
        case msg.Call.id:
          var callRequest = _callRequests.remove(message.requestID);
          callRequest?.completeError(
            ApplicationError(message.uri, args: message.args, kwargs: message.kwargs),
          );
          break;

        case msg.Register.id:
          var registerRequest = _registerRequests.remove(message.requestID);
          registerRequest?.future.completeError(
            ApplicationError(message.uri, args: message.args, kwargs: message.kwargs),
          );
          break;

        case msg.Unregister.id:
          var unregisterRequest = _unregisterRequests.remove(message.requestID);
          unregisterRequest?.future.completeError(
            ApplicationError(message.uri, args: message.args, kwargs: message.kwargs),
          );
          break;

        case msg.Subscribe.id:
          var subscribeRequest = _subscribeRequests.remove(message.requestID);
          subscribeRequest?.future.completeError(
            ApplicationError(message.uri, args: message.args, kwargs: message.kwargs),
          );
          break;

        case msg.Unsubscribe.id:
          var unsubscribeRequest = _unsubscribeRequests.remove(message.requestID);
          unsubscribeRequest?.future.completeError(
            ApplicationError(message.uri, args: message.args, kwargs: message.kwargs),
          );
          break;

        case msg.Publish.id:
          var publishRequest = _publishRequests.remove(message.requestID);
          publishRequest?.completeError(
            ApplicationError(message.uri, args: message.args, kwargs: message.kwargs),
          );
          break;

        default:
          throw ProtocolError(wampErrorString(message));
      }
    } else if (message is msg.Goodbye) {
      _goodbyeRequest.complete();
    } else {
      throw ProtocolError("Unexpected message type ${message.runtimeType}");
    }
  }

  Future<Result> call(
    String procedure, {
    List<dynamic>? args,
    Map<String, dynamic>? kwargs,
    Map<String, dynamic>? options,
    Function(Result result)? progressHandler,
  }) {
    var call = msg.Call(_nextID, procedure, args: args, kwargs: kwargs, options: options);

    if (progressHandler != null) {
      call.options["receive_progress"] = true;
      _progressHandlerByRequestID[call.requestID] = progressHandler;
    }

    var completer = Completer<Result>();
    _callRequests[call.requestID] = completer;

    _baseSession.send(_wampSession.sendMessage(call));

    return completer.future;
  }

  Future<Registration> register(
    String procedure,
    Result Function(Invocation invocation) endpoint, {
    Map<String, dynamic>? options,
  }) {
    var register = msg.Register(_nextID, procedure, options: options);

    var completer = Completer<Registration>();
    _registerRequests[register.requestID] = RegisterRequest(completer, endpoint);

    _baseSession.send(_wampSession.sendMessage(register));

    return completer.future;
  }

  Future<void> unregister(Registration reg) {
    var unregister = msg.Unregister(_nextID, reg.registrationID);

    var completer = Completer();
    _unregisterRequests[unregister.requestID] = UnregisterRequest(completer, reg.registrationID);

    _baseSession.send(_wampSession.sendMessage(unregister));

    return completer.future;
  }

  Future<void>? publish(
    String topic, {
    List<dynamic>? args,
    Map<String, dynamic>? kwargs,
    Map<String, dynamic>? options,
  }) {
    var publish = msg.Publish(_nextID, topic, args: args, kwargs: kwargs, options: options);

    _baseSession.send(_wampSession.sendMessage(publish));

    var ack = options?["acknowledge"] ?? false;
    if (ack) {
      var completer = Completer<void>();
      _publishRequests[publish.requestID] = completer;

      return completer.future;
    }

    return null;
  }

  Future<Subscription> subscribe(String topic, void Function(Event event) endpoint, {Map<String, dynamic>? options}) {
    var subscribe = msg.Subscribe(_nextID, topic, options: options);

    var completer = Completer<Subscription>();
    _subscribeRequests[subscribe.requestID] = SubscribeRequest(completer, endpoint);
    _baseSession.send(_wampSession.sendMessage(subscribe));

    return completer.future;
  }

  Future<void> unsubscribe(Subscription sub) {
    var unsubscribe = msg.Unsubscribe(_nextID, sub.subscriptionID);

    var completer = Completer<void>();
    _unsubscribeRequests[unsubscribe.requestID] = UnsubscribeRequest(completer, sub.subscriptionID);
    _baseSession.send(_wampSession.sendMessage(unsubscribe));

    return completer.future;
  }
}
