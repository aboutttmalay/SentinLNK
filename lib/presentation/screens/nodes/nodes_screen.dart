import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../data/models/node_database.dart';
import 'node_details_screen.dart';
import '../../../core/services/hardware_bridge.dart';
import '../../../core/theme/app_colors.dart'; // 👉 Uses your app's actual theme!

class NodesScreen extends StatefulWidget {
  const NodesScreen({super.key});

  @override
  State<NodesScreen> createState() => _NodesScreenState();
}

class _NodesScreenState extends State<NodesScreen> {
  @override
  void initState() {
    super.initState();
    HardwareBridge.instance.connectAndSync();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Map<String, TacticalNode>>(
      valueListenable: NodeDatabase.instance.radarMap,
      builder: (context, nodesMap, child) {
        final nodes = nodesMap.values.toList();

        // Sort: Local node at the top, then alphabetically
        nodes.sort((a, b) {
          if (a.isLocal && !b.isLocal) return -1;
          if (!a.isLocal && b.isLocal) return 1;
          return a.longName.compareTo(b.longName);
        });

        // We use a Container instead of a Scaffold so it seamlessly blends into your HomeScreen
        return Container(
          color: AppColors.bg,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              
              // ==========================================
              // CUSTOM TACTICAL HEADER (Matches Chat Screen)
              // ==========================================
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "TACTICAL NODES",
                          style: TextStyle(
                            fontSize: 20, 
                            fontWeight: FontWeight.bold, 
                            color: Colors.white,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "${nodes.length} ACTIVE SIGNALS",
                          style: const TextStyle(
                            fontSize: 10, 
                            color: AppColors.primary, 
                            letterSpacing: 1.5
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(LucideIcons.listFilter, color: Colors.white),
                      onPressed: () {},
                    )
                  ],
                ),
              ),

              // ==========================================
              // SEARCH BAR
              // ==========================================
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
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.primary),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                ),
              ),

              // ==========================================
              // NODE LIST
              // ==========================================
              Expanded(
                child: nodes.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(color: AppColors.primary),
                            SizedBox(height: 16),
                            Text("📡 Syncing topology...",
                                 style: TextStyle(color: AppColors.textDim)),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () async {
                          await HardwareBridge.instance.connectAndSync();
                        },
                        color: AppColors.primary,
                        backgroundColor: AppColors.surface,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: nodes.length,
                          itemBuilder: (context, index) {
                            return _buildNodeCard(nodes[index]);
                          },
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ==========================================
  // NODE CARD UI (Styled like your original app)
  // ==========================================
  Widget _buildNodeCard(TacticalNode node) {
    final bool isLocal = node.isLocal;
    
    // Assign colors based on your app's theme
    final Color badgeColor = isLocal ? Colors.orangeAccent : AppColors.primary;
    final Color textColor = Colors.white;
    final Color dimTextColor = AppColors.textDim;

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
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            // Highlight the local node with an orange border
            color: isLocal ? Colors.orangeAccent.withValues(alpha: 0.3) : AppColors.border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            
            // --- 1. HEADER ROW ---
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.2), 
                    borderRadius: BorderRadius.circular(6)
                  ),
                  child: Text(
                    node.shortName,
                    style: TextStyle(color: badgeColor, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                const SizedBox(width: 12),
                Icon(LucideIcons.lock, color: badgeColor, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        node.longName,
                        style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
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
                if (isLocal)
                  Icon(LucideIcons.cloud, color: badgeColor, size: 20),
              ],
            ),
            const SizedBox(height: 16),

            // --- 2. TELEMETRY ROW ---
            if (isLocal)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(LucideIcons.zap, color: dimTextColor, size: 16),
                      const SizedBox(width: 6),
                      Text("PWR ${node.voltage.toStringAsFixed(2)}V", style: TextStyle(color: dimTextColor, fontSize: 13, fontWeight: FontWeight.w500)),
                      const SizedBox(width: 16),
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
                      Text("SNR ${node.snr}dB  RSSI ${node.rssi ?? '--'}dBm", style: TextStyle(color: badgeColor, fontSize: 13)),
                      const SizedBox(width: 12),
                      Icon(LucideIcons.signal, color: badgeColor, size: 14),
                      const SizedBox(width: 4),
                      Text("Good", style: TextStyle(color: badgeColor, fontSize: 13, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ],
              ),
            
            const SizedBox(height: 16),

            // --- 3. BOTTOM HARDWARE ROW ---
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

  // Safe builder to prevent text overflow layout crashes
  Widget _buildBottomIconText(IconData icon, String text, Color color) {
    return Expanded(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text, 
              style: TextStyle(color: color, fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}