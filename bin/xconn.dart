import 'package:xconn/wamp/messages/hello.dart';

void main(List<String> arguments) {
  Hello hello = Hello("realm1", {});
  print(hello.type);
}
