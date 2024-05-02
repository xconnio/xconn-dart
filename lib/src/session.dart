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

  void _processIncomingMessage(msg.Message message) {
    if (message is msg.Result) {
      var request = _callRequests.remove(message.requestID);
      if (request != null) {
        request.complete(Result(args: message.args, kwargs: message.kwargs, options: message.options));
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
}
