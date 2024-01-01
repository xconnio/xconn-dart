import 'package:xconn/wamp/interfaces/message.dart';

class Hello implements Message {
  final int type = 1;
  final String realm;
  final Map<String, String> details;

  Hello(this.realm, this.details);

  @override
  List<dynamic> marshal() {
    throw UnimplementedError();
  }

  static Message unmarshal(List<dynamic> msg) {
    return Hello("", {});
  }
}
