import "dart:async";
import "dart:io";
import "dart:typed_data";

import "package:wamp/src/helpers.dart";
import "package:wamp/src/types.dart";
import "package:wampproto/acceptor.dart";
import "package:wampproto/auth.dart";
import "package:wampproto/serializers.dart";

class WAMPSessionAcceptor {
  WAMPSessionAcceptor({IServerAuthenticator? authenticator, Serializer? serializer}) {
    _serializer = serializer ?? JSONSerializer();
    _authenticator = authenticator;
  }

  IServerAuthenticator? _authenticator;
  late Serializer _serializer;
  static const String jsonSubProtocol = "wamp.2.json";
  static const String cborSubProtocol = "wamp.2.cbor";
  static const String msgpackSubProtocol = "wamp.2.msgpack";

  Future<BaseSession> accept(WebSocket ws) async {
    Acceptor a = Acceptor(serializer: _serializer, authenticator: _authenticator);

    Completer<BaseSession> completer = Completer<BaseSession>();

    late StreamSubscription<dynamic> wsStreamSubscription;
    final sessionStreamController = StreamController.broadcast();

    wsStreamSubscription = ws.listen((message) {
      dynamic data;
      if (getSubProtocol(_serializer) == jsonSubProtocol) {
        data = Uint8List.fromList((message as String).codeUnits);
      } else {
        data = message;
      }

      MapEntry<Uint8List, bool> received = a.receive(data);
      ws.add(received.key);
      if (received.value) {
        wsStreamSubscription.onData(sessionStreamController.add);
        completer.complete(BaseSession(ws, sessionStreamController, a.getSessionDetails(), _serializer));
        return;
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

    return completer.future;
  }
}
