import "package:wamp/src/session.dart";
import "package:wamp/src/types.dart";
import "package:wamp/src/wsjoiner.dart";
import "package:wampproto/auth.dart";
import "package:wampproto/serializers.dart";

class Client {
  Client({IClientAuthenticator? authenticator, Serializer? serializer}) {
    _authenticator = authenticator;
    _serializer = serializer;
  }

  IClientAuthenticator? _authenticator;
  Serializer? _serializer;

  Future<Session> connect(String url, String realm) async {
    WAMPSessionJoiner joiner = WAMPSessionJoiner(authenticator: _authenticator, serializer: _serializer);
    BaseSession baseSession = await joiner.join(url, realm);

    return Session(baseSession);
  }
}
