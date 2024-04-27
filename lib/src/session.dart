import "dart:async";
import "dart:typed_data";

import "package:wamp/src/types.dart";
import "package:wampproto/idgen.dart";
import "package:wampproto/messages.dart";
import "package:wampproto/session.dart";

class Session {
  Session(this.baseSession) {
    wampSession = WAMPSession(serializer: baseSession.serializer);
    Future.microtask(() async {
      while (true) {
        await baseSession.receive().then(
              (value) => processIncomingMessage(wampSession.receive(Uint8List.fromList((value as String).codeUnits))),
            );
      }
    });
  }

  BaseSession baseSession;
  late WAMPSession wampSession;

  final SessionScopeIDGenerator idGen = SessionScopeIDGenerator();

  int get nextID => idGen.next();

  Map<int, Completer<Result>> callRequests = {};

  void processIncomingMessage(Message msg) {
    if (msg is Result) {
      var request = callRequests.remove(msg.requestID);
      if (request != null) {
        request.complete(msg);
      }
    }
  }

  Future<Result> call(
    String procedure, {
    List<dynamic>? args,
    Map<String, dynamic>? kwargs,
    Map<String, dynamic>? options,
  }) {
    var call = Call(nextID, procedure, args: args, kwargs: kwargs, options: options);

    var completer = Completer<Result>();
    callRequests[call.requestID] = completer;

    baseSession.send(wampSession.sendMessage(call));

    return completer.future;
  }
}
