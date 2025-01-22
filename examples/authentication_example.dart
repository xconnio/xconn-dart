import "package:wampproto/auth.dart";

import "package:xconn/src/types.dart";
import "package:xconn/xconn.dart";

class AuthenticationExample {
  Future<Session> connect(String url, String realm, IClientAuthenticator authenticator, Serializer serializer) {
    var client = Client(config: ClientConfig(authenticator: authenticator, serializer: serializer));
    return client.connect(url, realm);
  }

  Future<Session> connectTicket(String url, String realm, String authID, String ticket, Serializer serializer) {
    var ticketAuthenticator = TicketAuthenticator(authID, {}, ticket);

    return connect(url, realm, ticketAuthenticator, serializer);
  }

  Future<Session> connectCRA(String url, String realm, String authID, String secret, Serializer serializer) {
    var craAuthenticator = WAMPCRAAuthenticator(authID, {}, secret);

    return connect(url, realm, craAuthenticator, serializer);
  }

  Future<Session> connectCryptoSign(String url, String realm, String authID, String privateKey, Serializer serializer) {
    var cryptoSignAuthenticator = CryptoSignAuthenticator(authID, {}, privateKey);

    return connect(url, realm, cryptoSignAuthenticator, serializer);
  }
}
