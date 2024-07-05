import "dart:io";

import "package:xconn/xconn.dart";

const testProcedureEcho = "io.xconn.echo";
const testProcedureSum = "io.xconn.sum";

// Function to handle received Invocation for "io.xconn.echo"
Result sum(Invocation event) {
  print("Received Invocation: args=${event.args}, kwargs=${event.kwargs}, details=${event.details}");
  var sum = 0;
  for (final arg in event.args) {
    if (arg is int) {
      sum = sum + arg;
    }
  }
  return Result(args: [sum]);
}

void main() async {
  // Create and connect a callee client to server
  var client = Client();
  var callee = await client.connect("ws://localhost:8080/ws", "realm1");

  // Define function to handle received Invocation for "io.xconn.echo"
  Result echo(Invocation event) {
    print("Received Invocation: args=${event.args}, kwargs=${event.kwargs}, details=${event.details}");

    return Result(args: event.args, kwargs: event.kwargs);
  }

  // Register procedure "io.xconn.echo"
  var echoRegistration = await callee.register(testProcedureEcho, echo);
  print("Registered procedure '$testProcedureEcho'");

  // Register procedure "io.xconn.sum"
  var sumRegistration = await callee.register(testProcedureSum, sum);
  print("Registered procedure '$testProcedureSum'");

  // Define a signal handler to catch the interrupt signal (Ctrl+C)
  ProcessSignal.sigint.watch().listen((signal) async {
    // Unregister procedure "io.xconn.echo"
    await callee.unregister(echoRegistration);

    // Unregister procedure "io.xconn.sum"
    await callee.unregister(sumRegistration);

    // Close connection to the server
    await callee.close();

    exit(0);
  });
}
