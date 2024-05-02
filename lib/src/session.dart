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

  void _processIncomingMessage(msg.Message message) {
  }
}