import "dart:async";
import "dart:collection";

import "package:wampproto/messages.dart";
import "package:wampproto/serializers.dart";
import "package:wampproto/session.dart";
import "package:web_socket_channel/web_socket_channel.dart";

import "package:xconn/src/router.dart";

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
  BaseSession(this._ws, this._wsStreamSubscription, this.sessionDetails, this._serializer) {
    // close cleanly on abrupt client disconnect
    _wsStreamSubscription.onDone(() async {
      await close();
    });
  }

  final WebSocketChannel _ws;
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
    _ws.sink.add(data);
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
    await _wsStreamSubscription.cancel();
    await _ws.sink.close();
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

  late Function(List<dynamic>? args, Map<String, dynamic>? kwargs) sendProgress;
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

class ClientSideLocalBaseSession implements IBaseSession {
  ClientSideLocalBaseSession(this._id, this._realm, this._authid, this._authrole, this._serializer, this._router) {
    _incomingMessages = Queue();
    _completer = Completer();
  }

  final int _id;
  final String _realm;
  final String _authid;
  final String _authrole;
  final Serializer _serializer;
  final Router _router;

  late Queue _incomingMessages;
  late Completer _completer;

  @override
  int id() => _id;

  @override
  String realm() => _realm;

  @override
  String authid() => _authid;

  @override
  String authrole() => _authrole;

  @override
  Serializer serializer() => _serializer;

  @override
  Future send(Object data) async {
    await sendMessage(_serializer.deserialize(data));
  }

  @override
  Future<Object> receive() async {
    if (_incomingMessages.isNotEmpty) {
      return _incomingMessages.removeFirst();
    }

    await _completer.future;
    _completer = Completer();

    // Recursive call because in some cases there might still be no message available even after waiting
    return receive();
  }

  @override
  Future<void> sendMessage(Message msg) async {
    return _router.receiveMessage(this, msg);
  }

  @override
  Future<Message> receiveMessage() async {
    return _serializer.deserialize(await receive());
  }

  @override
  Future close() async {}

  Future feed(Object data) async {
    _incomingMessages.add(data);
    if (!_completer.isCompleted) {
      _completer.complete();
    }
  }
}

class ServerSideLocalBaseSession extends IBaseSession {
  ServerSideLocalBaseSession(
    this._id,
    this._realm,
    this._authid,
    this._authrole,
    this._serializer, {
    ClientSideLocalBaseSession? other,
  }) : _other = other;

  final int _id;
  final String _realm;
  final String _authid;
  final String _authrole;
  final Serializer _serializer;
  final ClientSideLocalBaseSession? _other;

  @override
  int id() => _id;

  @override
  String realm() => _realm;

  @override
  String authid() => _authid;

  @override
  String authrole() => _authrole;

  @override
  Future send(Object data) async {
    await _other?.feed(data);
  }

  @override
  Future sendMessage(Message msg) async {
    await send(_serializer.serialize(msg));
  }

  @override
  Future close() async {}
}
