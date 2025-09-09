import "dart:typed_data";

import "package:test/test.dart";
import "package:wampproto/messages.dart";
import "package:wampproto/serializers.dart";

import "package:xconn/src/helpers.dart";
import "package:xconn/xconn.dart";

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
  test("disconnect detection", () async {
    final session = await connectAnonymous("ws://localhost:8080", "realm1");

    await Future.delayed(const Duration(seconds: 5));

    print(session.isConnected());
    expect(session.isConnected(), isFalse);
  });

  test("getSubProtocol", () {
    // with json Serializer
    var jsonProtocol = getSubProtocol(JSONSerializer());
    expect(jsonProtocol, jsonSubProtocol);

    // with cbor Serializer
    var cborProtocol = getSubProtocol(CBORSerializer());
    expect(cborProtocol, cborSubProtocol);

    // with msgpack Serializer
    var msgpackProtocol = getSubProtocol(MsgPackSerializer());
    expect(msgpackProtocol, msgpackSubProtocol);

    // with invalid Serializer
    expect(() => getSubProtocol(TestSerializer()), throwsArgumentError);
  });

  test("getSerializer", () {
    // with json subProtocol
    var jsonSerializer = getSerializer(jsonSubProtocol);
    expect(jsonSerializer, isA<JSONSerializer>());

    // null should also return jsonSerializer
    var jsonSerializer1 = getSerializer(null);
    expect(jsonSerializer1, isA<JSONSerializer>());

    // with cbor subProtocol
    var cborSerializer = getSerializer(cborSubProtocol);
    expect(cborSerializer, isA<CBORSerializer>());

    // with msgpack subProtocol
    var msgpackSerializer = getSerializer(msgpackSubProtocol);
    expect(msgpackSerializer, isA<MsgPackSerializer>());

    // with invalid subProtocol
    expect(() => getSerializer("abc"), throwsException);
  });

  test("wampErrorString", () {
    // with no args or kwargs
    final error = Error(Register.id, 1, "wamp.error.no_such_procedure");
    var errString = wampErrorString(error);
    expect(errString, "wamp.error.no_such_procedure");

    // with args only
    final errorArgs = Error(Register.id, 1, "wamp.error.no_such_procedure", args: [1, "two"]);
    var errArgsString = wampErrorString(errorArgs);
    expect(errArgsString, "wamp.error.no_such_procedure: 1, two");

    // with kwargs only
    final errorKwArgs = Error(Register.id, 1, "wamp.error.no_such_procedure", kwargs: {"key": "value"});
    var errKwArgsString = wampErrorString(errorKwArgs);
    expect(errKwArgsString, "wamp.error.no_such_procedure: key=value");

    // with args and kwargs
    final errorArgsKwArgs =
        Error(Register.id, 1, "wamp.error.no_such_procedure", args: [1, "two"], kwargs: {"key": "value"});
    var errArgsKwArgsString = wampErrorString(errorArgsKwArgs);
    expect(errArgsKwArgsString, "wamp.error.no_such_procedure: 1, two: key=value");
  });
}
