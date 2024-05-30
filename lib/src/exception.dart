class ApplicationError implements Exception {
  ApplicationError(this.message, {this.args, this.kwargs});

  final String message;
  final List<dynamic>? args;
  final Map<String, dynamic>? kwargs;

  @override
  String toString() {
    String errStr = message;
    if (args?.isNotEmpty ?? false) {
      String argsStr = args!.map((arg) => arg.toString()).join(", ");
      errStr += ": $argsStr";
    }
    if (kwargs?.isNotEmpty ?? false) {
      String kwargsStr = kwargs!.entries.map((entry) => "${entry.key}=${entry.value}").join(", ");
      errStr += ": $kwargsStr";
    }
    return errStr;
  }
}

class ProtocolError implements Exception {
  ProtocolError(this.message);

  final String message;
}
