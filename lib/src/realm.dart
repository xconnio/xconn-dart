import "package:wampproto/broker.dart";
import "package:wampproto/dealer.dart";
import "package:wampproto/messages.dart";
import "package:wampproto/types.dart";

import "package:xconn/src/types.dart";

class Realm {
  final Dealer _dealer = Dealer();
  final Broker _broker = Broker();

  final Map<int, IBaseSession> _clients = {};

  void attachClient(IBaseSession base) {
    _clients[base.id()] = base;
    _dealer.addSession(base.id());
    _broker.addSession(base.id());
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
        List<MessageWithRecipient>? recipients = _broker.receiveMessage(sessionID, msg);
        if (recipients == null) {
          return;
        }

        for (final recipient in recipients) {
          var client = _clients[recipient.recipient];
          client?.sendMessage(recipient.message);
        }

        break;

      case Subscribe.id:
      case UnSubscribe.id:
        List<MessageWithRecipient>? recipients = _broker.receiveMessage(sessionID, msg);
        if (recipients == null) {
          throw Exception("recipients null");
        }
        MessageWithRecipient recipient = recipients[0];
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
