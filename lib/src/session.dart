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
}
