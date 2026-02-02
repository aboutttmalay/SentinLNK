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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // 1. Tactical Status Bar
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              color: isConnected ? AppColors.primaryDim : AppColors.alert,
              child: Row(
                children: [
                  Icon(
                    isConnected ? LucideIcons.activity : LucideIcons.alertTriangle,
                    color: Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    isConnected ? "MESH ACTIVE // 4 NODES" : "NO HARDWARE DETECTED",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                      fontSize: 12,
                    ),
                  ),
                  const Spacer(),
                  if (isConnected) 
                    const Row(
                      children: [
                        Icon(LucideIcons.battery, size: 14, color: Colors.white70),
                        SizedBox(width: 4),
                        Text("85%", style: TextStyle(fontSize: 12, color: Colors.white70)),
                      ],
                    )
                ],
              ),
            ),

            // 2. Chat List
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
      
      // 3. Scan Button (Only visible when disconnected)
      floatingActionButton: !isConnected
          ? FloatingActionButton.extended(
              onPressed: onAction,
              backgroundColor: AppColors.primary,
              icon: const Icon(LucideIcons.scanLine, color: Colors.white),
              label: const Text("SCAN MESH", style: TextStyle(color: Colors.white)),
            )
          : null,
    );
  }
}