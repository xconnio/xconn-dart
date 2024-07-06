import "package:test/test.dart";
import "package:wampproto/messages.dart" as msg;

import "package:xconn/src/types.dart";
import "package:xconn/xconn.dart";

void main() {
  const testProcedure = "io.xconn.test_procedure";
  const testTopic = "io.xconn.test_topic";

  var router = Router()..addRealm("realm1");

  var serializer = JSONSerializer();
  var clientSideBase = ClientSideLocalBaseSession(1, "realm1", "local", "local", serializer, router);
  var serverSideBase = ServerSideLocalBaseSession(1, "realm1", "local", "local", serializer, other: clientSideBase);

  router.attachClient(serverSideBase);

  late int registrationID;

  test("register", () async {
    var registerMsg = msg.Register(3, testProcedure);
    await router.receiveMessage(clientSideBase, registerMsg);

    var registered = await clientSideBase.receiveMessage();
    expect(registered, isA<msg.Registered>());

    registrationID = (registered as msg.Registered).registrationID;
  });

  test("call", () async {
    var callMsg = msg.Call(4, testProcedure);
    await router.receiveMessage(clientSideBase, callMsg);

    var invocation = await clientSideBase.receiveMessage();
    expect(invocation, isA<msg.Invocation>());

    var requestID = (invocation as msg.Invocation).requestID;
    var yieldMsg = msg.Yield(requestID);
    await router.receiveMessage(clientSideBase, yieldMsg);

    var result = await clientSideBase.receiveMessage();
    expect(result, isA<msg.Result>());
  });

  test("unregister", () async {
    var unregisterMsg = msg.Unregister(5, registrationID);
    await router.receiveMessage(clientSideBase, unregisterMsg);

    var unregistered = await clientSideBase.receiveMessage();
    expect(unregistered, isA<msg.Unregistered>());
  });

  late int subscriptionID;

  test("subscribe", () async {
    var subscribeMsg = msg.Subscribe(6, testTopic);
    await router.receiveMessage(clientSideBase, subscribeMsg);

    var subscribed = await clientSideBase.receiveMessage();
    expect(subscribed, isA<msg.Subscribed>());

    subscriptionID = (subscribed as msg.Subscribed).subscriptionID;
  });

  test("publish", () async {
    var publish = msg.Publish(7, testTopic);
    await router.receiveMessage(clientSideBase, publish);

    var event = await clientSideBase.receiveMessage();
    expect(event, isA<msg.Event>());

    var publishAck = msg.Publish(8, testTopic, options: {"acknowledge": true});
    await router.receiveMessage(clientSideBase, publishAck);

    var eventAck = await clientSideBase.receiveMessage();
    expect(eventAck, isA<msg.Event>());

    var published = await clientSideBase.receiveMessage();
    expect(published, isA<msg.Published>());
  });

  test("unsubscribe", () async {
    var unsubscribeMsg = msg.Unsubscribe(9, subscriptionID);
    await router.receiveMessage(clientSideBase, unsubscribeMsg);

    var unsubscribed = await clientSideBase.receiveMessage();
    expect(unsubscribed, isA<msg.Unsubscribed>());
  });
}
