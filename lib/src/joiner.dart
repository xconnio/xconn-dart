import "dart:async";

import "package:wampproto/auth.dart";
import "package:wampproto/joiner.dart";
import "package:wampproto/serializers.dart";

import "package:xconn/src/helpers.dart";
import "package:xconn/src/types.dart";
import "package:xconn/src/web_socket_channel_io.dart"
    if (dart.library.html) "package:xconn/src/web_socket_channel_html.dart";

class WAMPSessionJoiner {
  WAMPSessionJoiner({IClientAuthenticator? authenticator, Serializer? serializer}) {
    _serializer = serializer ?? CBORSerializer();
    _authenticator = authenticator ?? AnonymousAuthenticator("");
  }

  late IClientAuthenticator _authenticator;
  late Serializer _serializer;

  Future<BaseSession> join(String uri, String realm, {Duration? keepAliveInterval}) async {
    final channel = webSocketChannel(uri, getSubProtocol(_serializer));

    await channel.ready;

    final peer = WebSocketPeer(channel);

    return joinPeer(peer, realm, _serializer, _authenticator);
  }
}

Future<BaseSession> joinPeer(Peer peer, String realm, Serializer serializer, IClientAuthenticator authenticator) async {
  final j = Joiner(realm, serializer: serializer, authenticator: authenticator);

  final hello = j.sendHello();
  await peer.write(hello);

  while (true) {
    final msg = await peer.read();

    final toSend = j.receive(msg);

    if (toSend == null) {
      final details = j.getSessionDetails();

      return BaseSession(peer, details, serializer);
    }

    await peer.write(toSend);
  }
}
