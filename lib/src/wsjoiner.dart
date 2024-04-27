import "dart:async";
import "dart:io";
import "dart:typed_data";

import "package:wamp/src/helpers.dart";
import "package:wamp/src/types.dart";
import "package:wampproto/auth.dart";
import "package:wampproto/joiner.dart";
import "package:wampproto/serializers.dart";

class WAMPSessionJoiner {
  WAMPSessionJoiner(this._authenticator, {Serializer? serializer}) : _serializer = serializer ?? JSONSerializer();

  static const String jsonSubProtocol = "wamp.2.json";
  static const String cborSubProtocol = "wamp.2.cbor";
  static const String msgpackSubProtocol = "wamp.2.msgpack";

  final IClientAuthenticator _authenticator;
  final Serializer _serializer;

  Future<BaseSession> join(String uri, String realm) async {
    // ignore: close_sinks
    var ws = await WebSocket.connect(uri, protocols: [getSubProtocol(_serializer)]);

    final joiner = Joiner(realm, _serializer, _authenticator);
    ws.add(joiner.sendHello());

    var welcomeCompleter = Completer<BaseSession>();

    late StreamSubscription<dynamic> wsStreamSubscription;
    final sessionStreamController = StreamController.broadcast();

    wsStreamSubscription = ws.listen((event) {
      dynamic toSend;
      if (getSubProtocol(_serializer) == jsonSubProtocol) {
        toSend = joiner.receive(Uint8List.fromList((event as String).codeUnits));
      } else {
        toSend = joiner.receive(event);
      }
      if (toSend == null) {
        wsStreamSubscription.onData(sessionStreamController.add);

        BaseSession baseSession = BaseSession(ws, sessionStreamController, joiner.getSessionDetails(), _serializer);
        welcomeCompleter.complete(baseSession);
      } else {
        ws.add(toSend);
      }
    });
    wsStreamSubscription.onDone(() {
      sessionStreamController.stream.isEmpty.then(
        (isEmpty) => {
          if (!isEmpty) {sessionStreamController.close()},
        },
      );
      wsStreamSubscription.cancel();
    });

    return welcomeCompleter.future;
  }
}
