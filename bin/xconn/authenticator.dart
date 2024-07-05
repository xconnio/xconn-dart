import "package:wampproto/auth.dart";

import "types.dart";

const String anonymous = "anonymous";
const String ticket = "ticket";
const String wampCRA = "wampcra";
const String cryptosign = "cryptosign";

class ServerAuthenticator extends IServerAuthenticator {
  ServerAuthenticator(this.authenticators);

  final Authenticators authenticators;

  @override
  Response authenticate(Request request) {
    if (request is AnonymousRequest) {
      for (final auth in authenticators.anonymousAuths) {
        if (auth.realm == request.realm) {
          return Response(request.authID, auth.role);
        }
      }

      throw Exception("invalid realm");
    } else if (request is TicketRequest) {
      for (final auth in authenticators.ticketAuths) {
        if (auth.realm == request.realm && auth.ticket == request.ticket) {
          return Response(request.authID, auth.role);
        }
      }

      throw Exception("invalid ticket");
    } else if (request is WAMPCRARequest) {
      for (final auth in authenticators.craAuths) {
        if (auth.realm == request.realm) {
          return WAMPCRAResponse(request.authID, auth.role, auth.secret);
        }
      }

      throw Exception("invalid realm");
    } else if (request is CryptoSignRequest) {
      for (final auth in authenticators.cryptoSignAuths) {
        if (auth.realm == request.realm && auth.authorizedKeys.contains(request.publicKey)) {
          return Response(request.authID, auth.role);
        }
      }

      throw Exception("unknown publickey");
    }

    throw Exception("unknown authmethod");
  }

  @override
  List<String> methods() {
    return [anonymous, ticket, wampCRA, cryptosign];
  }
}
