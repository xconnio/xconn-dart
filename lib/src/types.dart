import "dart:async";
import "dart:io";
import "dart:html";
import "dart:typed_data";

import "package:wampproto/serializers.dart";
import "package:wampproto/session.dart";
import "package:wampproto/messages.dart";



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

abstract class IBaseSession {
  late final WebSocket ws;

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

  void send(Uint8List data) {
    throw UnimplementedError();
  }

  Uint8List receive() {
    throw UnimplementedError();
  }

  void sendMessage(Message msg) {
    throw UnimplementedError();
  }

  Message receiveMessage() {
    throw UnimplementedError();
  }
}
