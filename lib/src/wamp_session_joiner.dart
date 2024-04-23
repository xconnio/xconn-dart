import "dart:io";
import "dart:typed_data";

import "package:wampproto/auth.dart";
import "package:wampproto/joiner.dart";
import "package:wampproto/serializers.dart";
import "package:wampproto/session.dart";

String getSubProtocol(Serializer serializer) {
  if (serializer is JSONSerializer) {
    return WAMPSessionJoiner.jsonSubProtocol;
  } else if (serializer is CBORSerializer) {
    return WAMPSessionJoiner.cborSubProtocol;
  } else if (serializer is MsgPackSerializer) {
    return WAMPSessionJoiner.msgpackSubProtocol;
  } else {
    throw ArgumentError("invalid serializer");
  }
}

class WAMPSessionJoiner {
  WAMPSessionJoiner(this._authenticator, {Serializer? serializer}) : _serializer = serializer ?? JSONSerializer();

  static const String jsonSubProtocol = "wamp.2.json";
  static const String cborSubProtocol = "wamp.2.cbor";
  static const String msgpackSubProtocol = "wamp.2.msgpack";

  final IClientAuthenticator _authenticator;
  final Serializer _serializer;
  late WebSocket ws;

  Future<SessionDetails?> join(String uri, String realm) async {
    ws = await WebSocket.connect(uri, protocols: [getSubProtocol(_serializer)]);

    final joiner = Joiner(realm, _serializer, _authenticator);
    ws.add(joiner.sendHello());

    await for (final message in ws) {
      final toSend = joiner.receive(Uint8List.fromList((message as String).codeUnits));
      if (toSend == null) {
        return joiner.getSessionDetails();
      }

      ws.add(toSend);
    }
    return null;
  }
}
