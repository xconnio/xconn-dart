import "package:xconn/src/client.dart";

const testTopic = "io.xconn.test";

void main() async {
  // Create and connect a publisher client to server
  var client = Client();
  var publisher = await client.connect("ws://localhost:8080/ws", "realm1");

  // Publish event to topic
  await publisher.publish(testTopic);

  // Publish event with args
  await publisher.publish(testTopic, args: ["Hello", "World"]);

  // Publish event with kwargs
  await publisher.publish(testTopic, kwargs: {"Love": "WAMP"});

  // Publish event with args and kwargs
  await publisher.publish(testTopic, args: ["Hello World!", "I love WAMP"], kwargs: {"Hello": "World", "Love": "WAMP"});

  print("Published events to $testTopic");

  // Close connection to the server
  await publisher.close();
}
