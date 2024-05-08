import "package:wampproto/messages.dart";
import "package:wampproto/serializers.dart";

const String jsonSubProtocol = "wamp.2.json";
const String cborSubProtocol = "wamp.2.cbor";
const String msgpackSubProtocol = "wamp.2.msgpack";

String getSubProtocol(Serializer serializer) {
  if (serializer is JSONSerializer) {
    return jsonSubProtocol;
  } else if (serializer is CBORSerializer) {
    return cborSubProtocol;
  } else if (serializer is MsgPackSerializer) {
    return msgpackSubProtocol;
  } else {
    throw ArgumentError("invalid serializer");
  }
}

String wampErrorString(Error err) {
  String errStr = err.uri;
  if (err.args.isNotEmpty) {
    String args = err.args.map((arg) => arg.toString()).join(", ");
    errStr += ": $args";
  }
  if (err.kwargs.isNotEmpty) {
    String kwargs = err.kwargs.entries.map((entry) => "${entry.key}=${entry.value}").join(", ");
    errStr += ": $kwargs";
  }
  return errStr;
}

Serializer getSerializer(String? subprotocol) {
  if (subprotocol == null || subprotocol == jsonSubProtocol) {
    return JSONSerializer();
  } else if (subprotocol == cborSubProtocol) {
    return CBORSerializer();
  } else if (subprotocol == msgpackSubProtocol) {
    return MsgPackSerializer();
  } else {
    throw Exception("invalid websocket subprotocol $subprotocol");
  }
}
