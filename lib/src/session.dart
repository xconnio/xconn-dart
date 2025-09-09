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

    Future.microtask(_waitForRouterMessages);
  }

  final IBaseSession _baseSession;
  late WAMPSession _wampSession;
  bool _isConnected = true;

  final SessionScopeIDGenerator _idGen = SessionScopeIDGenerator();

  int get _nextID => _idGen.next();

  final Completer<void> _disconnectCompleter = Completer<void>();
  Future<void> get onDone => _disconnectCompleter.future;

  Future<void> _waitForRouterMessages() async {
    try {
      while (true) {
        final message = await _baseSession.receive();
        _processIncomingMessage(_wampSession.receive(message));
      }
    } catch (_) {
      _markDisconnected();
    }
  }

  Future<void> close() async {
    var goodbyeMsg = msg.Goodbye({}, closeRealm);
    var data = _wampSession.sendMessage(goodbyeMsg);
    _baseSession.send(data);

    return _goodbyeRequest.future
        .timeout(const Duration(seconds: 10), onTimeout: () async => _baseSession.close())
        .whenComplete(() async => _baseSession.close());
  }

  bool isConnected() {
    return _isConnected;
  }

  void Function()? _onDisconnect;

  void onDisconnect(void Function() callback) {
    _onDisconnect = callback;
  }

  final Map<int, Completer<Result>> _callRequests = {};
  final Map<int, RegisterRequest> _registerRequests = {};
  final Map<int, Result Function(Invocation)> _registrations = {};
  final Map<int, UnregisterRequest> _unregisterRequests = {};
  final Map<int, Completer<void>> _publishRequests = {};
  final Map<int, SubscribeRequest> _subscribeRequests = {};
  final Map<int, Map<Subscription, Subscription>> _subscriptions = {};
  final Map<int, UnsubscribeRequest> _unsubscribeRequests = {};
  final Completer<void> _goodbyeRequest = Completer();

  void _processIncomingMessage(msg.Message message) {
    if (message is msg.Result) {
      var request = _callRequests.remove(message.requestID);
      if (request != null) {
        request.complete(Result(args: message.args, kwargs: message.kwargs, details: message.details));
      }
    } else if (message is msg.Registered) {
      var request = _registerRequests.remove(message.requestID);
      if (request != null) {
        _registrations[message.registrationID] = request.endpoint;
        request.future.complete(Registration(message.registrationID, this));
      }
    } else if (message is msg.Invocation) {
      var endpoint = _registrations[message.registrationID];
      if (endpoint != null) {
        msg.Message msgToSend;
        try {
          var result = endpoint(Invocation(args: message.args, kwargs: message.kwargs, details: message.details));
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
        var subscription = Subscription(message.subscriptionID, request.endpoint, this);
        _subscriptions.putIfAbsent(message.subscriptionID, () => {});
        _subscriptions[message.subscriptionID]![subscription] = subscription;

        request.future.complete(subscription);
      }
    } else if (message is msg.Event) {
      var subscriptions = _subscriptions[message.subscriptionID];
      if (subscriptions != null) {
        subscriptions.forEach((_, subscription) {
          subscription.eventHandler(Event(args: message.args, kwargs: message.kwargs, details: message.details));
        });
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
      _markDisconnected();
    } else {
      throw ProtocolError("Unexpected message type ${message.runtimeType}");
    }
  }

  void _markDisconnected() {
    if (!_isConnected) return;
    _isConnected = false;

    if (!_disconnectCompleter.isCompleted) {
      _disconnectCompleter.complete();
    }

    if (_onDisconnect != null) {
      _onDisconnect?.call();
    }

    if (!_goodbyeRequest.isCompleted) {
      _goodbyeRequest.complete();
    }
  }

  int id() {
    return _baseSession.id();
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

  Future<Registration> register(
    String procedure,
    Result Function(Invocation invocation) invocationHandler, {
    Map<String, dynamic>? options,
  }) {
    var register = msg.Register(_nextID, procedure, options: options);

    var completer = Completer<Registration>();
    _registerRequests[register.requestID] = RegisterRequest(completer, invocationHandler);

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

  Future<Subscription> subscribe(String topic, void Function(Event event) eventHandler,
      {Map<String, dynamic>? options}) {
    var subscribe = msg.Subscribe(_nextID, topic, options: options);

    var completer = Completer<Subscription>();
    _subscribeRequests[subscribe.requestID] = SubscribeRequest(completer, eventHandler);
    _baseSession.send(_wampSession.sendMessage(subscribe));

    return completer.future;
  }

  Future<void> unsubscribe(Subscription sub) {
    final subscriptions = _subscriptions[sub.subscriptionID];
    if (subscriptions != null) {
      subscriptions.remove(sub);

      if (subscriptions.isNotEmpty) {
        _subscriptions[sub.subscriptionID] = subscriptions;
        return Future.value();
      }
    }

    var unsubscribe = msg.Unsubscribe(_nextID, sub.subscriptionID);

    var completer = Completer<void>();
    _unsubscribeRequests[unsubscribe.requestID] = UnsubscribeRequest(completer, sub.subscriptionID);
    _baseSession.send(_wampSession.sendMessage(unsubscribe));

    return completer.future;
  }
}
