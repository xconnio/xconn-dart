import "dart:io";

import "package:xconn/xconn.dart";

const procedureProgressUpload = "io.xconn.progress.upload";

Future<void> main() async {
  var callee = await connectAnonymous("ws://localhost:8080/ws", "realm1");

  Result? downloadHandler(Invocation inv) {
    final isProgress = inv.details["progress"] as bool? ?? false;

    // Handle the progressive chunk
    if (isProgress) {
      final chunkIndex = inv.args[0] as int;
      print("Received chunk $chunkIndex");
      return null;
    }

    // Final response after all chunks are received
    print("All chunks received, processing complete.");

    return Result(args: ["Upload complete"]);
  }

  var registration = await callee.register(procedureProgressUpload, downloadHandler);
  print("Registered procedure $procedureProgressUpload successfully");

  // Define a signal handler to catch the interrupt signal (Ctrl+C)
  ProcessSignal.sigint.watch().listen((signal) async {
    await callee.unregister(registration);
    await callee.close();
  });
}
