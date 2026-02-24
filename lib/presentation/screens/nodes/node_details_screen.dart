import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

// 👉 WE REMOVED tactical_node.dart BECAUSE IT IS NOW INSIDE node_database.dart!
import '../../../data/models/node_database.dart'; 

class NodeDetailsScreen extends StatelessWidget {
  final TacticalNode node; // Fixed the variable name

  const NodeDetailsScreen({super.key, required this.node}); // Fixed constructor

  @override
  Widget build(BuildContext context) {
    // 👉 Make the details screen listen to the live database!
    return ValueListenableBuilder<Map<String, TacticalNode>>(
      valueListenable: NodeDatabase.instance.radarMap,
      builder: (context, nodesMap, child) {
        
        // Grab the most up-to-date version of this node from the database
        // If it updates in the background, this screen will instantly redraw!
        final liveNode = nodesMap[node.hexId] ?? node;

        String nodeNumStr = "Unknown";
        if (liveNode.hexId.startsWith('!')) {
          try {
            nodeNumStr = int.parse(liveNode.hexId.substring(1), radix: 16).toString();
          } catch (_) {}
        }

        return Scaffold(
          backgroundColor: const Color(0xFF0F1714),
          appBar: AppBar(
            backgroundColor: const Color(0xFF0F1714),
            elevation: 0,
            leading: IconButton(
              icon: const Icon(LucideIcons.arrowLeft, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Details", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                Text(liveNode.longName, style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader("Details"),
                _buildCard([
                  _buildRowData("Short Name", liveNode.shortName, "Device Role", liveNode.role),
                  const Divider(color: Color(0xFF2A3630), height: 32),
                  _buildRowData("Node ID", liveNode.hexId, "Node Number", nodeNumStr),
                  const Divider(color: Color(0xFF2A3630), height: 32),
                  _buildSingleData("Last heard", liveNode.lastHeardText),
                  const Divider(color: Color(0xFF2A3630), height: 32),
                  _buildRowData("User ID", liveNode.hexId, "Uptime", "Online"),
                  const Divider(color: Color(0xFF2A3630), height: 32),
                  _buildSingleData("Public Key", "gV14UwP... (Encrypted)", icon: LucideIcons.lock),
                ]),

                _buildSectionHeader("Telemetry"),
                _buildCard([
                  // NOW THIS WILL UPDATE LIVE!
                  _buildTelemetryRow(LucideIcons.battery, "Battery: ${liveNode.batteryLevel.toInt()}%", active: liveNode.batteryLevel > 0),
                  const Divider(color: Color(0xFF2A3630), height: 24),
                  _buildTelemetryRow(LucideIcons.zap, "Voltage: ${liveNode.voltage.toStringAsFixed(2)}V"),
                  const Divider(color: Color(0xFF2A3630), height: 24),
                  _buildTelemetryRow(LucideIcons.signal, "SNR: ${liveNode.snr} dB"),
                ]),

                _buildSectionHeader("Device"),
                _buildCard([
                  Center(
                    child: Container(
                      width: 80, height: 80,
                      decoration: const BoxDecoration(color: Color(0xFF8A6222), shape: BoxShape.circle),
                      child: const Icon(LucideIcons.radio, color: Colors.white, size: 40),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      const Icon(LucideIcons.cpu, color: Colors.grey, size: 18),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Hardware", style: TextStyle(color: Colors.grey, fontSize: 12)),
                          Text(liveNode.hardware, style: const TextStyle(color: Colors.white, fontSize: 14)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Row(
                    children: [
                      Icon(LucideIcons.checkCircle2, color: Color(0xFF22C55E), size: 18),
                      SizedBox(width: 12),
                      Text("Supported", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ]),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 24, bottom: 8),
      child: Text(title, style: const TextStyle(color: Color(0xFF86EFAC), fontSize: 16, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF142415), borderRadius: BorderRadius.circular(20)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }

  Widget _buildRowData(String title1, String val1, String title2, String val2) {
    return Row(
      children: [
        Expanded(child: _buildSingleData(title1, val1)),
        Expanded(child: _buildSingleData(title2, val2)),
      ],
    );
  }

  Widget _buildSingleData(String title, String value, {IconData? icon}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (icon != null) ...[Icon(icon, color: Colors.grey, size: 12), const SizedBox(width: 4)],
            Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildTelemetryRow(IconData icon, String title, {bool active = false}) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF86EFAC), size: 18),
        const SizedBox(width: 12),
        Expanded(child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 14))),
        if (active)
          Container(
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(color: Color(0xFF22C55E), shape: BoxShape.circle),
            child: const Icon(LucideIcons.check, color: Colors.black, size: 12),
          ),
      ],
    );
  }
}