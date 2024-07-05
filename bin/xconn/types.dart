import "authenticator.dart";

class Realm {
  Realm({required this.name});

  factory Realm.fromMap(Map<String, dynamic> map) {
    return Realm(name: map["name"]);
  }

  final String name;
}

class Transport {
  Transport({required this.type, required this.port});

  factory Transport.fromMap(Map<String, dynamic> map) {
    return Transport(
      type: map["type"],
      port: map["port"],
    );
  }

  final String type;
  final int port;
}

abstract class Authenticator {
  Authenticator({
    required this.authid,
    required this.realm,
    required this.role,
  });

  final String authid;
  final String realm;
  final String role;
}

class AnonymousAuth extends Authenticator {
  AnonymousAuth({required super.authid, required super.realm, required super.role});

  factory AnonymousAuth.fromMap(Map<String, dynamic> map) {
    return AnonymousAuth(
      authid: map["authid"],
      realm: map["realm"],
      role: map["role"],
    );
  }
}

class CRAAuth extends Authenticator {
  CRAAuth({required super.authid, required super.realm, required super.role, required this.secret});

  factory CRAAuth.fromMap(Map<String, dynamic> map) {
    return CRAAuth(
      authid: map["authid"],
      realm: map["realm"],
      role: map["role"],
      secret: map["secret"],
    );
  }

  final String secret;
}

class TicketAuth extends Authenticator {
  TicketAuth({required super.authid, required super.realm, required super.role, required this.ticket});

  factory TicketAuth.fromMap(Map<String, dynamic> map) {
    return TicketAuth(
      authid: map["authid"],
      realm: map["realm"],
      role: map["role"],
      ticket: map["ticket"],
    );
  }

  final String ticket;
}

class CryptoSignAuth extends Authenticator {
  CryptoSignAuth({required super.authid, required super.realm, required super.role, required this.authorizedKeys});

  factory CryptoSignAuth.fromMap(Map<String, dynamic> map) {
    return CryptoSignAuth(
      authid: map["authid"],
      realm: map["realm"],
      role: map["role"],
      authorizedKeys: List<String>.from(map["authorized_keys"]),
    );
  }

  final List<String> authorizedKeys;
}

class Authenticators {
  Authenticators({
    required this.anonymousAuths,
    required this.craAuths,
    required this.ticketAuths,
    required this.cryptoSignAuths,
  });

  final List<AnonymousAuth> anonymousAuths;
  final List<CRAAuth> craAuths;
  final List<TicketAuth> ticketAuths;
  final List<CryptoSignAuth> cryptoSignAuths;
}

class Config {
  Config({
    required this.version,
    required this.realms,
    required this.transports,
    required this.authenticators,
  });

  factory Config.fromMap(Map<String, dynamic> map) {
    return Config(
      version: map["version"],
      realms: (map["realms"] as List)
          .map(
            (realm) => Realm.fromMap(Map<String, dynamic>.from(realm)),
          )
          .toList(),
      transports: (map["transports"] as List)
          .map(
            (transport) => Transport.fromMap(Map<String, dynamic>.from(transport)),
          )
          .toList(),
      authenticators: Authenticators(
        anonymousAuths: ((map["authenticators"] as Map)[anonymous] as List)
            .map(
              (auth) => AnonymousAuth.fromMap(Map<String, dynamic>.from(auth)),
            )
            .toList(),
        craAuths: ((map["authenticators"] as Map)[wampCRA] as List)
            .map(
              (auth) => CRAAuth.fromMap(Map<String, dynamic>.from(auth)),
            )
            .toList(),
        ticketAuths: ((map["authenticators"] as Map)[ticket] as List)
            .map(
              (auth) => TicketAuth.fromMap(Map<String, dynamic>.from(auth)),
            )
            .toList(),
        cryptoSignAuths: ((map["authenticators"] as Map)[cryptosign] as List)
            .map(
              (auth) => CryptoSignAuth.fromMap(Map<String, dynamic>.from(auth)),
            )
            .toList(),
      ),
    );
  }

  final String version;
  final List<Realm> realms;
  final List<Transport> transports;
  final Authenticators authenticators;
}
