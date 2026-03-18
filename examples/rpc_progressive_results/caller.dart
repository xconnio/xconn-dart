import "package:xconn/src/types.dart";
import "package:xconn/xconn.dart";

const procedureProgress = "io.xconn.progress.mirror";

Future<void> main() async {
  var caller = await connectAnonymous("ws://localhost:8080/ws", "realm1");

  const totalChunks = 6;

  print("Starting file upload...");

  final progressive = await caller.callProgressiveProgress(procedureProgress, args: [0], kwargs: {}, options: {});

  for (var chunkIndex = 1; chunkIndex < totalChunks; chunkIndex++) {
    final options = <String, dynamic>{};
    options["progress"] = chunkIndex < totalChunks - 1;

    final progress = Progress(args: [chunkIndex], options: options);

    await progressive.sendProgress(progress);

    print("Sent chunk $chunkIndex...");
  }

  await for (final result in progressive.receive()) {
    if (result.details["progress"] ?? false) {
      final currentChunk = result.args[0] as int;
      print("Progress update: chunk $currentChunk acknowledged by server");
    } else {
      print(result.args[0]);
    }
  }

  print("Upload complete.");

  await caller.close();
}
