import 'package:hive/hive.dart';

// 1. Define the Model
class ChatMessage extends HiveObject {
  final String text;
  final bool isMe;
  final String timestamp;
  final String? senderName; // 👉 NEW: Stores the node name

  ChatMessage({
    required this.text,
    required this.isMe,
    required this.timestamp,
    this.senderName, 
  });
}

// 2. Manually Write the Adapter
class ChatMessageAdapter extends TypeAdapter<ChatMessage> {
  @override
  final int typeId = 0; 

  @override
  ChatMessage read(BinaryReader reader) {
    return ChatMessage(
      text: reader.readString(),
      isMe: reader.readBool(),
      timestamp: reader.readString(),
      // 👉 FIX: reader.availableBytes ensures old databases don't crash when reading the new field
      senderName: reader.availableBytes > 0 ? reader.readString() : "Unknown Node", 
    );
  }

  @override
  void write(BinaryWriter writer, ChatMessage obj) {
    writer.writeString(obj.text);
    writer.writeBool(obj.isMe);
    writer.writeString(obj.timestamp);
    writer.writeString(obj.senderName ?? "Unknown Node"); // 👉 NEW
  }
}