# xconn

WAMP v2 Client and Router for Dart.

## Installation

To install `xconn`, use the following command:

**With Dart**

```shell
dart pub add xconn
```

**With Flutter**

```shell
flutter pub add xconn
```

## Client

Creating a client:

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

```dart
void examplePublish(Session session) async {
  await session.publish("io.xconn.example", args: ["Hello World!", 100], kwargs: {"xconn": "dart"});
  print("Published to topic io.xconn.example");
}
```

### Register a procedure

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

For more detailed examples or usage, refer to the [examples](./examples) folder of the project.

## Server

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

For more advanced usage, such as integrating an authenticator, refer to the sample tool available
in the [bin](./bin) folder of the project.

## Maintainer

For questions or issues, contact the maintainers:

- [omer@thing.com](mailto:omer@thing.com)
- [muzzammil@xconn.io](mailto:muzzammil@xconn.io)
