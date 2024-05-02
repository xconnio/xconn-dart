import "package:wamp/src/realm.dart";
import "package:wamp/src/types.dart";
import "package:wampproto/messages.dart";

class Router {
  Map<String, Realm> realms = {};

  void addRealm(String name) {
    realms[name] = Realm();
  }

  void removeRealm(String name) {
    realms.remove(name);
  }

  bool hasRealm(String name) {
    return realms.containsKey(name);
  }

  void attachClient(IBaseSession baseSession) {
    String realm = baseSession.realm();
    if (!realms.containsKey(realm)) {
      throw Exception("cannot attach client to non-existent realm $realm");
    }

    realms[realm]?.attachClient(baseSession);
  }

  void detachClient(IBaseSession baseSession) {
    String realm = baseSession.realm();
    if (!realms.containsKey(realm)) {
      throw Exception("cannot detach client from non-existent realm $realm");
    }

    realms[realm]?.detachClient(baseSession);
  }

  void receiveMessage(IBaseSession baseSession, Message msg) {
    String realm = baseSession.realm();
    if (!realms.containsKey(realm)) {
      throw Exception("cannot process message for non-existent realm $realm");
    }

    realms[realm]?.receiveMessage(baseSession.id(), msg);
  }
}
