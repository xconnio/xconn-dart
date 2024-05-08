import "package:wampproto/auth.dart";
import "package:wampproto/serializers.dart";

import "package:xconn/src/joiner.dart";
import "package:xconn/src/session.dart";
import "package:xconn/src/types.dart";

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
