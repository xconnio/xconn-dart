import "package:test/expect.dart";
import "package:test/scaffolding.dart";

import "package:xconn/src/types.dart";
import "package:xconn/xconn.dart";

void main() {
  var router = Router()..addRealm("realm1");

  var serializer = JSONSerializer();
  var clientSideBase = ClientSideLocalBaseSession(1, "realm1", "local", "local", serializer, router);
  var serverSideBase = ServerSideLocalBaseSession(1, "realm1", "local", "local", serializer, other: clientSideBase);

  router.attachClient(serverSideBase);

  var session = Session(clientSideBase);

  const procedureName = "io.xconn.test_procedure";
  late Registration registration;
  test("register a procedure", () async {
    registration = await session.register(procedureName, (inv) {
      print("Invocation: args=${inv.args}, kwargs=${inv.kwargs}, details=${inv.details}");
      return Result(args: inv.args, kwargs: inv.kwargs, details: inv.details);
    });

    expect(registration, isA<Registration>());
  });

  test("call a procedure", () async {
    var args = ["abc", 1];
    var kwargs = {"foo": 1};

    var result = await session.call(procedureName, args: args, kwargs: kwargs);
    expect(result, isA<Result>());
    expect(result.args, args);
    expect(result.kwargs, kwargs);
    expect(result.details, {});
  });

  test("unregister a procedure", () async {
    await registration.unregister();
  });

  const topicName = "io.xconn.test_topic";
  late Subscription subscription;
  test("subscribe to a topic", () async {
    subscription = await session.subscribe(topicName, (event) {
      print("Event: args=${event.args}, kwargs=${event.kwargs}, details=${event.details}");
    });
    expect(subscription, isA<Subscription>());
  });

  test("publish to a topic", () async {
    await session.publish(topicName, args: ["abc"], kwargs: {"one": 1}, options: {"acknowledge": true});
  });

  test("unsubscribe from a topic", () async {
    await subscription.unsubscribe();
  });

  test("close a session", () async {
    var disconnected = false;
    session.onDisconnect(() {
      disconnected = true;
    });

    expect(session.connected(), true);

    await session.close();

    expect(session.connected(), false);
    expect(disconnected, true);
  });
}
