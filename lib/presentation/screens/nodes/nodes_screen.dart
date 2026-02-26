import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../data/models/node_database.dart';
import '../../../core/services/hardware_bridge.dart';
import '../../../core/theme/app_colors.dart'; 
import 'node_details_screen.dart';
import '../../../data/models/tactical_node.dart';

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
    // 👉 REMOVED: connectAndSync()
    // The ScanScreen now handles all connections. This screen just reads the data!
  }

  String _getSignalQualityText(int? rssi) {
    if (rssi == null || rssi == -100) return "Waiting...";
    if (rssi >= -70) return "Excellent";
    if (rssi >= -90) return "Good";
    if (rssi >= -105) return "Fair";
    return "Weak";
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Map<String, TacticalNode>>(
      valueListenable: NodeDatabase.instance.radarMap,
      builder: (context, nodesMap, child) {
        
        // 👉 THE FIX: Filter out "Ghost" Nodes
        // Only show nodes that are Local, OR have been heard in the last 24 hours.
        // It ignores nodes with 0 timestamp (default empty flash memory nodes).
        final currentTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        final nodes = nodesMap.values.where((node) {
          if (node.isLocal) return true;
          if (node.lastHeardUnix == 0) return false; // Hide dead memory ghosts
          
          final secondsSinceHeard = currentTime - node.lastHeardUnix;
          return secondsSinceHeard < 86400; // Only show if active within 24 hours
        }).toList();

        nodes.sort((a, b) {
          if (a.isLocal && !b.isLocal) return -1;
          if (!a.isLocal && b.isLocal) return 1;
          return a.longName.compareTo(b.longName);
        });

        return Container(
          color: AppColors.bg,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "NODES",
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.2),
                    ),
                    Text(
                      "(${nodes.length} online / ${nodes.length} total)",
                      style: const TextStyle(fontSize: 12, color: AppColors.textDim),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: TextField(
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: "Filter nodes...",
                    hintStyle: const TextStyle(color: AppColors.textDim),
                    prefixIcon: const Icon(LucideIcons.search, color: AppColors.textDim),
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary)),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                ),
              ),

              Expanded(
                child: nodes.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(color: AppColors.primary),
                            SizedBox(height: 16),
                            Text("📡 Syncing topology...", style: TextStyle(color: AppColors.textDim)),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        // 👉 FIXED: Since the background drainer loops constantly, 
                        // pull-to-refresh just needs a visual delay to let UI catch up.
                        onRefresh: () async { 
                          await Future.delayed(const Duration(seconds: 1)); 
                        },
                        color: AppColors.primary,
                        backgroundColor: AppColors.surface,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: nodes.length,
                          itemBuilder: (context, index) { return _buildNodeCard(nodes[index], context); },
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNodeCard(TacticalNode node, BuildContext context) {
    final bool isLocal = node.isLocal;
    final Color badgeColor = isLocal ? Colors.orangeAccent : AppColors.primary;
    final Color textColor = Colors.white;
    final Color dimTextColor = AppColors.textDim;

    return GestureDetector(
      onTap: () { Navigator.push(context, MaterialPageRoute(builder: (context) => NodeDetailsScreen(node: node))); },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: isLocal ? Colors.orangeAccent.withValues(alpha: 0.3) : AppColors.border)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: badgeColor.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6)),
                  child: Text(node.shortName, style: TextStyle(color: badgeColor, fontWeight: FontWeight.bold, fontSize: 14)),
                ),
                const SizedBox(width: 12),
                Icon(LucideIcons.lock, color: badgeColor, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(node.longName, style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(LucideIcons.radioReceiver, color: dimTextColor, size: 12),
                          const SizedBox(width: 4),
                          Text(node.lastHeardText, style: TextStyle(color: dimTextColor, fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ),
                if (isLocal) Icon(LucideIcons.cloud, color: badgeColor, size: 20),
              ],
            ),
            const SizedBox(height: 16),

            if (isLocal)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(LucideIcons.zap, color: dimTextColor, size: 16),
                      const SizedBox(width: 6),
                      Expanded(child: Text("PWR ${node.voltage.toStringAsFixed(2)}V", style: TextStyle(color: dimTextColor, fontSize: 13, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis)),
                      Icon(LucideIcons.barChart2, color: dimTextColor, size: 16),
                      const SizedBox(width: 6),
                      Text("ChUtil 0.0%", style: TextStyle(color: dimTextColor, fontSize: 13)),
                    ],
                  ),
                ],
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(LucideIcons.battery, color: dimTextColor, size: 16),
                      const SizedBox(width: 6),
                      Text("${node.batteryLevel.toInt()}%", style: TextStyle(color: dimTextColor, fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(child: Text("SNR ${node.snr.toStringAsFixed(1)}dB  RSSI ${node.rssi ?? '--'}dBm", style: TextStyle(color: badgeColor, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis)),
                      const SizedBox(width: 4),
                      Icon(LucideIcons.signal, color: badgeColor, size: 14),
                      const SizedBox(width: 4),
                      Text(_getSignalQualityText(node.rssi), style: TextStyle(color: badgeColor, fontSize: 13, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ],
              ),
            
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildBottomIconText(LucideIcons.cpu, node.hardware, dimTextColor),
                _buildBottomIconText(LucideIcons.user, node.role, dimTextColor),
                _buildBottomIconText(LucideIcons.fingerprint, node.hexId, dimTextColor),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomIconText(IconData icon, String text, Color color) {
    return Expanded(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 4),
          Flexible(child: Text(text, style: TextStyle(color: color, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }
}