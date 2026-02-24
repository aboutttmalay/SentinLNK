import 'dart:io';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../../../core/theme/app_colors.dart';
import '../../widgets/pulse_animation.dart';
import '../scanning/scan_screen.dart';
import 'widgets/chat_tile.dart';
import '../settings/settings_tab.dart';
import '../nodes/nodes_screen.dart'; // 👉 NEW: Imported our real Nodes Screen!

class HomeScreen extends StatefulWidget {
  final bool isConnected;
  final VoidCallback onAction; 
  final VoidCallback? onDisconnect;

  const HomeScreen({
    super.key,
    required this.isConnected,
    required this.onAction,
    this.onDisconnect,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // To track which tab is selected (0 = Messages, 1 = Nodes, 2 = Settings)
  int _currentTabIndex = 0;

  // ==========================================
  // HARDWARE MANAGEMENT MENU (The 3-Dot Options)
  // ==========================================
  Widget _buildOptionButton({
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
                  Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textDim)),
                ],
              ),
            ),
            Icon(LucideIcons.chevronRight, color: AppColors.textDim, size: 20),
          ],
        ),
      ),
    );
  }

  void _showConfirmDialog({
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

  Future<void> _showConnectionInfoDialog() async {
    Navigator.pop(context); 
    
    var devices = FlutterBluePlus.connectedDevices;
    if (devices.isEmpty) return;
    BluetoothDevice device = devices.first;

    showDialog(
      context: context,
      barrierDismissible: false, 
      builder: (BuildContext c) => const Center(child: CircularProgressIndicator(color: AppColors.primary))
    );

    int rssi = -100;
    String battery = "N/A";
    String firmware = "N/A";

    try {
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

    if (mounted) Navigator.of(context, rootNavigator: true).pop();

    if (mounted) {
      showDialog(
        context: context,
        builder: (c) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text("🟢 NODE TELEMETRY", style: TextStyle(color: Colors.greenAccent)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("DEVICE: ${device.platformName.isNotEmpty ? device.platformName : 'Saved Node'}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              const Divider(color: Colors.white24),
              Text("SIGNAL (RSSI): $rssi dBm", style: const TextStyle(color: AppColors.textDim)),
              const SizedBox(height: 10),
              Text("BATTERY: $battery", style: const TextStyle(color: AppColors.textDim)),
              const SizedBox(height: 10),
              Text("FIRMWARE: $firmware", style: const TextStyle(color: AppColors.textDim)),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: const Text("CLOSE", style: TextStyle(color: AppColors.textDim))),
          ],
        ),
      );
    }
  }

  void _handleForgetDevice() {
    Navigator.pop(context); 
    _showConfirmDialog(
      title: "Forget Device?",
      message: "This will permanently sever the link and wipe security keys. This cannot be undone.",
      onConfirm: () async {
        var devices = FlutterBluePlus.connectedDevices;
        if (devices.isNotEmpty) {
          BluetoothDevice device = devices.first;
          await device.disconnect();
          if (Platform.isAndroid) {
            try {
              await device.removeBond(); 
              await device.clearGattCache(); 
            } catch (e) {
              print("Error wiping device: $e");
            }
          }
        }
        
        // Wipes the tactical memory
        ScanScreen.lastKnownNode = null; 

        if (widget.onDisconnect != null) widget.onDisconnect!();
      },
    );
  }

  void _showHardwareMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
              margin: const EdgeInsets.only(bottom: 12),
            ),
            const SizedBox(height: 4),

            _buildOptionButton(
              icon: LucideIcons.wifi, label: "Connection Info", subtitle: "View live hardware telemetry",
              onTap: () => _showConnectionInfoDialog(),
            ),
            const SizedBox(height: 10),

            _buildOptionButton(
              icon: LucideIcons.powerOff, label: "Disconnect", subtitle: "Temporarily disconnect", color: Colors.orange,
              onTap: () {
                Navigator.pop(context);
                _showConfirmDialog(
                  title: "Disconnect Node?",
                  message: "Do you want to disconnect? Chat history will be securely saved.",
                  onConfirm: () async {
                    var devices = FlutterBluePlus.connectedDevices;
                    if (devices.isNotEmpty) {
                      await devices.first.disconnect();
                    }
                    if (widget.onDisconnect != null) widget.onDisconnect!();
                  },
                );
              },
            ),
            const SizedBox(height: 10),

            _buildOptionButton(
              icon: LucideIcons.trash2, label: "Forget Device", subtitle: "Remove device and history", color: Colors.red,
              onTap: _handleForgetDevice,
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // CUSTOM TACTICAL FOOTER (UPDATED)
  // ==========================================
  Widget _buildFooterTab(IconData icon, String label, int index) {
    bool isSelected = _currentTabIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _currentTabIndex = index;
        });
      },
      child: Container(
        color: Colors.transparent, // Increases tap target area safely
        width: 70, // Gives each icon an equal, invisible bounding box
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon, 
              color: isSelected ? AppColors.primary : AppColors.textDim,
              size: 22,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? AppColors.primary : AppColors.textDim,
                letterSpacing: 0.5,
              ),
              maxLines: 1, // Prevents text from breaking layout
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBlinkingHardwareLogo() {
    return GestureDetector(
      onTap: widget.isConnected ? _showHardwareMenu : widget.onAction,
      child: Container(
        color: Colors.transparent,
        width: 70, // Match the width of the other tabs for perfect balance
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            PulseAnimation(
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (widget.isConnected ? AppColors.primary : Colors.orange).withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  widget.isConnected ? LucideIcons.cpu : LucideIcons.scanLine, 
                  color: widget.isConnected ? AppColors.primary : Colors.orange,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              widget.isConnected ? "UPLINK" : "SCAN",
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: widget.isConnected ? AppColors.primary : Colors.orange,
                letterSpacing: 0.5,
              ),
              maxLines: 1,
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // MAIN UI
  // ==========================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      
      // Main Content Area
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _currentTabIndex == 0 
                ? ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      ChatTile(
                        name: "Alpha Squad",
                        message: widget.isConnected ? "Sector 4 clear. Requesting extraction." : "Connection required...",
                        time: "09:41", isUnread: true, isConnected: widget.isConnected, onTap: widget.isConnected ? widget.onAction : () {},
                      ),
                      ChatTile(
                        name: "Command HQ",
                        message: widget.isConnected ? "Update SITREP immediately." : "Connection required...",
                        time: "09:30", isUnread: false, isConnected: widget.isConnected, onTap: () {},
                      ),
                    ],
                  )
                : _currentTabIndex == 1
                    ? const NodesScreen() // 👉 THE FIX: IT NOW LOADS THE ACTUAL NODES SCREEN!
                    : SettingsTab(isConnected: widget.isConnected), 
            ),
          ],
        ),
      ),

      
      // ==========================================
      // THE NEW EQUALLY SPACED TACTICAL FOOTER
      // ==========================================
      bottomNavigationBar: Container(
        height: 75,
        decoration: const BoxDecoration(
          color: AppColors.surface, 
          border: Border(top: BorderSide(color: AppColors.border, width: 1)),
        ),
        padding: EdgeInsets.only(bottom: Platform.isIOS ? 15 : 0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly, 
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Option 1: Messages
            _buildFooterTab(LucideIcons.messageSquare, "Messages", 0),
            
            // Option 2: Nodes
            _buildFooterTab(LucideIcons.network, "NODES", 1),
            
            // Option 3: Settings
            _buildFooterTab(LucideIcons.settings, "Settings", 2),

            // Option 4: The Hardware Options Menu 
            _buildBlinkingHardwareLogo(),
          ],
        ),
      ),
    );
  }
}