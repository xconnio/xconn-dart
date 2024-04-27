import "package:wamp/wamp_session.dart";
import "package:wampproto/serializers.dart";

String getSubProtocol(Serializer serializer) {
  if (serializer is JSONSerializer) {
    return WAMPSessionJoiner.jsonSubProtocol;
  } else if (serializer is CBORSerializer) {
    return WAMPSessionJoiner.cborSubProtocol;
  } else if (serializer is MsgPackSerializer) {
    return WAMPSessionJoiner.msgpackSubProtocol;
  } else {
    throw ArgumentError("invalid serializer");
  }
}
