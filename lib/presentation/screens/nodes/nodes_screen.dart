import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../data/models/node_database.dart';
import 'node_details_screen.dart';
import '../../../core/services/hardware_bridge.dart';

class NodesScreen extends StatefulWidget {
  const NodesScreen({super.key});

  @override
  State<NodesScreen> createState() => _NodesScreenState();
}

class _NodesScreenState extends State<NodesScreen> {
  @override
  void initState() {
    super.initState();
    print("📌 NodesScreen initState");
    HardwareBridge.instance.connectAndSync();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Map<String, TacticalNode>>(
      valueListenable: NodeDatabase.instance.radarMap,
      builder: (context, nodesMap, child) {
        // 🔥🔥🔥 DISTINCTIVE PRINT
        print("🔥🔥🔥 BUILDER FIRED at ${DateTime.now().toIso8601String()}");
        print("🔥 Map keys: ${nodesMap.keys.join(', ')}");
        final nodes = nodesMap.values.toList(); // ← only one declaration
        print("🔥 Nodes list length: ${nodes.length}");

        nodes.sort((a, b) {
          if (a.isLocal && !b.isLocal) return -1;
          if (!a.isLocal && b.isLocal) return 1;
          return a.longName.compareTo(b.longName);
        });

        return Scaffold(
          backgroundColor: const Color(0xFF0F1714),
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Nodes",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                Text(
                  "(${nodes.length} online / ${nodes.length} shown / ${nodes.length} total)",
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(LucideIcons.listFilter, color: Colors.white),
                onPressed: () {},
              )
            ],
          ),
          body: Column(
            children: [
              // Search Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: TextField(
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: "Filter",
                    hintStyle: const TextStyle(color: Colors.grey),
                    prefixIcon: const Icon(LucideIcons.search, color: Colors.grey),
                    filled: true,
                    fillColor: const Color(0xFF1A2421),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.grey, width: 0.5),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.grey, width: 0.5),
                    ),
                  ),
                ),
              ),

              // 👇 TEMPORARY: Show simple text with node count
              Expanded(
                child: Center(
                  child: Text(
                    "Nodes: ${nodes.length}",
                    style: const TextStyle(color: Colors.white, fontSize: 24),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNodeCard(TacticalNode node) {
    // … (unchanged, but currently not used)
    final Color cardColor = node.isLocal ? const Color(0xFF2A2415) : const Color(0xFF142415);
    final Color badgeColor = node.isLocal ? const Color(0xFFFACC15) : const Color(0xFF22C55E);
    final Color textColor = Colors.white;
    final Color dimTextColor = Colors.grey[400]!;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => NodeDetailsScreen(node: node),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // TOP ROW: Badge, Lock, Name, Cloud Icon
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: badgeColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    node.shortName,
                    style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                const Icon(LucideIcons.lock, color: Color(0xFF22C55E), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        node.longName,
                        style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      Row(
                        children: [
                          Icon(LucideIcons.radioReceiver, color: dimTextColor, size: 12),
                          const SizedBox(width: 4),
                          Text(
                            node.lastHeardText,
                            style: TextStyle(color: dimTextColor, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (node.isLocal)
                  const Icon(LucideIcons.cloud, color: Color(0xFF22C55E), size: 20),
              ],
            ),
            const SizedBox(height: 16),

            // MIDDLE ROW: Telemetry (Battery, Signal)
            if (node.isLocal)
              Row(
                children: [
                  Icon(LucideIcons.batteryCharging, color: dimTextColor, size: 14),
                  const SizedBox(width: 4),
                  Text("PWR ${node.voltage.toStringAsFixed(2)}V",
                      style: TextStyle(color: dimTextColor, fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 16),
                  Icon(LucideIcons.barChart2, color: dimTextColor, size: 14),
                  const SizedBox(width: 4),
                  Text("ChUtil 0.0%", style: TextStyle(color: dimTextColor, fontSize: 13)),
                ],
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(LucideIcons.battery, color: dimTextColor, size: 14),
                      const SizedBox(width: 4),
                      Text("${node.batteryLevel.toInt()}%", style: TextStyle(color: dimTextColor, fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text("SNR ${node.snr}dB RSSI ${node.rssi ?? '--'}dBm",
                          style: const TextStyle(color: Color(0xFF22C55E), fontSize: 13)),
                      const SizedBox(width: 8),
                      const Icon(LucideIcons.signal, color: Color(0xFF22C55E), size: 14),
                      const SizedBox(width: 4),
                      const Text("Good", style: TextStyle(color: Color(0xFF22C55E), fontSize: 13)),
                    ],
                  ),
                ],
              ),

            const SizedBox(height: 16),

            // BOTTOM ROW: Hardware, Role, Hex ID
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(LucideIcons.cpu, color: dimTextColor, size: 14),
                    const SizedBox(width: 4),
                    Text(node.hardware, style: TextStyle(color: dimTextColor, fontSize: 13)),
                  ],
                ),
                Row(
                  children: [
                    Icon(LucideIcons.user, color: dimTextColor, size: 14),
                    const SizedBox(width: 4),
                    Text(node.role, style: TextStyle(color: dimTextColor, fontSize: 13, fontWeight: FontWeight.bold)),
                  ],
                ),
                Row(
                  children: [
                    Icon(LucideIcons.fingerprint, color: dimTextColor, size: 14),
                    const SizedBox(width: 4),
                    Text(node.hexId, style: TextStyle(color: dimTextColor, fontSize: 13)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}