import "package:wampproto/auth.dart";
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

Future<Session> _connect(String uri, String realm, [IClientAuthenticator? authenticator]) async {
  final client = Client(config: ClientConfig(authenticator: authenticator));
  return client.connect(uri, realm);
}

Future<Session> connectAnonymous(String uri, String realm) async {
  return _connect(uri, realm);
}

Future<Session> connectTicket(String uri, String realm, String authid, String ticket) async {
  final ticketAuthenticator = TicketAuthenticator(authid, ticket, null);
  return _connect(uri, realm, ticketAuthenticator);
}

Future<Session> connectCRA(String uri, String realm, String authid, String secret) async {
  final craAuthenticator = WAMPCRAAuthenticator(authid, secret, null);
  return _connect(uri, realm, craAuthenticator);
}

Future<Session> connectCryptosign(String uri, String realm, String authid, String privateKey) async {
  final cryptosignAuthenticator = CryptoSignAuthenticator(authid, privateKey, null);
  return _connect(uri, realm, cryptosignAuthenticator);
}
