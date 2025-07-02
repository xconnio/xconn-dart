import "dart:io";

import "package:xconn/src/client.dart";
import "package:xconn/src/types.dart";

const testTopic = "io.xconn.test";

void main() async {
  // Create and connect a subscriber client to server
  var client = Client();
  var subscriber = await client.connect("ws://localhost:8080/ws", "realm1");

  // Define function to handle received events
  void eventHandler(Event event) {
    print("Received Event: args=${event.args}, kwargs=${event.kwargs}, details=${event.details}");
  }

  // Subscribe to topic
  var subscription = await subscriber.subscribe(testTopic, eventHandler);
  print("Subscribed to topic $testTopic");

  // Define a signal handler to catch the interrupt signal (Ctrl+C)
  ProcessSignal.sigint.watch().listen((signal) async {
    // Unsubscribe from topic
    await subscription.unsubscribe();

    // Close connection to the server
    await subscriber.close();

    exit(0);
  });
}
