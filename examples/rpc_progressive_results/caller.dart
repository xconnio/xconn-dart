import "package:xconn/src/types.dart";
import "package:xconn/xconn.dart";

const procedureProgress = "io.xconn.progress.mirror";

Future<void> main() async {
  var caller = await connectAnonymous("ws://localhost:8080/ws", "realm1");

  const totalChunks = 6;
  var chunkIndex = 0;

  print("Starting file upload...");

  final result = await caller.callProgressiveProgress(procedureProgress, () {
    final options = <String, dynamic>{};

    // Mark the last chunk as non-progressive
    options["progress"] = chunkIndex == totalChunks - 1 ? false : true;

    // Simulate sending each chunk
    print("Uploading chunk $chunkIndex...");
    final args = [chunkIndex];

    chunkIndex++;

    return Progress(args: args, options: options);
  }, (Result result) {
    // final chunkIndex = result.args[0] as int;
    print("Progress update: chunk ${result.args[0]} acknowledged by server");
  });

  print("Final result: ${result.args[0]}");

  await caller.close();
}
