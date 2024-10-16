import "dart:io";
import "package:xconn/xconn.dart";

const procedureDownload = "io.xconn.progress.download";

Future<void> main() async {
  var client = Client();
  var session = await client.connect("ws://localhost:8080/ws", "realm1");

  // Define function to handle received Invocation for "io.xconn.progress.download"
  Result downloadHandler(Invocation inv) {
    var totalSize = 1000; // Total file size in "bytes"
    var chunkSize = 100; // Each chunk is 100 bytes
    var progress = 0;

    while (progress < totalSize) {
      progress += chunkSize;
      inv.sendProgress([progress, totalSize], null); // Send progress
      sleep(const Duration(milliseconds: 500)); // Simulate time to download each chunk
    }

    return Result(args: ["Download complete"]);
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
