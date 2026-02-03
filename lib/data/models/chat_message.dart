import 'package:hive/hive.dart';

// 1. Define the Model
class ChatMessage extends HiveObject {
  final String text;
  final bool isMe;
  final String timestamp;

  ChatMessage({
    required this.text,
    required this.isMe,
    required this.timestamp,
  });
}

// 2. Manually Write the Adapter (The "Bridge" for the Database)
class ChatMessageAdapter extends TypeAdapter<ChatMessage> {
  @override
  final int typeId = 0; // Unique ID for this object type

  @override
  ChatMessage read(BinaryReader reader) {
    // Read the data back in the exact order we wrote it
    return ChatMessage(
      text: reader.readString(),
      isMe: reader.readBool(),
      timestamp: reader.readString(),
    );
  }

  @override
  void write(BinaryWriter writer, ChatMessage obj) {
    // Write the data to disk
    writer.writeString(obj.text);
    writer.writeBool(obj.isMe);
    writer.writeString(obj.timestamp);
  }
}