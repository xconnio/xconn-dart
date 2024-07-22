# Usage

XConn provides a versatile WAMP v2 client and router for Dart applications. Below are examples
demonstrating various functionalities:

## Client

### Creating a Client

To create a client and connect to a WAMP server:

```dart
import "package:xconn/xconn.dart";

void main() async {
  var client = Client();
  var session = await client.connect("ws://localhost:8080/ws", "realm1");
}
```

Once the session is established, you can perform WAMP actions. Below are examples of all 4 WAMP
operations:

### Subscribe to a topic

To subscribe to a topic and handle events:

```dart
void exampleSubscribe(Session session) async {
  var subscription = await session.subscribe("io.xconn.example", eventHandler);
  print("Subscribed to topic io.xconn.example");
}

void eventHandler(Event event) {
  print("Received Event: args=${event.args}, kwargs=${event.kwargs}, details=${event.details}");
}
```

### Publish to a topic

To publish messages to a topic:

```dart
void examplePublish(Session session) async {
  await session.publish("io.xconn.example", args: ["Hello World!", 100], kwargs: {"xconn": "dart"});
  print("Published to topic io.xconn.example");
}
```

### Register a procedure

To register a procedure:

```dart
void exampleRegister(Session session) async {
  var registration = await session.register("io.xconn.echo", invocationHandler);
  print("Registered procedure io.xconn.echo");
}

Result invocationHandler(Invocation invocation) {
  return Result(args: invocation.args, kwargs: invocation.kwargs, details: invocation.details);
}
```

### Call a procedure

To call a procedure:

```dart
void exampleCall(Session session) async {
  var result = await session.call("io.xconn.echo", args: ["Hello World!"], kwargs: {"number": 100});
  print("Call result: args=${result.args}, kwargs=${result.kwargs}, details=${result.details}");
}
```

### Authentication

Authentication is straightforward. Simply create the object of the desired authenticator and pass it
to the Client.

**Ticket Auth**

```dart
void main() async {
  var ticketAuthenticator = TicketAuthenticator(ticket, authid);
  var client = Client(authenticator: ticketAuthenticator);
  var session = await client.connect("ws://localhost:8080/ws", "realm1");
}
```

**Challenge Response Auth**

```dart
void main() async {
  var craAuthenticator = WAMPCRAAuthenticator(secret, authid);
  var client = Client(authenticator: craAuthenticator);
  var session = await client.connect("ws://localhost:8080/ws", "realm1");
}
```

**Cryptosign Auth**

```dart
void main() async {
  var cryptosignAuthenticator = CryptoSignAuthenticator(privateKey, authid);
  var client = Client(authenticator: cryptosignAuthenticator);
  var session = await client.connect("ws://localhost:8080/ws", "realm1");
}
```

### Serializers

XConn supports various serializers for different data formats. To use, create an instance of your
chosen serializer and pass it to the client.

**JSON Serializer**

```dart
void main() async {
  var jsonSerializer = JSONSerializer();
  var client = Client(serializer: jsonSerializer);
  var session = await client.connect("ws://localhost:8080/ws", "realm1");
}
```

**CBOR Serializer**

```dart
void main() async {
  var cborSerializer = CBORSerializer();
  var client = Client(serializer: cborSerializer);
  var session = await client.connect("ws://localhost:8080/ws", "realm1");
}
```

**MsgPack Serializer**

```dart
void main() async {
  var msgPackSerializer = MsgPackSerializer();
  var client = Client(serializer: msgPackSerializer);
  var session = await client.connect("ws://localhost:8080/ws", "realm1");
}
```

For more detailed examples or usage, refer to
the [examples](https://github.com/xconnio/xconn-dart/tree/main/examples) folder of the project.

## Server

### Setting Up a Basic Server

Setting up a basic server is straightforward:

```dart
import 'package:xconn/xconn.dart';

void main() async {
  var router = Router()
    ..addRealm('realm1');
  var server = Server(router);
  await server.start('localhost', 8080);
}
```

### Setting Up Server with Authenticator

Here's a simple example of a server authenticator and how to pass it to the server:

```dart
class ServerAuthenticator extends IServerAuthenticator {
  @override
  Response authenticate(Request request) {
    if (request is AnonymousRequest) {
      // Handle anonymous request
    } else if (request is TicketRequest) {
      // Handle ticket request
    } else if (request is WAMPCRARequest) {
      // Handle wampcra request
    } else if (request is CryptoSignRequest) {
      // Handle cryptosign request
    }

    throw Exception("unknown authmethod");
  }

  @override
  List<String> methods() {
    return ["anonymous", "ticket", "wampcra", "cryptosign"];
  }
}

void main() async {
  var router = Router()
    ..addRealm('realm1');
  var server = Server(router);

  // Start the server with the custom authenticator
  await server.start('localhost', 8080, authenticator: ServerAuthenticator());
}
```

For more advanced usage, such as integrating an authenticator, refer to the sample tool available
in the [bin](https://github.com/xconnio/xconn-dart/tree/main/bin/xconn) folder of the project.

