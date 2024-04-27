import "package:wamp/src/session.dart";
import "package:wamp/src/types.dart";
import "package:wamp/src/wsjoiner.dart";
import "package:wampproto/auth.dart";
import "package:wampproto/serializers.dart";

class Client {
  Client(this._authenticator, this._serializer);

  final IClientAuthenticator _authenticator;
  final Serializer _serializer;

  Future<Session> connect(String url, String realm) async {
    WAMPSessionJoiner joiner = WAMPSessionJoiner(_authenticator, serializer: _serializer);
    BaseSession baseSession = await joiner.join(url, realm);

    return Session(baseSession);
  }
}
