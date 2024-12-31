import "dart:io";
import "package:xconn/xconn.dart";

const procedureDownload = "io.xconn.progress.download";

Future<void> main() async {
  var client = Client();
  var session = await client.connect("ws://localhost:8080/ws", "realm1");

  // Define function to handle received Invocation for "io.xconn.progress.download"
  Result downloadHandler(Invocation inv) {
    const int fileSize = 100; // Simulate a file size of 100 units

    for (int i = 0; i <= fileSize; i += 10) {
      final int progress = i * 100 ~/ fileSize; // Calculate progress percentage
      inv.sendProgress([progress], null); // Send progress
      sleep(const Duration(milliseconds: 500));
    }

    return Result(args: ["Download complete!"]);
  }

  // Register procedure "io.xconn.progress.download"
  var registration = await session.register(procedureDownload, downloadHandler);
  print("Registered procedure $procedureDownload successfully");

  // Define a signal handler to catch the interrupt signal (Ctrl+C)
  ProcessSignal.sigint.watch().listen((signal) async {
    await session.unregister(registration);
    await session.close();
  });
}
