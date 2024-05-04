import "dart:async";
import "dart:io";

import "package:wamp/exports.dart";
import "package:wamp/src/types.dart";
import "package:wamp/src/wsacceptor.dart";

class Server {
  Server(this.router);

  Router router;

  Future<void> start(String host, int port) async {
    var server = await HttpServer.bind(host, port);

    await for (final request in server) {
      var webSocket = await WebSocketTransformer.upgrade(request);
      WAMPSessionAcceptor a = WAMPSessionAcceptor();
      BaseSession baseSession = await a.accept(webSocket);
      router.attachClient(baseSession);

      _handleWebSocket(baseSession, webSocket);
    }
  }

  void _handleWebSocket(BaseSession baseSession, WebSocket webSocket) {
    Future.microtask(() async {
      while (webSocket.closeCode == null) {
        var message = await baseSession.receiveMessage();
        await router.receiveMessage(baseSession, message);
      }
    });
  }
}
