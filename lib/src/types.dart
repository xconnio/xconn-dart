import "dart:async";
import "dart:io";

import "package:wampproto/serializers.dart";
import "package:wampproto/session.dart";

class BaseSession {
  BaseSession(this._ws, this._wsStreamController, this.sessionDetails, this.serializer);

  final WebSocket _ws;
  final StreamController _wsStreamController;
  SessionDetails sessionDetails;
  Serializer serializer;

  void send(Object data) {
    _ws.add(data);
  }

  Future<Object> receive() async {
    return await _wsStreamController.stream.first;
  }

  Future<void> close() async {
    await _ws.close();
  }
}

class Result {
  Result({
    List<dynamic>? args,
    Map<String, dynamic>? kwargs,
    Map<String, dynamic>? options,
  })  : args = args ?? [],
        kwargs = kwargs ?? {},
        options = options ?? {};

  final List<dynamic> args;
  final Map<String, dynamic> kwargs;
  final Map<String, dynamic> options;
}

class Registration {
  Registration(this.registrationID);

  final int registrationID;
}

class RegisterRequest {
  RegisterRequest(this.future, this.endpoint);

  final Completer<Registration> future;
  final Result Function(Invocation) endpoint;
}

class Invocation {
  Invocation({
    List<dynamic>? args,
    Map<String, dynamic>? kwargs,
    Map<String, dynamic>? options,
  })  : args = args ?? [],
        kwargs = kwargs ?? {},
        options = options ?? {};

  final List<dynamic> args;
  final Map<String, dynamic> kwargs;
  final Map<String, dynamic> options;
}

class UnregisterRequest {
  UnregisterRequest(this.future, this.registrationID);

  final Completer<void> future;
  final int registrationID;
}

class Published {}

class Subscription {
  Subscription(this.subscriptionId);

  final int subscriptionId;
}

class SubscribeRequest {
  SubscribeRequest(this.future, this.endpoint);

  final Completer<Subscription> future;
  final void Function(Event) endpoint;
}

class Event {
  Event({
    List<dynamic>? args,
    Map<String, dynamic>? kwargs,
    Map<String, dynamic>? options,
  })  : args = args ?? [],
        kwargs = kwargs ?? {},
        options = options ?? {};

  final List<dynamic> args;
  final Map<String, dynamic> kwargs;
  final Map<String, dynamic> options;
}
