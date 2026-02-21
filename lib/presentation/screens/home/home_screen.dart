import 'dart:io';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../../../core/theme/app_colors.dart';
import 'widgets/chat_tile.dart';
import '../scanning/scan_screen.dart'; // 👉 Added this import for Tactical Memory!

class HomeScreen extends StatelessWidget {
  final bool isConnected;
  final VoidCallback onAction; 
  final VoidCallback? onDisconnect;

  const HomeScreen({
    super.key,
    required this.isConnected,
    required this.onAction,
    this.onDisconnect,
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

  // 🟢 CONNECTION INFO (REAL HARDWARE TELEMETRY)
  Future<void> _showConnectionInfoDialog(BuildContext context) async {
    Navigator.pop(context); // Close bottom sheet
    
    var devices = FlutterBluePlus.connectedDevices;
    if (devices.isEmpty) return;
    BluetoothDevice device = devices.first;

    // Show loading spinner
    showDialog(
      context: context,
      barrierDismissible: false, // Prevents user from tapping out
      builder: (BuildContext c) => const Center(child: CircularProgressIndicator(color: AppColors.primary))
    );

    int rssi = -100;
    String battery = "N/A";
    String firmware = "N/A";

    try {
      // A strict 5-second timeout. If the hardware hangs, it aborts the wait!
      await Future(() async {
        rssi = await device.readRssi();
        List<BluetoothService> services = await device.discoverServices();
        
        for (var s in services) {
          if (s.uuid.toString().toUpperCase().contains("180F")) { 
            for (var c in s.characteristics) {
              if (c.uuid.toString().toUpperCase().contains("2A19")) {
                var val = await c.read();
                if (val.isNotEmpty) battery = "${val[0]}%";
              }
            }
          }
          if (s.uuid.toString().toUpperCase().contains("180A")) { 
            for (var c in s.characteristics) {
              if (c.uuid.toString().toUpperCase().contains("2A26")) { 
                var val = await c.read();
                if (val.isNotEmpty) firmware = String.fromCharCodes(val);
              }
            }
          }
        }
      }).timeout(const Duration(seconds: 5)); 
      
    } catch (e) {
      print("Telemetry Error / Timeout: $e");
    }

    // Safely pop the loading spinner using context.mounted
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }

    // Show Info Dialog with whatever data we successfully grabbed
    if (context.mounted) {
      showDialog(
        context: context,
        builder: (c) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text("🟢 NODE TELEMETRY", style: TextStyle(color: Colors.greenAccent)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("DEVICE: ${device.platformName}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              const Divider(color: Colors.white24),
              Text("SIGNAL (RSSI): $rssi dBm", style: const TextStyle(color: AppColors.textDim)),
              const SizedBox(height: 10),
              Text("BATTERY: $battery", style: const TextStyle(color: AppColors.textDim)),
              const SizedBox(height: 10),
              Text("FIRMWARE: $firmware", style: const TextStyle(color: AppColors.textDim)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text("CLOSE", style: TextStyle(color: AppColors.textDim)),
            ),
          ],
        ),
      );
    }
  }

  void _handleForgetDevice(BuildContext context) {
    Navigator.pop(context); // Close the bottom sheet menu
    
    _showConfirmDialog(
      context,
      title: "Forget Device?",
      message: "This will permanently sever the link and wipe security keys. This cannot be undone.",
      onConfirm: () async {
        var devices = FlutterBluePlus.connectedDevices;
        if (devices.isNotEmpty) {
          BluetoothDevice device = devices.first;
          await device.disconnect();
          if (Platform.isAndroid) {
            try {
              await device.removeBond(); // Wipes security keys
              await device.clearGattCache(); // Wipes Android memory
            } catch (e) {
              print("Error wiping device: $e");
            }
          }
        }
        
        // 👉 THIS COMPLETELY WIPES THE TACTICAL MEMORY!
        ScanScreen.lastKnownNode = null; 

        // Update the UI back to disconnected state
        if (onDisconnect != null) onDisconnect!();
      },
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

            // 1. CONNECTION INFO
            _buildOptionButton(
              context: context,
              icon: LucideIcons.wifi,
              label: "Connection Info",
              subtitle: "View live hardware telemetry",
              onTap: () => _showConnectionInfoDialog(context), 
            ),
            const SizedBox(height: 10),

            // 2. DISCONNECT 
            _buildOptionButton(
              context: context,
              icon: LucideIcons.powerOff,
              label: "Disconnect",
              subtitle: "Temporarily disconnect",
              color: Colors.orange,
              onTap: () {
                Navigator.pop(context);
                _showConfirmDialog(
                  context,
                  title: "Disconnect Node?",
                  message: "Do you want to disconnect? Chat history will be securely saved.",
                  onConfirm: () async {
                    var devices = FlutterBluePlus.connectedDevices;
                    if (devices.isNotEmpty) {
                      // Just a simple, soft disconnect! Android will remember the name.
                      await devices.first.disconnect();
                      
                      // Wait briefly for the radio to reset its beacon
                      await Future.delayed(const Duration(milliseconds: 500));
                    }
                    if (onDisconnect != null) onDisconnect!();
                  },
                );
              },
            ),
            const SizedBox(height: 10),

            // 3. FORGET DEVICE
            _buildOptionButton(
              context: context,
              icon: LucideIcons.trash2,
              label: "Forget Device",
              subtitle: "Remove device and history",
              color: Colors.red,
              onTap: () => _handleForgetDevice(context), // 👉 Fixed the duplicate onTap error here!
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
      backgroundColor: AppColors.bg,
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
                    message: isConnected ? "Sector 4 clear. Requesting extraction." : "Connection required...",
                    time: "09:41",
                    isUnread: true,
                    isConnected: isConnected,
                    onTap: isConnected ? onAction : () {},
                  ),
                  ChatTile(
                    name: "Command HQ",
                    message: isConnected ? "Update SITREP immediately." : "Connection required...",
                    time: "09:30",
                    isUnread: false,
                    isConnected: isConnected,
                    onTap: () {},
                  ),
                  ChatTile(
                    name: "Medic Team",
                    message: isConnected ? "Supplies dropped at WP-2." : "Connection required...",
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