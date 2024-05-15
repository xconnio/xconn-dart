import "package:wampproto/broker.dart";
import "package:wampproto/dealer.dart";
import "package:wampproto/messages.dart";
import "package:wampproto/session.dart";
import "package:wampproto/types.dart";

import "package:xconn/src/types.dart";

class Realm {
  final Dealer _dealer = Dealer();
  final Broker _broker = Broker();

  final Map<int, IBaseSession> _clients = {};

  void attachClient(IBaseSession base) {
    _clients[base.id()] = base;
    var details = SessionDetails(base.id(), base.realm(), base.authid(), base.authrole());
    _dealer.addSession(details);
    _broker.addSession(details);
  }

  void detachClient(IBaseSession base) {
    _clients.remove(base.id());
    _broker.removeSession(base.id());
    _dealer.removeSession(base.id());
  }

  void stop() {
    // stop will disconnect all clients.
  }

  Future<void> receiveMessage(int sessionID, Message msg) async {
    switch (msg.messageType()) {
      case Call.id:
      case Yield.id:
      case Register.id:
      case UnRegister.id:
        MessageWithRecipient recipient = _dealer.receiveMessage(sessionID, msg);
        var client = _clients[recipient.recipient];
        client?.sendMessage(recipient.message);
        break;

      case Publish.id:
        var publishMsg = msg as Publish;
        var publication = _broker.receivePublish(sessionID, publishMsg);

        publication.recipients?.forEach((recipient) {
          var client = _clients[recipient];
          var event = publication.event;
          if (event != null) {
            client?.sendMessage(event);
          }
        });

        var ack = publication.ack;
        if (ack != null) {
          var client = _clients[ack.recipient];
          client?.sendMessage(ack.message);
        }

        break;

      case Subscribe.id:
      case UnSubscribe.id:
        MessageWithRecipient? recipient = _broker.receiveMessage(sessionID, msg);
        if (recipient == null) {
          throw Exception("recipient null");
        }

        var client = _clients[recipient.recipient];
        client?.sendMessage(recipient.message);
        break;

      case Goodbye.id:
        _dealer.removeSession(sessionID);
        _broker.removeSession(sessionID);
        var client = _clients[sessionID];
        await client?.close();
        _clients.remove(sessionID);
        break;
    }
  }
}
