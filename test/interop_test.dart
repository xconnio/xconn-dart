import "package:test/expect.dart";
import "package:test/scaffolding.dart";
import "package:wampproto/auth.dart";
import "package:wampproto/serializers.dart";
import "package:xconn/src/client.dart";
import "package:xconn/src/types.dart";

void main() async {
  const xconnURL = "ws://localhost:8080/ws";
  const crossbarURL = "ws://localhost:8081/ws";
  const realm = "realm1";
  const procedureAdd = "io.xconn.backend.add2";

  Future<void> testCall(IClientAuthenticator authenticator, Serializer serializer, String url) async {
    var client = Client(authenticator: authenticator, serializer: serializer);
    var session = await client.connect(url, realm);
    var result = await session.call(procedureAdd, args: [2, 2]);
    expect(4, result.args[0]);
  }

  Future<void> testRPC(IClientAuthenticator authenticator, Serializer serializer, String url) async {
    var client = Client(authenticator: authenticator, serializer: serializer);
    var session = await client.connect(url, realm);

    var reg = await session.register("io.xconn.test", (inv) {
      return Result(args: inv.args, kwargs: inv.kwargs);
    });

    var args = ["Hello", "wamp"];
    var result = await session.call("io.xconn.test", args: args);
    expect(args, result.args);

    await session.unregister(reg);
  }

  Future<void> testPubSub(IClientAuthenticator authenticator, Serializer serializer, String url) async {
    var client = Client(authenticator: authenticator, serializer: serializer);
    var session = await client.connect(url, realm);

    var args = ["Hello", "wamp"];
    var sub = await session.subscribe("io.xconn.test", (event) {
      expect(args, event.args);
    });

    await session.publish("io.xconn.test", args: args, options: {"acknowledge": true});

    await session.unsubscribe(sub);
  }

  final serverURLs = {"xconn": xconnURL, "crossbar": crossbarURL};

  final authenticators = {
    "AnonymousAuth": AnonymousAuthenticator(""),
    "TicketAuth": TicketAuthenticator("ticket-user", {}, "ticket-pass"),
    "WAMPCRAAuth": WAMPCRAAuthenticator("wamp-cra-user", {}, "cra-secret"),
    // FIXME: WAMPCRA with salt is broken in crossbar
    // "WAMPCRAAuthSalted": WAMPCRAAuthenticator("wamp-cra-salt-user", {}, "cra-salt-secret"),
    "CryptosignAuth": CryptoSignAuthenticator(
      "cryptosign-user",
      {},
      "150085398329d255ad69e82bf47ced397bcec5b8fbeecd28a80edbbd85b49081",
    ),
  };

  final serializers = {
    "CBOR": CBORSerializer.new,
    "MsgPack": MsgPackSerializer.new,
    "JSON": JSONSerializer.new,
  };

  serverURLs.forEach((serverName, url) {
    authenticators.forEach((authName, authenticator) {
      serializers.forEach((serializerName, serializer) {
        test("$serverName with $authName and $serializerName", () async {
          await testCall(authenticator, serializer(), url);
          await testRPC(authenticator, serializer(), url);
          await testPubSub(authenticator, serializer(), url);
        });
      });
    });
  });
}
