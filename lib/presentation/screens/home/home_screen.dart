import 'dart:io';
import 'dart:math' as math; 
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../../../core/theme/app_colors.dart';
import '../../widgets/pulse_animation.dart';
import '../scanning/scan_screen.dart';
import 'widgets/chat_tile.dart';
import '../settings/settings_tab.dart';
import '../nodes/nodes_screen.dart';
import '../../../core/storage/storage_service.dart'; 
import '../../../core/services/hardware_bridge.dart'; 
import '../../../data/models/node_database.dart';
import '../chat/active_chat_screen.dart'; 

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
  int _currentTabIndex = 0;

  @override
  void initState() {
    super.initState();
    
    // 👉 FIX 1: Removed connectAndSync() here because ScanScreen now handles it completely!
    
    // 👉 FEATURE 3: GLOBAL MESSAGE LISTENER
    NodeDatabase.instance.latestIncomingMessage.addListener(_onGlobalMessageReceived);
  }

  @override
  void dispose() {
    NodeDatabase.instance.latestIncomingMessage.removeListener(_onGlobalMessageReceived);
    super.dispose();
  }

  // ==========================================
  // 💬 GLOBAL MESSAGE POP-UP ALERT
  // ==========================================
  void _onGlobalMessageReceived() {
    final rawMsg = NodeDatabase.instance.latestIncomingMessage.value;
    if (rawMsg != null) {
      final parts = rawMsg.split('|');
      if (parts.length >= 2) {
        String type = parts[0];
        String text = parts[1];
        
        // CHECK: Are we currently looking at the Chat Screen?
        // If 'isCurrent' is true, it means we are on the Home Screen (Nodes/Settings/Menu)
        // and NOT inside the ActiveChatScreen. So we show the popup!
        if (ModalRoute.of(context)?.isCurrent == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.only(bottom: 80, left: 16, right: 16), // Floats above the bottom nav bar
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              content: Row(
                children: [
                  Icon(type == "SQUAD" ? LucideIcons.shieldCheck : LucideIcons.messageSquare, color: Colors.white, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text("NEW ${type == 'SQUAD' ? 'ENCRYPTED' : 'GLOBAL'} MESSAGE", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white70)),
                        Text(text, style: const TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                ],
              ),
              backgroundColor: type == "SQUAD" ? Colors.green[800] : AppColors.primary,
              duration: const Duration(seconds: 4),
            )
          );
        }
      }
    }
  }

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
              decoration: BoxDecoration(color: color.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
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

  void _showConfirmDialog({required String title, required String message, required VoidCallback onConfirm}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: Text(message, style: const TextStyle(color: AppColors.textDim)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL", style: TextStyle(color: AppColors.textDim))),
          TextButton(onPressed: () { Navigator.pop(context); onConfirm(); }, child: const Text("CONFIRM", style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }

  Future<void> _showConnectionInfoDialog() async {
    Navigator.pop(context); 
    var devices = FlutterBluePlus.connectedDevices;
    if (devices.isEmpty) return;
    BluetoothDevice device = devices.first;

    showDialog(context: context, barrierDismissible: false, builder: (BuildContext c) => const Center(child: CircularProgressIndicator(color: AppColors.primary)));

    int rssi = -100; String battery = "N/A"; String firmware = "N/A";

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
    } catch (e) {}

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
          actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text("CLOSE", style: TextStyle(color: AppColors.textDim)))],
        ),
      );
    }
  }

  void _handleForgetDevice() {
    Navigator.pop(context); 
    _showConfirmDialog(
      title: "Forget Device?",
      message: "This will permanently sever the link, wipe security keys, and DELETE ALL CHAT HISTORY. This cannot be undone.",
      onConfirm: () async {
        
        // 1. Wipe Hard Storage Logs
        await StorageService.clearLogs();
        
        // 2. INSTANTLY WIPE ALL IN-MEMORY BUFFERS (Nodes, Chat, Squad, Pipeline)
        NodeDatabase.instance.clearDatabase();
        
        // 3. Unpair and disconnect the hardware
        await HardwareBridge.instance.disconnectAndUnpair();
        
        print("🗑️ TACTICAL LOGS & BUFFERS WIPED.");
        
        // 👉 FIXED: Removed the outdated ScanScreen.lastKnownNode = null; 
        // Our new StorageService handles all of this automatically now!
        
        // 4. Return to Scan Screen
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
            Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)), margin: const EdgeInsets.only(bottom: 12)),
            const SizedBox(height: 4),
            _buildOptionButton(icon: LucideIcons.wifi, label: "Connection Info", subtitle: "View live hardware telemetry", onTap: () => _showConnectionInfoDialog()),
            const SizedBox(height: 10),
            _buildOptionButton(
              icon: LucideIcons.powerOff, label: "Disconnect", subtitle: "Temporarily disconnect", color: Colors.orange,
              onTap: () {
                Navigator.pop(context);
                _showConfirmDialog(title: "Disconnect Node?", message: "Do you want to disconnect? Chat history will be securely saved.",
                  onConfirm: () async {
                    var devices = FlutterBluePlus.connectedDevices;
                    if (devices.isNotEmpty) await devices.first.disconnect();
                    if (widget.onDisconnect != null) widget.onDisconnect!();
                  });
              },
            ),
            const SizedBox(height: 10),
            _buildOptionButton(icon: LucideIcons.trash2, label: "Forget Device", subtitle: "Remove device and history", color: Colors.red, onTap: _handleForgetDevice),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildFooterTab(IconData icon, String label, int index) {
    bool isSelected = _currentTabIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentTabIndex = index),
      child: Container(
        color: Colors.transparent, width: 70, 
        child: Column(
          mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isSelected ? AppColors.primary : AppColors.textDim, size: 22),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 10, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? AppColors.primary : AppColors.textDim, letterSpacing: 0.5), maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  Widget _buildBlinkingHardwareLogo() {
    return GestureDetector(
      onTap: widget.isConnected ? _showHardwareMenu : widget.onAction,
      child: Container(
        color: Colors.transparent, width: 70, 
        child: Column(
          mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center,
          children: [
            PulseAnimation(
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: (widget.isConnected ? AppColors.primary : Colors.orange).withValues(alpha: 0.2), shape: BoxShape.circle),
                child: Icon(widget.isConnected ? LucideIcons.cpu : LucideIcons.scanLine, color: widget.isConnected ? AppColors.primary : Colors.orange, size: 20),
              ),
            ),
            const SizedBox(height: 2),
            Text(widget.isConnected ? "UPLINK" : "SCAN", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: widget.isConnected ? AppColors.primary : Colors.orange, letterSpacing: 0.5), maxLines: 1),
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
            Expanded(
              child: _currentTabIndex == 0 
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Expanded(
                              child: Text(
                                "MESSAGES",
                                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.2),
                                maxLines: 1, overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (widget.isConnected)
                              GestureDetector(
                                onTap: () => showDialog(context: context, builder: (context) => const SquadSetupDialog()),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min, 
                                    children: [
                                      Icon(LucideIcons.shieldCheck, color: AppColors.primary, size: 14),
                                      SizedBox(width: 6),
                                      Text("SQUAD SETUP", style: TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      
                      Expanded(
                        child: ValueListenableBuilder<String>(
                          valueListenable: HardwareBridge.instance.currentSquad,
                          builder: (context, squadName, child) {
                            
                            List<Widget> chatTiles = [];

                            // 1. ALWAYS SHOW GLOBAL MESH
                            chatTiles.add(
                              ChatTile(
                                name: "Global Mesh",
                                message: widget.isConnected 
                                  ? (squadName == "Global Mesh" ? "Public frequency open." : "Active on background channel.") 
                                  : "Hardware disconnected...",
                                time: "Active", 
                                isUnread: squadName == "Global Mesh", 
                                isConnected: widget.isConnected, 
                                onTap: widget.isConnected ? () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ActiveChatScreen(
                                        chatName: "Global Mesh",
                                        onBack: () => Navigator.pop(context),
                                      ),
                                    ),
                                  );
                                } : () {},
                              )
                            );

                            // 2. SHOW SECURE SQUAD MESH
                            if (squadName != "Global Mesh") {
                              String squadTitle = "Squad: $squadName";
                              chatTiles.add(
                                ChatTile(
                                  name: squadTitle,
                                  message: widget.isConnected ? "Secure AES-256 channel active." : "Hardware disconnected...",
                                  time: "Now", 
                                  isUnread: true, 
                                  isConnected: widget.isConnected, 
                                  onTap: widget.isConnected ? () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => ActiveChatScreen(
                                          chatName: squadTitle,
                                          onBack: () => Navigator.pop(context),
                                        ),
                                      ),
                                    );
                                  } : () {},
                                )
                              );
                            }

                            return ListView(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              children: chatTiles,
                            );
                          },
                        ),
                      ),
                    ],
                  )
                : _currentTabIndex == 1
                    ? const NodesScreen() 
                    : SettingsTab(isConnected: widget.isConnected), 
            ),
          ],
        ),
      ),
      
      bottomNavigationBar: Container(
        height: 75,
        decoration: const BoxDecoration(color: AppColors.surface, border: Border(top: BorderSide(color: AppColors.border, width: 1))),
        padding: EdgeInsets.only(bottom: Platform.isIOS ? 15 : 0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly, 
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildFooterTab(LucideIcons.messageSquare, "Messages", 0),
            _buildFooterTab(LucideIcons.network, "NODES", 1),
            _buildFooterTab(LucideIcons.settings, "Settings", 2),
            _buildBlinkingHardwareLogo(),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 🛡️ SQUAD SETUP DIALOG UI
// ==========================================
class SquadSetupDialog extends StatefulWidget {
  const SquadSetupDialog({super.key});

  @override
  State<SquadSetupDialog> createState() => _SquadSetupDialogState();
}

class _SquadSetupDialogState extends State<SquadSetupDialog> {
  bool _isJoining = false;
  String _generatedCode = "";
  final TextEditingController _joinController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _generateCode();
  }

  void _generateCode() {
    const chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
    final rnd = math.Random();
    String code = String.fromCharCodes(Iterable.generate(6, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))));
    setState(() {
      _generatedCode = "${code.substring(0, 3)}-${code.substring(3, 6)}";
    });
  }

  void _applyCode(String code) {
    if (code.trim().isEmpty) return;
    String cleanCode = code.replaceAll("-", "").toUpperCase().trim();
    
    // Call the hardware bridge!
    HardwareBridge.instance.setGroupCode(cleanCode);
    
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("🟢 ENCRYPTING CHANNEL...\nCode: $cleanCode\nHardware will now reboot onto the private mesh."), 
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.bg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: AppColors.border)),
      title: Row(
        children: [
          Icon(_isJoining ? LucideIcons.logIn : LucideIcons.shieldAlert, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _isJoining ? "JOIN SQUAD" : "CREATE SQUAD", 
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _isJoining 
              ? "Enter the 6-character group code from your squad leader to sync encryption keys."
              : "Share this highly secure code with your squad. Anyone with this code will instantly sync to your private AES-256 frequency.",
            style: const TextStyle(color: AppColors.textDim, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 24),
          
          if (!_isJoining) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.primary.withValues(alpha: 0.3))),
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(_generatedCode, style: const TextStyle(color: AppColors.primary, fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 4)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: _generateCode,
              icon: const Icon(LucideIcons.refreshCw, color: AppColors.textDim, size: 16),
              label: const Text("GENERATE NEW CODE", style: TextStyle(color: AppColors.textDim)),
            )
          ] else ...[
            TextField(
              controller: _joinController,
              textCapitalization: TextCapitalization.characters,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 4),
              decoration: InputDecoration(
                hintText: "XXX-XXX",
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.1)),
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.primary)),
              ),
            ),
          ]
        ],
      ),
      actionsPadding: const EdgeInsets.all(16),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: [
        TextButton(
          onPressed: () => setState(() => _isJoining = !_isJoining),
          child: Text(_isJoining ? "CREATE INSTEAD" : "JOIN EXISTING", style: const TextStyle(color: AppColors.textDim, fontSize: 11)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
          onPressed: () => _applyCode(_isJoining ? _joinController.text : _generatedCode),
          child: const Text("SECURE LINK", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12)),
        ),
      ],
    );
  }
}