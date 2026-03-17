import "dart:async";
import "dart:collection";

import "package:wampproto/auth.dart";
import "package:wampproto/messages.dart";
import "package:wampproto/serializers.dart";
import "package:wampproto/session.dart";
import "package:web_socket_channel/web_socket_channel.dart";
import "package:xconn/src/exception.dart";

import "package:xconn/src/router.dart";
import "package:xconn/src/session.dart";

abstract class IBaseSession {
  int id();

  String realm();

  String authid();

  String authrole();

  Serializer serializer();

  Future<Object> read();

  Future<void> write(Object payload);

  Future<Message> readMessage();

  Future<void> writeMessage(Message msg);

  Future<void> close();
}

class BaseSession implements IBaseSession {
  BaseSession(this._peer, this._details, this._serializer);

  final Peer _peer;
  final SessionDetails _details;
  final Serializer _serializer;

  @override
  int id() => _details.sessionID;

  @override
  String realm() => _details.realm;

  @override
  String authid() => _details.authid;

  @override
  String authrole() => _details.authrole;

  @override
  Serializer serializer() => _serializer;

  @override
  Future<Object> read() => _peer.read();

  @override
  Future<void> write(Object payload) => _peer.write(payload);

  @override
  Future<Message> readMessage() async {
    final payload = await read();
    return _serializer.deserialize(payload);
  }

  @override
  Future<void> writeMessage(Message msg) async {
    final payload = _serializer.serialize(msg);
    await write(payload);
  }

  @override
  Future<void> close() => _peer.close();
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
  Registration(this.registrationID, this._session);

  final int registrationID;
  final Session _session;

  Future<void> unregister() {
    return _session.unregister(this);
  }
}

class RegisterRequest {
  RegisterRequest(this.future, this.endpoint);

  final Completer<Registration> future;
  final Future<Result?> Function(Invocation) endpoint;
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
  Subscription(this.subscriptionID, this._eventHandler, this._session);

  final int subscriptionID;
  final void Function(Event) _eventHandler;
  final Session _session;

  void Function(Event) get eventHandler => _eventHandler;

  Future<void> unsubscribe() {
    return _session.unsubscribe(this);
  }
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

class Progress {
  Progress({
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

class ClientConfig {
  ClientConfig({
    IClientAuthenticator? authenticator,
    Serializer? serializer,
    this.keepAliveInterval,
  })  : authenticator = authenticator ?? AnonymousAuthenticator(""),
        serializer = serializer ?? CBORSerializer();

  final IClientAuthenticator authenticator;
  final Serializer serializer;
  final Duration? keepAliveInterval;
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
  Future write(Object data) async {
    await writeMessage(_serializer.deserialize(data));
  }

  @override
  Future<Object> read() async {
    if (_incomingMessages.isNotEmpty) {
      return _incomingMessages.removeFirst();
    }

    await _completer.future;
    _completer = Completer();

    // Recursive call because in some cases there might still be no message available even after waiting
    return read();
  }

  @override
  Future<void> writeMessage(Message msg) async {
    return _router.receiveMessage(this, msg);
  }

  @override
  Future<Message> readMessage() async {
    return _serializer.deserialize(await read());
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
  Serializer serializer() => _serializer;

  @override
  Future write(Object data) async {
    await _other?.feed(data);
  }

  @override
  Future writeMessage(Message msg) async {
    await write(_serializer.serialize(msg));
  }

  @override
  Future close() async {}

  @override
  Future<Object> read() {
    throw UnimplementedError();
  }

  @override
  Future<Message> readMessage() {
    throw UnimplementedError();
  }
}

abstract class Peer {
  Future<Object> read();

  Future<void> write(Object data);

  Future<void> close();
}

class WebSocketPeer implements Peer {
  WebSocketPeer(this._channel) : _iterator = StreamIterator(_channel.stream);
  final WebSocketChannel _channel;
  final StreamIterator _iterator;

  @override
  Future<Object> read() async {
    if (await _iterator.moveNext()) {
      return _iterator.current;
    }
    throw PeerClosedException("Websocket closed");
  }

  @override
  Future<void> write(Object data) async {
    _channel.sink.add(data);
  }

  @override
  Future<void> close() async {
    await _channel.sink.close();
  }
}

class ProgressiveResult {
  ProgressiveResult(this._requestID, this._procedure, this.baseSession, this.wampSession, this._controller);

  final int _requestID;
  final String _procedure;
  final IBaseSession baseSession;
  late WAMPSession wampSession;
  final StreamController<Result> _controller;

  Future<void> sendProgress(Progress progress) async {
    var call = Call(
      _requestID,
      _procedure,
      args: progress.args,
      kwargs: progress.kwargs,
      options: progress.options,
    );
    await baseSession.write(wampSession.sendMessage(call));
  }

  Stream<Result> receive() => _controller.stream;
}
