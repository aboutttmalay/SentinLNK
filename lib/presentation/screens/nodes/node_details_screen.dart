import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../data/models/tactical_node.dart';
import '../../../data/models/node_database.dart'; 
import '../../../core/theme/app_colors.dart'; // 👉 Implements your SentinLNK Theme!

class NodeDetailsScreen extends StatelessWidget {
  final TacticalNode node;

  const NodeDetailsScreen({super.key, required this.node});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Map<String, TacticalNode>>(
      valueListenable: NodeDatabase.instance.radarMap,
      builder: (context, nodesMap, child) {
        
        final liveNode = nodesMap[node.hexId] ?? node;

        String nodeNumStr = "Unknown";
        if (liveNode.hexId.startsWith('!')) {
          try {
            nodeNumStr = int.parse(liveNode.hexId.substring(1), radix: 16).toString();
          } catch (_) {}
        }

        return Scaffold(
          backgroundColor: AppColors.bg, // 👉 Uses your app background
          appBar: AppBar(
            backgroundColor: AppColors.surface, // 👉 Uses your app surface
            elevation: 0,
            leading: IconButton(
              icon: const Icon(LucideIcons.chevronLeft, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "NODE DETAILS", 
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1)
                ),
                Text(
                  liveNode.longName.toUpperCase(), 
                  style: const TextStyle(color: AppColors.primary, fontSize: 10, letterSpacing: 1.5)
                ),
              ],
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1.0),
              child: Container(color: AppColors.border, height: 1.0),
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader("IDENTITY"),
                _buildCard([
                  _buildRowData("Short Name", liveNode.shortName, "Device Role", liveNode.role),
                  const Divider(color: AppColors.border, height: 32),
                  _buildRowData("Node ID", liveNode.hexId, "Node Number", nodeNumStr),
                  const Divider(color: AppColors.border, height: 32),
                  _buildSingleData("Last Heard", liveNode.lastHeardText),
                  const Divider(color: AppColors.border, height: 32),
                  _buildSingleData("Public Key", "gV14UwP... (Encrypted)", icon: LucideIcons.lock),
                ]),

                _buildSectionHeader("TELEMETRY"),
                _buildCard([
                  _buildTelemetryRow(LucideIcons.battery, "Battery: ${liveNode.batteryLevel.toInt()}%", active: liveNode.batteryLevel > 0),
                  const Divider(color: AppColors.border, height: 24),
                  _buildTelemetryRow(LucideIcons.zap, "Voltage: ${liveNode.voltage.toStringAsFixed(2)}V", active: liveNode.voltage > 0),
                  const Divider(color: AppColors.border, height: 24),
                  _buildTelemetryRow(LucideIcons.signal, "SNR: ${liveNode.snr} dB", active: true),
                ]),

                _buildSectionHeader("HARDWARE"),
                _buildCard([
                  Center(
                    child: Container(
                      width: 80, height: 80,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1), 
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 2),
                      ),
                      child: const Icon(LucideIcons.radio, color: AppColors.primary, size: 40),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      const Icon(LucideIcons.cpu, color: AppColors.textDim, size: 18),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Model", style: TextStyle(color: AppColors.textDim, fontSize: 12)),
                          Text(liveNode.hardware, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Row(
                    children: [
                      Icon(LucideIcons.checkCircle2, color: AppColors.primary, size: 18),
                      SizedBox(width: 12),
                      Text("Firmware Supported", style: TextStyle(color: AppColors.primary, fontSize: 14, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ]),
                
                const SizedBox(height: 24),
                
                // 👉 Full-width Share Button styled for SentinLNK
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(LucideIcons.qrCode, color: Colors.white, size: 18),
                    label: const Text("SHARE CONTACT", style: TextStyle(color: Colors.white, letterSpacing: 1, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: const BorderSide(color: AppColors.border),
                      backgroundColor: AppColors.surface,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 16, bottom: 8),
      child: Text(
        title, 
        style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5)
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface, 
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
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
            if (icon != null) ...[Icon(icon, color: AppColors.textDim, size: 12), const SizedBox(width: 4)],
            Text(title, style: const TextStyle(color: AppColors.textDim, fontSize: 12)),
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
        Icon(icon, color: AppColors.textDim, size: 18),
        const SizedBox(width: 12),
        Expanded(child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 14))),
        if (active)
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.2), shape: BoxShape.circle),
            child: const Icon(LucideIcons.check, color: AppColors.primary, size: 12),
          ),
      ],
    );
  }
}