import "dart:typed_data";

import "package:test/test.dart";
import "package:wamp/src/wamp_session_joiner.dart";
import "package:wampproto/messages.dart";
import "package:wampproto/serializers.dart";

class TestSerializer implements Serializer {
  @override
  Uint8List serialize(final Message message) {
    return Uint8List.fromList("".codeUnits);
  }

  @override
  Message deserialize(final Uint8List message) {
    return Hello("realm", {}, "", []);
  }
}

void main() {
  test("jsonSubProtocol", () {
    var result = getSubProtocol(JSONSerializer());
    expect(result, equals(WAMPSessionJoiner.jsonSubProtocol));
  });

  test("cborSubProtocol", () {
    var result = getSubProtocol(CBORSerializer());
    expect(result, equals(WAMPSessionJoiner.cborSubProtocol));
  });

  test("msgpackSubProtocol", () {
    var result = getSubProtocol(MsgPackSerializer());
    expect(result, equals(WAMPSessionJoiner.msgpackSubProtocol));
  });

  test("invalidSerializer", () {
    expect(() => getSubProtocol(TestSerializer()), throwsArgumentError);
  });
}
