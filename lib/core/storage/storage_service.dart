import 'package:hive_flutter/hive_flutter.dart';
import '../../data/models/chat_message.dart';

class StorageService {
  static const String _boxName = 'tactical_logs';

  // 1. Initialize the Database (Run this at app start)
  static Future<void> init() async {
    await Hive.initFlutter();
    
    // Register the adapter we just generated
    Hive.registerAdapter(ChatMessageAdapter());
    
    // Open the box (Database File)
    await Hive.openBox<ChatMessage>(_boxName);
  }

  // 2. Save a Message
  static Future<void> saveMessage(String text, bool isMe, String timestamp) async {
    final box = Hive.box<ChatMessage>(_boxName);
    final message = ChatMessage(text: text, isMe: isMe, timestamp: timestamp);
    await box.add(message); // Auto-increments key
  }

  // 3. Load History
  static List<ChatMessage> getHistory() {
    final box = Hive.box<ChatMessage>(_boxName);
    return box.values.toList();
  }

  // 4. Tactical Wipe (Clear all logs)
  static Future<void> clearLogs() async {
    final box = Hive.box<ChatMessage>(_boxName);
    await box.clear();
  }
}