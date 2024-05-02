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
