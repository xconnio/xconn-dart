import "dart:convert";
import "dart:typed_data";

class Value {
  Value(this._data);

  factory Value.of(v) => Value(v);
  final dynamic _data;

  dynamic raw() => _data;

  String asString() {
    if (_data is String) {
      return _data as String;
    }
    throw FormatException("value is not string, got ${_data.runtimeType}");
  }

  String stringOr(String def) {
    try {
      return asString();
    } on FormatException {
      return def;
    }
  }

  bool asBool() {
    if (_data is bool) {
      return _data as bool;
    }
    throw FormatException("value is not bool, got ${_data.runtimeType}");
  }

  bool boolOr(bool def) {
    try {
      return asBool();
    } on FormatException {
      return def;
    }
  }

  int asInt() {
    final v = _data;
    if (v is int) {
      return v;
    }
    if (v is double) {
      return v.toInt();
    }
    throw FormatException("value cannot be converted to int, got ${_data.runtimeType}");
  }

  int intOr(int def) {
    try {
      return asInt();
    } on FormatException {
      return def;
    }
  }

  double asDouble() {
    final v = _data;
    if (v is double) {
      return v;
    }
    if (v is int) {
      return v.toDouble();
    }
    throw FormatException("value cannot be converted to float64, got ${_data.runtimeType}");
  }

  double doubleOr(double def) {
    try {
      return asDouble();
    } on FormatException {
      return def;
    }
  }

  Uint8List asBytes() {
    final v = _data;
    if (v is Uint8List) {
      return v;
    }
    if (v is List<int>) {
      return Uint8List.fromList(v);
    }
    if (v is String) {
      return Uint8List.fromList(utf8.encode(v));
    }
    throw FormatException("value cannot be converted to bytes, got ${_data.runtimeType}");
  }

  Uint8List bytesOr(Uint8List def) {
    try {
      return asBytes();
    } on FormatException {
      return def;
    }
  }

  T decodeInto<T>(T Function(dynamic json) fromJson) {
    final encoded = jsonEncode(_data);
    final decoded = jsonDecode(encoded);
    return fromJson(decoded);
  }
}

class ValueList {
  ValueList(this._list);

  factory ValueList.from(List<dynamic> values) => ValueList(values.map((v) => Value.of(v)).toList());
  final List<Value> _list;

  int len() => _list.length;

  Value get(int i) {
    if (i < 0 || i >= _list.length) {
      throw FormatException("index $i out of range [0, ${_list.length})");
    }
    return _list[i];
  }

  Value getOr(int i, dynamic def) {
    try {
      return get(i);
    } on FormatException {
      return Value.of(def);
    }
  }

  String asString(int i) => get(i).asString();

  String stringOr(int i, String def) => getOr(i, def).stringOr(def);

  bool asBool(int i) => get(i).asBool();

  bool boolOr(int i, bool def) => getOr(i, def).boolOr(def);

  int asInt(int i) => get(i).asInt();

  int intOr(int i, int def) => getOr(i, def).intOr(def);

  double asDouble(int i) => get(i).asDouble();

  double doubleOr(int i, double def) => getOr(i, def).doubleOr(def);

  Uint8List asBytes(int i) => get(i).asBytes();

  Uint8List bytesOr(int i, Uint8List def) => getOr(i, def).bytesOr(def);

  List<dynamic> raw() => _list.map((v) => v.raw()).toList(growable: false);
}

class Dict {
  Dict(this._map);

  factory Dict.from(Map<String, dynamic> values) => Dict({for (final e in values.entries) e.key: Value.of(e.value)});
  final Map<String, Value> _map;

  int len() => _map.length;

  Value get(String key) {
    final v = _map[key];
    if (v == null) {
      throw FormatException('key "$key" not found');
    }
    return v;
  }

  Value getOr(String key, dynamic def) {
    final v = _map[key];
    return v ?? Value.of(def);
  }

  bool has(String key) => _map.containsKey(key);

  String asString(String key) => get(key).asString();

  String stringOr(String key, String def) => getOr(key, def).stringOr(def);

  bool asBool(String key) => get(key).asBool();

  bool boolOr(String key, bool def) => getOr(key, def).boolOr(def);

  int asInt(String key) => get(key).asInt();

  int intOr(String key, int def) => getOr(key, def).intOr(def);

  double asDouble(String key) => get(key).asDouble();

  double doubleOr(String key, double def) => getOr(key, def).doubleOr(def);

  Uint8List asBytes(String key) => get(key).asBytes();

  Uint8List bytesOr(String key, Uint8List def) => getOr(key, def).bytesOr(def);

  T decodeInto<T>(T Function(Map<String, dynamic> json) fromJson) {
    final raw = <String, dynamic>{
      for (final e in _map.entries) e.key: e.value.raw(),
    };
    final encoded = jsonEncode(raw);
    final decoded = jsonDecode(encoded) as Map<String, dynamic>;
    return fromJson(decoded);
  }

  Map<String, dynamic> raw() => {for (final e in _map.entries) e.key: e.value.raw()};
}
