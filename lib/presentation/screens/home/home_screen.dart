import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_colors.dart';
import 'widgets/chat_tile.dart';

class HomeScreen extends StatelessWidget {
  final bool isConnected;
  final VoidCallback onAction; // Triggers Scan (if disconnected) or Chat (if connected)

  const HomeScreen({
    super.key,
    required this.isConnected,
    required this.onAction,
  });

  static Widget _buildOptionButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String subtitle,
    required VoidCallback onTap,
    Color color = const Color(0xFF22C55E),
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textDim,
                    ),
                  ),
                ],
              ),
            ),
            Icon(LucideIcons.chevronRight, color: AppColors.textDim, size: 20),
          ],
        ),
      ),
    );
  }

  static void _showConfirmDialog(
    BuildContext context, {
    required String title,
    required String message,
    required VoidCallback onConfirm,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: Text(message, style: const TextStyle(color: AppColors.textDim)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("CANCEL", style: TextStyle(color: AppColors.textDim)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onConfirm();
            },
            child: const Text("CONFIRM", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showConnectionMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
              margin: const EdgeInsets.only(bottom: 12),
            ),
            const SizedBox(height: 4),
            _buildOptionButton(
              context: context,
              icon: LucideIcons.wifi,
              label: "Connection Info",
              subtitle: "View device details",
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Device: Alpha Squad\nStatus: Connected\nSignal: Strong"),
                    duration: Duration(seconds: 3),
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
            _buildOptionButton(
              context: context,
              icon: LucideIcons.powerOff,
              label: "Disconnect",
              subtitle: "Temporarily disconnect",
              color: Colors.orange,
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Device disconnected"),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
            _buildOptionButton(
              context: context,
              icon: LucideIcons.shuffle,
              label: "Unpair Device",
              subtitle: "Remove pairing (keep history)",
              color: Colors.amber,
              onTap: () {
                Navigator.pop(context);
                _showConfirmDialog(
                  context,
                  title: "Unpair Device?",
                  message: "Connection will be removed but chat history will be saved.",
                  onConfirm: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Device unpaired")),
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 10),
            _buildOptionButton(
              context: context,
              icon: LucideIcons.trash2,
              label: "Forget Device",
              subtitle: "Remove device and history",
              color: Colors.red,
              onTap: () {
                Navigator.pop(context);
                _showConfirmDialog(
                  context,
                  title: "Forget Device?",
                  message: "This will remove the device and ALL chat history. This cannot be undone.",
                  onConfirm: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Device forgotten")),
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // 1. Chat List
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  ChatTile(
                    name: "Alpha Squad",
                    message: "Sector 4 clear. Requesting extraction.",
                    time: "09:41",
                    isUnread: true,
                    isConnected: isConnected,
                    onTap: onAction,
                  ),
                  ChatTile(
                    name: "Command HQ",
                    message: "Update SITREP immediately.",
                    time: "09:30",
                    isUnread: false,
                    isConnected: isConnected,
                    onTap: () {},
                  ),
                  ChatTile(
                    name: "Medic Team",
                    message: "Supplies dropped at WP-2.",
                    time: "09:15",
                    isUnread: false,
                    isConnected: isConnected,
                    onTap: () {},
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      
      // 2. Action Button
      floatingActionButton: isConnected
          ? FloatingActionButton(
              onPressed: () => _showConnectionMenu(context),
              backgroundColor: AppColors.primary,
              child: const Icon(LucideIcons.moreVertical, color: Colors.white),
            )
          : FloatingActionButton.extended(
              onPressed: onAction,
              backgroundColor: AppColors.primary,
              icon: const Icon(LucideIcons.scanLine, color: Colors.white),
              label: const Text("SCAN MESH", style: TextStyle(color: Colors.white)),
            ),
    );
  }
}