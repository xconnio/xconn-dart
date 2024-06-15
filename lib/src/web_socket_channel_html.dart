import "package:web_socket_channel/html.dart";
import "package:web_socket_channel/web_socket_channel.dart";

WebSocketChannel webSocketChannel(String uri, String serializer) {
  return HtmlWebSocketChannel.connect(Uri.parse(uri), protocols: [serializer]);
}
