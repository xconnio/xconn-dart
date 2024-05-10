import "dart:async";
import "dart:io";

import "package:wampproto/acceptor.dart";
import "package:wampproto/auth.dart";
import "package:wampproto/serializers.dart";

import "package:xconn/src/helpers.dart";
import "package:xconn/src/types.dart";

class WAMPSessionAcceptor {
  WAMPSessionAcceptor({IServerAuthenticator? authenticator}) {
    _authenticator = authenticator;
  }

  IServerAuthenticator? _authenticator;
  late Serializer _serializer;

  Future<BaseSession> accept(WebSocket ws) async {
    _serializer = getSerializer(ws.protocol);
    Acceptor acceptor = Acceptor(serializer: _serializer, authenticator: _authenticator);

    Completer<BaseSession> completer = Completer<BaseSession>();

    // ignore: cancel_subscriptions
    late StreamSubscription<dynamic> wsStreamSubscription;

    wsStreamSubscription = ws.listen((message) {
      MapEntry<Object, bool> received = acceptor.receive(message);
      ws.add(received.key);
      if (received.value) {
        wsStreamSubscription
          ..onData(null)
          ..onDone(null);

        var base = BaseSession(ws, wsStreamSubscription, acceptor.getSessionDetails(), _serializer);
        completer.complete(base);
      }
    });

    return completer.future;
  }
}
