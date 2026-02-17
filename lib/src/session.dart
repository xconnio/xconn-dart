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
    _baseSession.done.then((_) {
      _markDisconnected();
    });
  }

  final IBaseSession _baseSession;
  late WAMPSession _wampSession;
  bool _isConnected = true;

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

  bool isConnected() {
    return _isConnected;
  }

  void Function()? _onDisconnect;

  void onDisconnect(void Function() callback) {
    _onDisconnect = callback;
  }

  final Map<int, Completer<Result>> _callRequests = {};
  final Map<int, Function(Result result)> _progressHandlers = {};
  final Map<int, Function(List<dynamic>? args, Map<String, dynamic>? kwargs)> _progressFunc = {};
  final Map<int, RegisterRequest> _registerRequests = {};
  final Map<int, Result? Function(Invocation)> _registrations = {};
  final Map<int, UnregisterRequest> _unregisterRequests = {};
  final Map<int, Completer<void>> _publishRequests = {};
  final Map<int, SubscribeRequest> _subscribeRequests = {};
  final Map<int, Map<Subscription, Subscription>> _subscriptions = {};
  final Map<int, UnsubscribeRequest> _unsubscribeRequests = {};
  final Completer<void> _goodbyeRequest = Completer();

  void _processIncomingMessage(msg.Message message) {
    if (message is msg.Result) {
      var progress = message.details["progress"] ?? false;
      if (progress) {
        var progressHandler = _progressHandlers[message.requestID];
        if (progressHandler != null) {
          progressHandler(Result(args: message.args, kwargs: message.kwargs));
        }
      } else {
        var request = _callRequests.remove(message.requestID);
        if (request != null) {
          request.complete(Result(args: message.args, kwargs: message.kwargs, details: message.details));
        }
        _progressHandlers.remove(message.requestID);
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
        var invocation = Invocation(args: message.args, kwargs: message.kwargs, details: message.details);

        bool receiveProgress = message.details["receive_progress"] ?? false;
        bool progress = message.details["progress"] ?? false;
        if (receiveProgress) {
          void progressFunc(args, kwargs) {
            var yield = msg.Yield(message.requestID, args: args, kwargs: kwargs, options: {"progress": true});
            var data = _wampSession.sendMessage(yield);
            _baseSession.send(data);
          }

          invocation.sendProgress = progressFunc;
          if (progress) {
            _progressFunc[message.requestID] = progressFunc;
          }
        }

        if (progress && !receiveProgress) {
          final progressFunction = _progressFunc[message.requestID];

          if (progressFunction != null) {
            invocation.sendProgress = progressFunction;
          }
        }

        if (!progress && !receiveProgress) {
          _progressFunc.remove(message.requestID);
        }

        msg.Message msgToSend;
        try {
          var result = endpoint(invocation);
          if (result == null) {
            return;
          }
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
    if (!_isConnected) {
      return;
    }
    _isConnected = false;

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

  Future<Result> _call(msg.Call call) {
    var completer = Completer<Result>();
    _callRequests[call.requestID] = completer;

    _baseSession.send(_wampSession.sendMessage(call));

    return completer.future;
  }

  Future<Result> call(
    String procedure, {
    List<dynamic>? args,
    Map<String, dynamic>? kwargs,
    Map<String, dynamic>? options,
  }) {
    var call = msg.Call(_nextID, procedure, args: args, kwargs: kwargs, options: options);

    return _call(call);
  }

  Future<Result> callProgress(
    String procedure,
    Function(Result result) progressHandler, {
    List<dynamic>? args,
    Map<String, dynamic>? kwargs,
    Map<String, dynamic>? options,
  }) {
    var call = msg.Call(_nextID, procedure, args: args, kwargs: kwargs, options: options);

    call.options["receive_progress"] = true;
    _progressHandlers[call.requestID] = progressHandler;

    return _call(call);
  }

  Future<Result> callProgressive(String procedure, Progress Function() progressFunc) {
    var progress = progressFunc();
    var call = msg.Call(_nextID, procedure, args: progress.args, kwargs: progress.kwargs, options: progress.options);

    var completer = Completer<Result>();
    _callRequests[call.requestID] = completer;

    _baseSession.send(_wampSession.sendMessage(call));

    var callInProgress = progress.options["progress"] ?? false;
    Future(() {
      while (callInProgress) {
        var prog = progressFunc();

        var call1 = msg.Call(call.requestID, procedure, args: prog.args, kwargs: prog.kwargs, options: prog.options);

        _baseSession.send(_wampSession.sendMessage(call1));

        callInProgress = prog.options["progress"] ?? false;
      }
    });

    return completer.future;
  }

  Future<Result> callProgressiveProgress(
    String procedure,
    Progress Function() progressSender,
    Function(Result result) progressReceiver,
  ) {
    var progress = progressSender();
    var call = msg.Call(_nextID, procedure, args: progress.args, kwargs: progress.kwargs, options: progress.options);

    var completer = Completer<Result>();
    _callRequests[call.requestID] = completer;
    call.options["receive_progress"] = true;
    _progressHandlers[call.requestID] = progressReceiver;
    _baseSession.send(_wampSession.sendMessage(call));

    var callInProgress = progress.options["progress"] ?? false;
    Future(() {
      while (callInProgress) {
        var prog = progressSender();

        var call1 = msg.Call(call.requestID, procedure, args: prog.args, kwargs: prog.kwargs, options: prog.options);

        _baseSession.send(_wampSession.sendMessage(call1));

        callInProgress = prog.options["progress"] ?? false;
      }
    });

    return completer.future;
  }

  Future<Registration> register(
    String procedure,
    Result? Function(Invocation invocation) invocationHandler, {
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
