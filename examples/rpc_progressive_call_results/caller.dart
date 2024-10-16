import "dart:io";

import "package:xconn/xconn.dart";

const procedureDownload = "io.xconn.progress.download";

Future<void> main() async {
  var client = Client();
  var session = await client.connect("ws://localhost:8080/ws", "realm1");

  // Call procedure "io.xconn.progress.download"
  var result = await session.call(
    procedureDownload,
    progressHandler: (Result result) {
      var progress = result.args[0]; // Current progress
      var totalSize = result.args[1]; // Total file size
      print("Download progress: $progress / $totalSize bytes");
    },
  );

  print(result.args[0]);

  await session.close();
  exit(0);
}
