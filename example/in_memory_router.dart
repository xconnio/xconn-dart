import "package:wampproto/serializers.dart";

import "package:xconn/exports.dart";
import "package:xconn/src/types.dart";

const procedureName = "io.xconn.example_procedure";
const topicName = "io.xconn.example_topic";

void main() async {
  var router = Router()..addRealm("realm1");

  var serializer = JSONSerializer();
  var clientSideBase = ClientSideLocalBaseSession(1, "realm1", "local", "local", serializer, router);
  var serverSideBase = ServerSideLocalBaseSession(1, "realm1", "local", "local", serializer, other: clientSideBase);

  router.attachClient(serverSideBase);

  var session = Session(clientSideBase);

  // register a procedure
  var registration = await session.register(procedureName, (inv) {
    return Result(args: inv.args, kwargs: inv.kwargs, details: inv.details);
  });

  // call a procedure
  var result = await session.call(procedureName, args: ["abc"]);
  print("Result: args=${result.args}, kwargs=${result.kwargs}, details=${result.details}");

  // unregister a procedure
  await session.unregister(registration);

  // subscribe to a topic
  var subscription = await session.subscribe(topicName, (event) {
    print("Event: args=${event.args}, kwargs=${event.kwargs}, details=${event.details}");
  });

  // publish to a topic
  await session.publish(topicName, args: ["abc"], kwargs: {"one": 1}, options: {"acknowledge": true});

  // unsubscribe from a topic
  await session.unsubscribe(subscription);
}
