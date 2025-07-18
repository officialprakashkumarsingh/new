/* ----------------------------------------------------------
   MODELS
---------------------------------------------------------- */
enum Sender { user, bot }

class Message {
  final String id;
  final Sender sender;
  final String text;
  final bool isStreaming;
  final DateTime timestamp;

  Message({
    required this.id,
    required this.sender,
    required this.text,
    this.isStreaming = false,
    required this.timestamp,
  });

  factory Message.user(String text) {
    final timestamp = DateTime.now();
    return Message(
      id: 'user_${timestamp.toIso8601String()}',
      sender: Sender.user,
      text: text,
      timestamp: timestamp,
    );
  }

  factory Message.bot(String text, {bool isStreaming = false}) {
    final timestamp = DateTime.now();
    return Message(
      id: 'bot_${timestamp.toIso8601String()}',
      sender: Sender.bot,
      text: text,
      isStreaming: isStreaming,
      timestamp: timestamp,
    );
  }
}

class ChatSession {
  final String title;
  final List<Message> messages;

  ChatSession({required this.title, required this.messages});
}

// NEW USER MODEL
class User {
  final String name;
  final String email;
  final String avatarUrl;

  User({required this.name, required this.email, required this.avatarUrl});
}