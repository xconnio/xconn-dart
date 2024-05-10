import "dart:async";
import "dart:io";

import "package:wampproto/messages.dart";
import "package:wampproto/serializers.dart";
import "package:wampproto/session.dart";

abstract class IBaseSession {
  int id() {
    throw UnimplementedError();
  }

  String realm() {
    throw UnimplementedError();
  }

  String authid() {
    throw UnimplementedError();
  }

  String authrole() {
    throw UnimplementedError();
  }

  Serializer serializer() {
    throw UnimplementedError();
  }

  void send(Object data) {
    throw UnimplementedError();
  }

  Future<Object> receive() async {
    throw UnimplementedError();
  }

  void sendMessage(Message msg) {
    throw UnimplementedError();
  }

  Future<Message> receiveMessage() async {
    throw UnimplementedError();
  }

  Future<void> close() async {
    throw UnimplementedError();
  }
}

class BaseSession extends IBaseSession {
  BaseSession(this._ws, this._wsStreamSubscription, this.sessionDetails, this._serializer);

  final WebSocket _ws;
  final StreamSubscription<dynamic> _wsStreamSubscription;
  SessionDetails sessionDetails;
  final Serializer _serializer;

  @override
  int id() {
    return sessionDetails.sessionID;
  }

  @override
  String realm() {
    return sessionDetails.realm;
  }

  @override
  String authid() {
    return sessionDetails.authid;
  }

  @override
  String authrole() {
    return sessionDetails.authrole;
  }

  @override
  Serializer serializer() {
    return _serializer;
  }

  @override
  void send(Object data) {
    _ws.add(data);
  }

  @override
  void sendMessage(Message msg) {
    send(_serializer.serialize(msg));
  }

  @override
  Future<Object> receive() async {
    var completer = Completer<Object>();

    _wsStreamSubscription
      ..onData((data) {
        completer.complete(data);
        _wsStreamSubscription.pause();
      })
      ..resume();
    return completer.future;
  }

  @override
  Future<Message> receiveMessage() async {
    return _serializer.deserialize(await receive());
  }

  @override
  Future<void> close() async {
    await _ws.close();
  }
}

class Result {
  Result({
    List<dynamic>? args,
    Map<String, dynamic>? kwargs,
    Map<String, dynamic>? details,
  })  : args = args ?? [],
        kwargs = kwargs ?? {},
        details = details ?? {};

  final List<dynamic> args;
  final Map<String, dynamic> kwargs;
  final Map<String, dynamic> details;
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
    Map<String, dynamic>? details,
  })  : args = args ?? [],
        kwargs = kwargs ?? {},
        details = details ?? {};

  final List<dynamic> args;
  final Map<String, dynamic> kwargs;
  final Map<String, dynamic> details;
}

class UnregisterRequest {
  UnregisterRequest(this.future, this.registrationID);

  final Completer<void> future;
  final int registrationID;
}

class Subscription {
  Subscription(this.subscriptionID);

  final int subscriptionID;
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
    Map<String, dynamic>? details,
  })  : args = args ?? [],
        kwargs = kwargs ?? {},
        details = details ?? {};

  final List<dynamic> args;
  final Map<String, dynamic> kwargs;
  final Map<String, dynamic> details;
}

class UnsubscribeRequest {
  UnsubscribeRequest(this.future, this.subscriptionId);

  final Completer<void> future;
  final int subscriptionId;
}
