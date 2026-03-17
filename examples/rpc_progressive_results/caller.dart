import "dart:async";
import "package:xconn/src/types.dart";
import "package:xconn/xconn.dart";

const procedureProgress = "io.xconn.progress.mirror";

Future<void> main() async {
  final caller = await connectAnonymous("ws://localhost:8080/ws", "realm1");

  const totalChunks = 6;
  var chunkIndex = 0;

  print("Starting file upload...");

  // Create a stream controller for progressive chunks
  final controller = StreamController<Progress>();

  // Kick off the progressive call
  final result = await caller.callProgressiveProgress(
    procedureProgress,
    controller.stream,
    (Result result) {
      print("Progress update: chunk ${result.args[0]} acknowledged by server");
    },
  );

  // Simulate sending chunks
  while (chunkIndex < totalChunks) {
    final options = <String, dynamic>{
      "progress": chunkIndex == totalChunks - 1 ? false : true,
    };

    print("Uploading chunk $chunkIndex...");
    controller.add(Progress(args: [chunkIndex], options: options));

    chunkIndex++;
    await Future.delayed(const Duration(milliseconds: 100)); // simulate delay
  }

  print("Final result: ${result.args[0]}");

  await controller.close();
  await caller.close();
}
