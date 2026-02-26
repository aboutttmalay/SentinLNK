import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/chat_message.dart';

class StorageService {
  static const String _globalBox = 'tactical_logs'; // Keeps your old history intact
  static const String _squadBox = 'squad_logs';     // New entirely separate box for Squads

  // 1. Initialize the Database
  static Future<void> init() async {
    await Hive.initFlutter();
    Hive.registerAdapter(ChatMessageAdapter());
    
    // 👉 FIX: Open BOTH databases so they are completely separated
    await Hive.openBox<ChatMessage>(_globalBox);
    await Hive.openBox<ChatMessage>(_squadBox);
  }

  // 2. Save a Message (Routes to the correct box)
  static Future<void> saveMessage(String text, bool isMe, String timestamp, {bool isSquad = false}) async {
    final box = Hive.box<ChatMessage>(isSquad ? _squadBox : _globalBox);
    final message = ChatMessage(text: text, isMe: isMe, timestamp: timestamp);
    await box.add(message); 
  }

  // 3. Load History (Loads only from the requested box)
  static List<ChatMessage> getHistory({bool isSquad = false}) {
    final box = Hive.box<ChatMessage>(isSquad ? _squadBox : _globalBox);
    return box.values.toList();
  }

  // 4. Tactical Wipe (Clear all logs)
  static Future<void> clearLogs() async {
    await Hive.box<ChatMessage>(_globalBox).clear();
    await Hive.box<ChatMessage>(_squadBox).clear();
  }

  static const String _keyKnownDevices = 'known_devices';

  // Save a device as "Known"
  static Future<void> saveKnownDevice(String remoteId, String name) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> known = prefs.getStringList(_keyKnownDevices) ?? [];
    String entry = "$remoteId|$name";
    
    known.removeWhere((e) => e.startsWith(remoteId));
    known.add(entry);
    
    await prefs.setStringList(_keyKnownDevices, known);
  }

  // Remove a device (Unpair)
  static Future<void> removeKnownDevice(String remoteId) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> known = prefs.getStringList(_keyKnownDevices) ?? [];
    known.removeWhere((e) => e.startsWith(remoteId));
    await prefs.setStringList(_keyKnownDevices, known);
  }

  // Get list of known devices
  static Future<Map<String, String>> getKnownDevices() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> known = prefs.getStringList(_keyKnownDevices) ?? [];
    Map<String, String> deviceMap = {};
    for (var entry in known) {
      var parts = entry.split('|');
      if (parts.length == 2) {
        deviceMap[parts[0]] = parts[1]; 
      }
    }
    return deviceMap;
  }
}