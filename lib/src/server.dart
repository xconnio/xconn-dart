import "dart:async";
import "dart:io";

import "package:xconn/exports.dart";
import "package:xconn/src/acceptor.dart";
import "package:xconn/src/helpers.dart";
import "package:xconn/src/types.dart";

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

  Future<void> start(String host, int port) async {
    _httpServer = await HttpServer.bind(host, port);

    await for (final request in _httpServer) {
      var webSocket = await WebSocketTransformer.upgrade(
        request,
        protocolSelector: (supportedProtocols) => protocolSelector(request),
      );

      WAMPSessionAcceptor acceptor = WAMPSessionAcceptor();
      BaseSession baseSession = await acceptor.accept(webSocket);
      _router.attachClient(baseSession);

      _handleWebSocket(baseSession, webSocket);
      acceptor.wsStreamSubscription.onDone(() {
        _router.detachClient(baseSession);
      });
    }
  }

  Future<void> close() async {
    await _router.stop();
    await _httpServer.close(force: true);
  }

  void _handleWebSocket(BaseSession baseSession, WebSocket webSocket) {
    Future.microtask(() async {
      while (webSocket.closeCode == null) {
        var message = await baseSession.receiveMessage();
        await _router.receiveMessage(baseSession, message);
      }
    });
  }
}
