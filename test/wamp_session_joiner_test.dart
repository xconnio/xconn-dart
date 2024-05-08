import "dart:typed_data";

import "package:test/test.dart";
import "package:wampproto/messages.dart";
import "package:wampproto/serializers.dart";

import "package:xconn/src/helpers.dart";

class TestSerializer implements Serializer {
  @override
  Uint8List serialize(final Message message) {
    return Uint8List.fromList("".codeUnits);
  }

  @override
  Message deserialize(final Object message) {
    return Hello("realm", {}, "", []);
  }
}

void main() {
  test("jsonSubProtocol", () {
    var result = getSubProtocol(JSONSerializer());
    expect(result, equals(jsonSubProtocol));
  });

  test("cborSubProtocol", () {
    var result = getSubProtocol(CBORSerializer());
    expect(result, equals(cborSubProtocol));
  });

  test("msgpackSubProtocol", () {
    var result = getSubProtocol(MsgPackSerializer());
    expect(result, equals(msgpackSubProtocol));
  });

  test("invalidSerializer", () {
    expect(() => getSubProtocol(TestSerializer()), throwsArgumentError);
  });
}
