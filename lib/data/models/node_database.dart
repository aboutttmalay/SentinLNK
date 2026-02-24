import 'package:flutter/material.dart';
import 'package:meshtastic_flutter/generated/mesh.pb.dart'; 

// ==========================================
// 👉 1. THE DATA MODEL
// ==========================================
class TacticalNode {
  final String shortName;
  final String longName;
  final String hexId;
  final String hardware;
  final String role;
  final double batteryLevel;
  final double voltage;
  final double snr;
  final int? rssi;   
  final int lastHeardUnix; // Store raw integer for better sorting
  final String lastHeardText;
  final bool isLocal;

  TacticalNode({
    required this.shortName,
    required this.longName,
    required this.hexId,
    required this.hardware,
    required this.role,
    required this.batteryLevel,
    required this.voltage,
    required this.snr,
    this.rssi,
    required this.lastHeardUnix,
    required this.lastHeardText,
    required this.isLocal,
  });

  // THE SECRET: The official app merges partial packets!
  TacticalNode copyWith({
    String? shortName, String? longName, String? hardware, String? role,
    double? batteryLevel, double? voltage, double? snr, int? rssi,
    int? lastHeardUnix, String? lastHeardText, bool? isLocal,
  }) {
    return TacticalNode(
      shortName: shortName ?? this.shortName,
      longName: longName ?? this.longName,
      hexId: this.hexId,
      hardware: hardware ?? this.hardware,
      role: role ?? this.role,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      voltage: voltage ?? this.voltage,
      snr: snr ?? this.snr,
      rssi: rssi ?? this.rssi,
      lastHeardUnix: lastHeardUnix ?? this.lastHeardUnix,
      lastHeardText: lastHeardText ?? this.lastHeardText,
      isLocal: isLocal ?? this.isLocal,
    );
  }
}

// ==========================================
// 👉 2. THE OFFICIAL REPLICA DATABASE
// ==========================================
class NodeDatabase {
  static final NodeDatabase instance = NodeDatabase._init();
  NodeDatabase._init();

  final ValueNotifier<Map<String, TacticalNode>> radarMap = ValueNotifier({});
  String localNodeHexId = ""; // We will store MyNodeInfo here

  // ==========================================
  // 👉 NEW: Global trigger for background text messages
  // ==========================================
  final ValueNotifier<String?> latestIncomingMessage = ValueNotifier(null);

  void notifyNewMessage(String text) {
    print("📨 BACKGROUND NOTIFIER: Triggering UI for new message: $text");
    latestIncomingMessage.value = text;
  }

  // 1️⃣ OFFICIAL STEP 1: Catch Local Node ID
  void setLocalHardwareId(String hexId) {
    localNodeHexId = hexId;
    print("📍 SET LOCAL NODE: $localNodeHexId");
  }

  // 2️⃣ OFFICIAL STEP 2: Smart Merge NodeInfo
  void processDirectNodeInfo(NodeInfo info) {
    final current = Map<String, TacticalNode>.from(radarMap.value);
    
    String hexId = "!${info.num.toRadixString(16).toLowerCase()}";
    
    // Create a blank slate if we've never seen this node
    TacticalNode node = current[hexId] ?? TacticalNode(
      shortName: hexId.length > 4 ? hexId.substring(hexId.length - 4) : hexId,
      longName: "Unknown Node",
      hexId: hexId, hardware: "UNKNOWN", role: "CLIENT",
      batteryLevel: 0.0, voltage: 0.0, snr: 0.0, lastHeardUnix: 0, lastHeardText: "Never", isLocal: false,
    );

    // Smart Merge User Data
    if (info.hasUser()) {
      node = node.copyWith(
        shortName: info.user.shortName.isNotEmpty ? info.user.shortName : node.shortName,
        longName: info.user.longName.isNotEmpty ? info.user.longName : node.longName,
        hardware: info.user.hwModel.toString().replaceAll("HW_", "").replaceAll("UNSET", "UNKNOWN"),
        role: info.user.role.toString().replaceAll("ROLE_", "").replaceAll("UNSET", "CLIENT"),
      );
    }

    // Smart Merge Telemetry
    if (info.hasDeviceMetrics()) {
      node = node.copyWith(
        batteryLevel: info.deviceMetrics.batteryLevel.toDouble(),
        voltage: info.deviceMetrics.voltage.toDouble(),
      );
    }
    
    // Smart Merge Signal & Timing
    node = node.copyWith(
      snr: info.hasSnr() ? info.snr.toDouble() : node.snr,
      lastHeardUnix: info.lastHeard > 0 ? info.lastHeard : node.lastHeardUnix,
      lastHeardText: _formatLastHeard(info.lastHeard > 0 ? info.lastHeard : node.lastHeardUnix),
      isLocal: (hexId == localNodeHexId),
    );

    current[hexId] = node;
    // 🚀 Trigger UI Build on the main thread
    Future.microtask(() {
      radarMap.value = current;
    });
    print("📦 NodeDatabase: added/updated node $hexId. Total nodes now: ${current.length}");
  }

  // 👉 NEW: Process Live Battery & Health Data!
  void processTelemetry(String hexId, double battery, double voltage, double snr, int rssi) {
    final current = Map<String, TacticalNode>.from(radarMap.value);
    
    // Only update if we already know who this node is
    if (current.containsKey(hexId)) {
      current[hexId] = current[hexId]!.copyWith(
        batteryLevel: battery,
        voltage: voltage,
        snr: snr,
        rssi: rssi,
        lastHeardUnix: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        lastHeardText: "Just now",
      );
      // 🚀 Trigger UI Build on the main thread
      Future.microtask(() {
        print("⚡ MICROTASK: about to set radarMap.value with ${current.length} nodes");
        radarMap.value = current;
      });
      print("📦 NodeDatabase: telemetry update for $hexId. Total nodes now: ${current.length}");
    }
  }

  String _formatLastHeard(int unixTime) {
    if (unixTime == 0) return "Unknown";
    final last = DateTime.fromMillisecondsSinceEpoch(unixTime * 1000);
    final diff = DateTime.now().difference(last);
    
    if (diff.inMinutes < 1) return "Now";
    if (diff.inHours < 1) return "${diff.inMinutes} min ago";
    if (diff.inDays < 1) return "${diff.inHours} hrs ago";
    return "${diff.inDays} days ago";
  }
}