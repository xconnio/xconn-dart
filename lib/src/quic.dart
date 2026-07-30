import "dart:ffi";
import "dart:io";
import "dart:typed_data";

import "package:dart_quic/dart_quic.dart";
import "package:wampproto/auth.dart";
import "package:wampproto/serializers.dart";

import "package:xconn/src/exception.dart";
import "package:xconn/src/joiner.dart";
import "package:xconn/src/session.dart";
import "package:xconn/src/types.dart";

const int _magic = 0x7F;
const int _msgTypeWAMP = 0;
const int _msgTypePing = 1;
const int _msgTypePong = 2;
const int _defaultMaxMsgSize = 1 << 20;

int _serializerID(Serializer serializer) {
  if (serializer is JSONSerializer) {
    return 1;
  }
  if (serializer is MsgPackSerializer) {
    return 2;
  }
  if (serializer is CBORSerializer) {
    return 3;
  }
  throw ArgumentError("unsupported serializer: $serializer");
}

// Encodes maxMsgSize as the exponent field for the rawsocket handshake.
int _msgSizeExp(int maxMsgSize) {
  var exp = 0;
  var size = maxMsgSize;
  while (size > 1) {
    size >>= 1;
    exp++;
  }
  return exp - 9;
}

class _QUICStreamPeer implements Peer {
  _QUICStreamPeer(this._stream);

  final QuicStream _stream;
  bool _closed = false;

  @override
  Future<Object> read() async {
    while (true) {
      if (_closed) {
        throw PeerClosedException("QUIC stream closed");
      }
      try {
        final header = await _stream.readExact(4);
        final msgType = header[0];
        final length = (header[1] << 16) | (header[2] << 8) | header[3];

        if (msgType == _msgTypeWAMP) {
          return _stream.readExact(length);
        } else if (msgType == _msgTypePing) {
          final payload = await _stream.readExact(length);
          final pong = Uint8List(4 + length);
          pong[0] = _msgTypePong;
          pong[1] = (length >> 16) & 0xFF;
          pong[2] = (length >> 8) & 0xFF;
          pong[3] = length & 0xFF;
          pong.setRange(4, 4 + length, payload);
          await _stream.writeAll(pong);
        } else if (msgType == _msgTypePong) {
          await _stream.readExact(length); // discard
        } else {
          throw ProtocolError("QUIC rawsocket: unknown message type $msgType");
        }
      } on Object catch (e) {
        if (_closed || e is StateError) {
          throw PeerClosedException("QUIC stream closed");
        }
        rethrow;
      }
    }
  }

  @override
  Future<void> write(Object data) async {
    final bytes = data is Uint8List ? data : Uint8List.fromList(data as List<int>);
    final length = bytes.length;
    final msg = Uint8List(4 + length);
    msg[0] = _msgTypeWAMP;
    msg[1] = (length >> 16) & 0xFF;
    msg[2] = (length >> 8) & 0xFF;
    msg[3] = length & 0xFF;
    msg.setRange(4, 4 + length, bytes);
    await _stream.writeAll(msg);
  }

  @override
  Future<void> close() async {
    if (_closed) {
      return;
    }
    _closed = true;
    _stream
      ..finish()
      ..dispose();
  }
}

// The underlying QUIC connection, shared across all sessions opened on it.
// Use openStream/acceptStream for raw (non-WAMP) data transfer.
class QUICConnection {
  QUICConnection._(this._conn, this._client);

  final QuicConn _conn;
  final QuicClientEndpoint _client;
  bool _closed = false;

  // Opens a raw bidirectional stream to the server.
  Future<QuicStream> openStream() => _conn.openBiStream();

  // Waits for the server to open a raw bidirectional stream to this client.
  Future<QuicStream> acceptStream() => _conn.acceptBiStream();

  Future<void> _close() async {
    if (_closed) {
      return;
    }
    _closed = true;
    // QuicConn.close() is synchronous
    _conn
      ..close()
      ..dispose();
    try {
      await _client.close();
    } on Object catch (_) {}
    _client.dispose();
  }
}

// A WAMP session running over a QUIC stream.
// Extends Session with QUIC-specific capabilities:
class QUICSession extends Session {
  // ignore: use_super_parameters
  QUICSession._(BaseSession base, this._connection, {bool ownsConnection = true})
    : _ownsConnection = ownsConnection,
      super(base);

  final QUICConnection _connection;
  final bool _ownsConnection;

  QUICConnection get connection => _connection;

  Future<QuicStream> openStream() => _connection.openStream();

  Future<QuicStream> acceptStream() => _connection.acceptStream();

  // Opens an additional WAMP session multiplexed on the same QUIC connection.
  Future<QUICSession> openSession(String realm, [QUICDialerConfig? config]) async {
    config ??= QUICDialerConfig();
    final stream = await _connection._conn.openBiStream();
    try {
      final peer = await _handshake(stream, config.serializer);
      final base = await joinPeer(peer, realm, config.serializer, config.authenticator);
      return QUICSession._(base, _connection, ownsConnection: false);
    } on Object {
      stream
        ..finish()
        ..dispose();
      rethrow;
    }
  }

  @override
  Future<void> close() async {
    await super.close();
    if (_ownsConnection) {
      await _connection._close();
    }
  }
}

// Performs the rawsocket handshake on an already-open QuicStream and
// returns a Peer ready for WAMP message exchange.
Future<_QUICStreamPeer> _handshake(QuicStream stream, Serializer serializer) async {
  final serID = _serializerID(serializer);
  final byte1 = (_msgSizeExp(_defaultMaxMsgSize) << 4) | serID;
  await stream.writeAll(Uint8List.fromList([_magic, byte1, 0x00, 0x00]));

  final resp = await stream.readExact(4);
  if (resp[0] != _magic) {
    throw ProtocolError("rawsocket handshake: bad magic 0x${resp[0].toRadixString(16)}");
  }
  if ((resp[1] >> 4) == 0) {
    throw ProtocolError("rawsocket handshake error from server: code ${resp[1] & 0x0F}");
  }
  if ((resp[1] & 0x0F) != serID) {
    throw ProtocolError("rawsocket handshake: serializer mismatch (sent $serID, got ${resp[1] & 0x0F})");
  }
  return _QUICStreamPeer(stream);
}

class QUICDialerConfig {
  QUICDialerConfig({
    IClientAuthenticator? authenticator,
    Serializer? serializer,
    this.skipVerification = false,
    this.libraryPath,
  }) : authenticator = authenticator ?? AnonymousAuthenticator(""),
       serializer = serializer ?? CBORSerializer();

  final IClientAuthenticator authenticator;
  final Serializer serializer;

  final bool skipVerification;

  final String? libraryPath;
}

Future<QUICSession> connectQUIC(String address, String realm, [QUICDialerConfig? config]) async {
  config ??= QUICDialerConfig();

  if (config.libraryPath != null) {
    LibraryLoader.setCustomLoader(() => DynamicLibrary.open(config!.libraryPath!));
  }
  QuicInitializer.initialize();

  final colon = address.lastIndexOf(":");
  if (colon < 0) {
    throw ArgumentError("connectQUIC: invalid address '$address' — expected host:port");
  }
  final host = address.substring(0, colon);
  final port = int.parse(address.substring(colon + 1));

  // dart_quic requires an IP address, not a hostname — resolve first.
  final addresses = await InternetAddress.lookup(host);
  if (addresses.isEmpty) {
    throw ArgumentError("connectQUIC: could not resolve '$host'");
  }
  final resolvedAddr = "${addresses.first.address}:$port";

  final clientCfg = config.skipVerification
      ? QuicClientConfig.withSkipVerification()
      : QuicClientConfig.withSystemRoots();

  final client = await QuicClientEndpoint.create(clientCfg);
  QuicConn? conn;
  QuicStream? stream;
  try {
    conn = await client.connectTo(serverAddr: resolvedAddr, serverName: host);
    stream = await conn.openBiStream();
    final peer = await _handshake(stream, config.serializer);
    final connection = QUICConnection._(conn, client);
    final base = await joinPeer(peer, realm, config.serializer, config.authenticator);
    return QUICSession._(base, connection);
  } on Object {
    if (stream != null) {
      stream
        ..finish()
        ..dispose();
    }
    if (conn != null) {
      conn
        ..close()
        ..dispose();
    }
    try {
      await client.close();
    } on Object catch (_) {}
    client.dispose();
    rethrow;
  }
}
