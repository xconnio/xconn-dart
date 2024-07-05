import "package:xconn/xconn.dart";

const testProcedureEcho = "io.xconn.echo";
const testProcedureSum = "io.xconn.sum";

void main() async {
  // Create and connect a caller client to server
  var client = Client();
  var caller = await client.connect("ws://localhost:8080/ws", "realm1");

  // Call procedure "io.xconn.echo"
  var result = await caller.call(testProcedureEcho, args: ["Hello"], kwargs: {"Hello": "World"});
  print(
    "Result of procedure '$testProcedureEcho': args=${result.args}, kwargs=${result.kwargs}, details=${result.details}",
  );

  // Call procedure "io.xconn.sum"
  var sum = await caller.call(testProcedureSum, args: [2, 187676, 876]);
  print("Sum=${sum.args[0]}");

  // Close connection to the server
  await caller.close();
}
