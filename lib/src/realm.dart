import "package:wamp/src/types.dart";
import "package:wampproto/broker.dart";
import "package:wampproto/dealer.dart";
import "package:wampproto/messages.dart";
import "package:wampproto/types.dart";

class Realm {
  Dealer dealer = Dealer();
  Broker broker = Broker();

  Map<int, IBaseSession> clients = {};

  void attachClient(IBaseSession base) {
    clients[base.id()] = base;
    dealer.addSession(base.id());
    broker.addSession(base.id());
  }

  void detachClient(IBaseSession base) {
    clients.remove(base.id());
    broker.removeSession(base.id());
    dealer.removeSession(base.id());
  }

  void stop() {
    // stop will disconnect all clients.
  }

  void receiveMessage(int sessionID, Message msg) {
    switch (msg.messageType()) {
      case Call.id || Yield.id || Register.id || UnRegister.id:
        MessageWithRecipient recipient = dealer.receiveMessage(sessionID, msg);
        var client = clients[recipient.recipient];
        client?.sendMessage(recipient.message);

      case Publish.id || Subscribe.id || UnSubscribe.id:
        List<MessageWithRecipient>? recipients = broker.receiveMessage(sessionID, msg);
        if (recipients == null) {
          return;
        }

        for (final recipient in recipients) {
          var client = clients[recipient.recipient];
          client?.sendMessage(msg);
        }
      case Goodbye.id:
        dealer.removeSession(sessionID);
        broker.removeSession(sessionID);
        var client = clients[sessionID];
        client?.ws.close();
        clients.remove(sessionID);
    }
  }
}
