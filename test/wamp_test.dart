import "package:test/test.dart";
import "package:wamp/wamp.dart";

void main() {
  test("calculate", () {
    expect(calculate(), 42);
  });
}
