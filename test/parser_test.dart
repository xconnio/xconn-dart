import "dart:convert";
import "dart:typed_data";

import "package:test/test.dart";
import "package:xconn/src/parser.dart";

void main() {
  group("Value", () {
    test("Raw", () {
      expect(Value.of(123).raw(), 123);
      expect(Value.of("abc").raw(), "abc");
    });

    group("asString&stringOr", () {
      test("String", () {
        expect(Value.of("hello").asString(), "hello");
        expect(Value.of("world").stringOr("default"), "world");
      });

      test("ThrowsFormatExceptionIfNotString", () {
        expect(() => Value.of(123).asString(), throwsFormatException);
      });

      test("stringOrReturnsDefaultIfNotString", () {
        expect(Value.of(123).stringOr("default"), "default");
      });
    });

    group("asBool&boolOr", () {
      test("Bool", () {
        expect(Value.of(true).asBool(), true);
        expect(Value.of(false).boolOr(true), false);
      });

      test("ThrowsFormatExceptionIfNotBool", () {
        expect(() => Value.of(123).asBool(), throwsFormatException);
      });

      test("boolOrReturnsDefaultIfNotBool", () {
        expect(Value.of(123).boolOr(true), true);
      });
    });

    group("asInt&intOr", () {
      test("Int", () {
        expect(Value.of(42).asInt(), 42);
      });

      test("worksWithDouble", () {
        expect(Value.of(42.9).asInt(), 42);
      });

      test("throwsFormatException", () {
        expect(() => Value.of("x").asInt(), throwsFormatException);
      });

      test("intOrReturnsDefault", () {
        expect(Value.of("x").intOr(99), 99);
      });
    });

    group("asDouble&doubleOr", () {
      test("Double", () {
        expect(Value.of(3.14).asDouble(), 3.14);
      });

      test("Int", () {
        expect(Value.of(10).asDouble(), 10.0);
      });

      test("throwsFormatException", () {
        expect(() => Value.of("x").asDouble(), throwsFormatException);
      });

      test("doubleOrReturnsDefault", () {
        expect(Value.of("x").doubleOr(1.5), 1.5);
      });
    });

    group("asBytes&bytesOr", () {
      test("Uint8List", () {
        final bytes = Uint8List.fromList([1, 2, 3]);
        expect(Value.of(bytes).asBytes(), bytes);
      });

      test("List<int>", () {
        final list = [1, 2, 3];
        expect(Value.of(list).asBytes(), Uint8List.fromList(list));
      });

      test("String", () {
        const s = "abc";
        expect(Value.of(s).asBytes(), utf8.encode(s));
      });

      test("throwsFormatException", () {
        expect(() => Value.of(123).asBytes(), throwsFormatException);
      });

      test("bytesOrReturnsDefault", () {
        final def = Uint8List.fromList([9]);
        expect(Value.of(123).bytesOr(def), def);
      });
    });

    group("decodeInto", () {
      test("decodesJSONIntoTargetType", () {
        final value = Value.of({"name": "Alice", "age": 30});
        final person = value.decodeInto((json) => Person.fromJson(json));

        expect(person.name, "Alice");
        expect(person.age, 30);
      });
    });
  });

  group("ValueList", () {
    test("len", () {
      final list = ValueList.from([1, "a", true]);
      expect(list.len(), 3);
    });

    test("get", () {
      final list = ValueList.from(["x", "y"]);
      expect(list.get(0).asString(), "x");
      expect(list.get(1).asString(), "y");
    });

    test("getThrowsIfOutOfRange", () {
      final list = ValueList.from([]);
      expect(() => list.get(0), throwsFormatException);
    });

    test("getOr", () {
      final list = ValueList.from([1]);
      expect(list.getOr(0, "def").asInt(), 1);
      expect(list.getOr(1, "def").asString(), "def");
    });

    group("string&stringOr", () {
      test("string", () {
        final list = ValueList.from(["hello"]);
        expect(list.asString(0), "hello");
      });

      test("stringOr", () {
        final list = ValueList.from([123]);
        expect(list.stringOr(0, "fallback"), "fallback");
        expect(list.stringOr(1, "fallback"), "fallback");
      });
    });

    group("bool&boolOr", () {
      test("bool", () {
        final list = ValueList.from([true]);
        expect(list.asBool(0), true);
      });

      test("boolOr", () {
        final list = ValueList.from([123]);
        expect(list.boolOr(0, false), false);
      });
    });

    group("int&intOr", () {
      test("int", () {
        final list = ValueList.from([42]);
        expect(list.asInt(0), 42);
      });

      test("intOr", () {
        final list = ValueList.from(["oops"]);
        expect(list.intOr(0, 99), 99);
      });
    });

    group("double&doubleOr", () {
      test("double", () {
        final list = ValueList.from([3.14]);
        expect(list.asDouble(0), 3.14);
      });

      test("doubleOr", () {
        final list = ValueList.from(["oops"]);
        expect(list.doubleOr(0, 1.5), 1.5);
      });
    });

    group("bytes&bytesOr", () {
      test("bytes", () {
        final list = ValueList.from([
          Uint8List.fromList([1, 2])
        ]);
        expect(list.asBytes(0), Uint8List.fromList([1, 2]));
      });

      test("bytesOr", () {
        final def = Uint8List.fromList([9]);
        final list = ValueList.from([123]);
        expect(list.bytesOr(0, def), def);
      });
    });

    test("raw", () {
      final list = ValueList.from([1, "a", true]);
      expect(list.raw(), [1, "a", true]);
    });
  });

  group("Dict", () {
    test("len", () {
      final dict = Dict.from({"a": 1, "b": "x"});
      expect(dict.len(), 2);
    });

    test("get", () {
      final dict = Dict.from({"name": "Alice"});
      expect(dict.get("name").asString(), "Alice");
    });

    test("getThrowsIfMissing", () {
      final dict = Dict.from({});
      expect(() => dict.get("missing"), throwsFormatException);
    });

    test("getOr", () {
      final dict = Dict.from({"a": 42});
      expect(dict.getOr("a", "def").asInt(), 42);
      expect(dict.getOr("b", "def").asString(), "def");
    });

    test("has", () {
      final dict = Dict.from({"a": 1});
      expect(dict.has("a"), true);
      expect(dict.has("b"), false);
    });

    group("string&stringOr", () {
      test("string", () {
        final dict = Dict.from({"msg": "hello"});
        expect(dict.asString("msg"), "hello");
      });

      test("stringOr", () {
        final dict = Dict.from({});
        expect(dict.stringOr("msg", "fallback"), "fallback");
      });
    });

    group("bool&boolOr", () {
      test("bool", () {
        final dict = Dict.from({"flag": true});
        expect(dict.asBool("flag"), true);
      });

      test("boolOr", () {
        final dict = Dict.from({});
        expect(dict.boolOr("flag", false), false);
      });
    });

    group("int&intOr", () {
      test("int", () {
        final dict = Dict.from({"num": 123});
        expect(dict.asInt("num"), 123);
      });

      test("intOr", () {
        final dict = Dict.from({});
        expect(dict.intOr("num", 99), 99);
      });
    });

    group("double&doubleOr", () {
      test("double", () {
        final dict = Dict.from({"pi": 3.14});
        expect(dict.asDouble("pi"), 3.14);
      });

      test("doubleOr", () {
        final dict = Dict.from({});
        expect(dict.doubleOr("pi", 2.71), 2.71);
      });
    });

    group("bytes&bytesOr", () {
      test("bytes", () {
        final dict = Dict.from({
          "bin": Uint8List.fromList([1, 2])
        });
        expect(dict.asBytes("bin"), Uint8List.fromList([1, 2]));
      });

      test("bytesOr", () {
        final def = Uint8List.fromList([9]);
        final dict = Dict.from({});
        expect(dict.bytesOr("bin", def), def);
      });
    });

    group("decodeInto", () {
      test("decodesJSONIntoTargetType", () {
        final dict = Dict.from({"name": "Alice", "age": 30});
        final person = dict.decodeInto((json) => Person.fromJson(json));
        expect(person.name, "Alice");
        expect(person.age, 30);
      });
    });

    test("raw", () {
      final dict = Dict.from({"a": 1, "b": "x"});
      expect(dict.raw(), {"a": 1, "b": "x"});
    });
  });
}

class Person {
  Person(this.name, this.age);

  factory Person.fromJson(Map<String, dynamic> json) => Person(json["name"], json["age"]);
  final String name;
  final int age;
}
