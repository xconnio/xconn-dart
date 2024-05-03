import "dart:async";
import "dart:io";
import "dart:typed_data";

import "package:wamp/exports.dart";
import "package:wamp/src/types.dart";
import "package:wamp/src/wsacceptor.dart";

class Server {
  Server(this.router);

  Router router;

  Future<void> websocketHandler() async {
    var server = await HttpServer.bind(InternetAddress.anyIPv4, 8080);

    await for (final request in server) {
      var webSocket = await WebSocketTransformer.upgrade(request);
      WAMPSessionAcceptor a = WAMPSessionAcceptor();
      BaseSession baseSession = await a.accept(webSocket);
      router.attachClient(baseSession);

      handleWebSocket(baseSession);
    }
  }

  void handleWebSocket(BaseSession baseSession) {
    Future.microtask(() async {
      while (true) {
        var message = await baseSession.receive();
        var decodedMessage = Uint8List.fromList((message as String).codeUnits);
        var msg = baseSession.serializer.deserialize(decodedMessage);
        print(msg.marshal());
        await router.receiveMessage(baseSession, msg);
      }
    });
  }
}
