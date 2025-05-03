import "package:web_socket_channel/io.dart";
import "package:web_socket_channel/web_socket_channel.dart";

WebSocketChannel webSocketChannel(String uri, String serializer, {Duration? keepAliveInterval}) {
  return IOWebSocketChannel.connect(Uri.parse(uri), protocols: [serializer], pingInterval: keepAliveInterval);
}
