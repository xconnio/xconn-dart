import "dart:async";
import "dart:io";

import "package:wampproto/auth.dart";
import "package:web_socket_channel/io.dart";
import "package:web_socket_channel/web_socket_channel.dart";
import "package:xconn/src/acceptor.dart";
import "package:xconn/src/helpers.dart";
import "package:xconn/src/types.dart";
import "package:xconn/xconn.dart";

class Server {
  Server(this._router);

  final Router _router;
  late HttpServer _httpServer;

  List<String> supportedProtocols = [jsonSubProtocol, cborSubProtocol, msgpackSubProtocol];

  String? protocolSelector(HttpRequest request) {
    String? subprotocol = request.headers.value("Sec-WebSocket-Protocol");

    if (subprotocol != null) {
      List<String> subprotocols = subprotocol.split(",");

      subprotocols = subprotocols.map((proto) => proto.trim()).toList();

      for (final String sub in subprotocols) {
        if (supportedProtocols.contains(sub)) {
          return sub;
        }
      }
    }

    return null;
  }

  Future<void> start(String host, int port, {IServerAuthenticator? authenticator}) async {
    _httpServer = await HttpServer.bind(host, port);

    await for (final request in _httpServer) {
      var webSocket = IOWebSocketChannel(
        await WebSocketTransformer.upgrade(
          request,
          protocolSelector: (supportedProtocols) => protocolSelector(request),
        ),
      );
      await webSocket.ready;

      try {
        WAMPSessionAcceptor acceptor = WAMPSessionAcceptor(authenticator: authenticator);
        BaseSession baseSession = await acceptor.accept(webSocket);
        _router.attachClient(baseSession);

        _handleWebSocket(baseSession, webSocket);
        acceptor.wsStreamSubscription.onDone(() {
          _router.detachClient(baseSession);
        });
      } on Exception catch (err) {
        print(err);
      }
    }
  }

  Future<void> close() async {
    await _router.stop();
    await _httpServer.close(force: true);
  }

  void _handleWebSocket(BaseSession baseSession, WebSocketChannel webSocket) {
    Future.microtask(() async {
      while (webSocket.closeCode == null) {
        var message = await baseSession.receiveMessage();
        await _router.receiveMessage(baseSession, message);
      }
    });
  }
}
