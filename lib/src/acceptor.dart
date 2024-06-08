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
  late StreamSubscription wsStreamSubscription;

  Future<BaseSession> accept(WebSocketChannel ws) async {
    _serializer = getSerializer(ws.protocol);
    Acceptor acceptor = Acceptor(serializer: _serializer, authenticator: _authenticator);

    Completer<BaseSession> completer = Completer<BaseSession>();

    wsStreamSubscription = ws.stream.listen((message) {
      try {
        MapEntry<Object, bool> received = acceptor.receive(message);
        ws.sink.add(received.key);
        if (received.value) {
          if (acceptor.isAborted()) {
            ws.sink.close();
            var abortMessage = _serializer.deserialize(received.key) as Abort;
            completer.completeError(Exception(abortMessage.reason));
          } else {
            wsStreamSubscription
              ..onData(null)
              ..onDone(null);

            var base = BaseSession(ws, wsStreamSubscription, acceptor.getSessionDetails(), _serializer);
            completer.complete(base);
          }
        }
      } on Exception catch (error) {
        ws.sink.close();
        completer.completeError(error);
      }
    });

    return completer.future;
  }
}
