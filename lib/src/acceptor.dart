import "dart:async";

import "package:wampproto/acceptor.dart";
import "package:wampproto/auth.dart";
import "package:wampproto/messages.dart";
import "package:wampproto/serializers.dart";
import "package:web_socket_channel/web_socket_channel.dart";

import "package:xconn/src/helpers.dart";
import "package:xconn/src/types.dart";

class WAMPSessionAcceptor {
  WAMPSessionAcceptor({IServerAuthenticator? authenticator}) {
    _authenticator = authenticator;
  }

  IServerAuthenticator? _authenticator;
  late Serializer _serializer;

  Future<BaseSession> accept(WebSocketChannel ws) async {
    _serializer = getSerializer(ws.protocol);
    final peer = WebSocketPeer(ws);

    // first message must be HELLO
    final payload = await peer.read();
    final hello = _serializer.deserialize(payload) as Hello;

    return acceptPeer(peer, hello, _serializer, _authenticator);
  }
}

Future<BaseSession> acceptPeer(
    Peer peer, Hello hello, Serializer serializer, IServerAuthenticator? authenticator) async {
  final acceptor = Acceptor(serializer: serializer, authenticator: authenticator);

  var toSend = acceptor.receiveMessage(hello);

  await peer.write(serializer.serialize(toSend!));

  if (toSend.messageType() == Welcome.id) {
    final details = acceptor.getSessionDetails();
    return BaseSession(peer, details, serializer);
  }

  while (true) {
    final payload = await peer.read();

    final result = acceptor.receive(payload);
    final message = result.key;
    final welcomed = result.value;

    await peer.write(message);

    if (welcomed) {
      final details = acceptor.getSessionDetails();
      return BaseSession(peer, details, serializer);
    }
  }
}
