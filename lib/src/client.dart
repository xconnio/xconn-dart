import "package:xconn/src/joiner.dart";
import "package:xconn/src/session.dart";
import "package:xconn/src/types.dart";

class Client {
  Client({ClientConfig? config}) : _config = config ?? ClientConfig();

  final ClientConfig _config;

  Future<Session> connect(String url, String realm) async {
    WAMPSessionJoiner joiner = WAMPSessionJoiner(authenticator: _config.authenticator, serializer: _config.serializer);
    BaseSession baseSession = await joiner.join(url, realm, keepAliveInterval: _config.keepAliveInterval);

    return Session(baseSession);
  }
}
