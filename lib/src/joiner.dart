import "dart:async";

import "package:wampproto/auth.dart";
import "package:wampproto/joiner.dart";
import "package:wampproto/serializers.dart";
import "package:web_socket_channel/web_socket_channel.dart";

import "package:xconn/src/helpers.dart";
import "package:xconn/src/types.dart";
import "package:xconn/src/web_socket_channel_io.dart"
    if (dart.library.html) "package:xconn/src/web_socket_channel_html.dart";

class WAMPSessionJoiner {
  WAMPSessionJoiner({IClientAuthenticator? authenticator, Serializer? serializer}) {
    _serializer = serializer ?? JSONSerializer();
    _authenticator = authenticator;
  }

  IClientAuthenticator? _authenticator;
  late Serializer _serializer;

  Future<BaseSession> join(String uri, String realm) async {
    WebSocketChannel channel = webSocketChannel(uri, getSubProtocol(_serializer));
    await channel.ready;

    final joiner = Joiner(realm, _serializer, _authenticator);
    channel.sink.add(joiner.sendHello());

    var welcomeCompleter = Completer<BaseSession>();

    // ignore: cancel_subscriptions
    late StreamSubscription<dynamic> wsStreamSubscription;

    wsStreamSubscription = channel.stream.listen((event) {
      try {
        var toSend = joiner.receive(event);
        if (toSend == null) {
          wsStreamSubscription
            ..onData(null)
            ..onDone(null);

          BaseSession baseSession = BaseSession(channel, wsStreamSubscription, joiner.getSessionDetails(), _serializer);
          welcomeCompleter.complete(baseSession);
        } else {
          channel.sink.add(toSend);
        }
      } on Exception catch (error) {
        welcomeCompleter.completeError(error);
      }
    });

    return welcomeCompleter.future;
  }
}
