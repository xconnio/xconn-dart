import "dart:io";

import "package:args/args.dart";
import "package:xconn/exports.dart";

Future<void> main(List<String> args) async {
  var parser = ArgParser()
    ..addOption("host", defaultsTo: "127.0.0.1")
    ..addOption("port", defaultsTo: "8080")
    ..addOption("realm", defaultsTo: "realm1")
    ..addFlag("help", negatable: false);

  var result = parser.parse(args);
  if (result.flag("help")) {
    print(parser.usage);
    exit(0);
  }

  var realm = result["realm"];
  var r = Router()..addRealm(realm);

  Server s = Server(r);
  var host = result["host"];
  var port = int.parse(result["port"]);

  print("Listening for websocket connections on ws://$host:$port/ws");
  await s.start(host, port);
}
