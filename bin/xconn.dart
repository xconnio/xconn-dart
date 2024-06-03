import "dart:io";

import "package:args/args.dart";
import "package:xconn/exports.dart";
import "package:yaml/yaml.dart";

import "authenticator.dart";
import "helpers.dart";
import "types.dart";

const config = """
version: '1'

realms:
  - name: realm1

transports:
  - type: websocket
    port: 8080

authenticators:
  cryptosign:
    - authid: john
      realm: realm1
      role: anonymous
      authorized_keys:
        - 20e6ff0eb2552204fac19a15a61da586e437abd64a545bedce61a89b48184fcb

  wampcra:
    - authid: john
      realm: realm1
      role: anonymous
      secret: hello

  ticket:
    - authid: john
      realm: realm1
      role: anonymous
      ticket: hello

  anonymous:
    - authid: john
      realm: realm1
      role: anonymous
""";

const cfgDir = ".xconn";
const cfgFile = "$cfgDir/config.yaml";

Future<void> main(List<String> arguments) async {
  final parser = ArgParser()
    ..addCommand("init")
    ..addCommand("start")
    ..addFlag("help", abbr: "h", negatable: false, help: "Prints usage information.");

  ArgResults argResults;
  try {
    argResults = parser.parse(arguments);
  } on Exception catch (e) {
    print(e);
    exit(1);
  }

  final command = argResults.command;
  if (command == null) {
    print("Command not recognized.");
    exit(1);
  }

  switch (command.name) {
    case "help":
      print("Usage: dart run xconn init");
      break;

    case "init":
      Directory(cfgDir).createSync();

      File(cfgFile).writeAsStringSync(config);

      print("Configuration file generated at .xconn/config.yaml");
      break;

    case "start":
      final file = File(cfgFile);
      final configStr = file.readAsStringSync();
      final yamlMap = loadYaml(configStr);

      final dartMap = convertYamlToMap(yamlMap);

      final cfg = Config.fromMap(dartMap);

      var r = Router();

      for (final realm in cfg.realms) {
        r.addRealm(realm.name);
      }

      var s = Server(r);

      var authenticator = ServerAuthenticator(cfg.authenticators);

      for (final transport in cfg.transports) {
        print("Listening for websocket connections on ws://0.0.0.0:${transport.port}/ws");
        await s.start("0.0.0.0", transport.port, authenticator: authenticator);
      }
      break;
    default:
      print("Command not recognized.");
      exit(1);
  }
}
