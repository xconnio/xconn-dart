import "dart:io";

import "package:xconn/xconn.dart";

const procedureDownload = "io.xconn.progress.download";

Future<void> main() async {
  var client = Client();
  var session = await client.connect("ws://localhost:8080/ws", "realm1");

  // Call procedure "io.xconn.progress.download"
  var result = await session.callProgress(
    procedureDownload,
    (Result result) {
      var progress = result.args[0]; // Current progress
      print("Download progress: $progress%");
    },
  );

  print(result.args[0]);

  await session.close();
  exit(0);
}
