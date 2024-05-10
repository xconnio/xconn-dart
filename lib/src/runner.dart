import "package:xconn/exports.dart";

Future<void> main() async {
  Router r = Router()..addRealm("realm1");

  Server s = Server(r);
  String host = "0.0.0.0";
  int port = 8080;
  print("server running on host $host & port $port");
  await s.start(host, port);
}
