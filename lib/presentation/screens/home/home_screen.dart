import 'dart:io';
import 'dart:math' as math; 
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:convert';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:meshtastic_flutter/generated/channel.pb.dart';

import '../../../core/theme/app_colors.dart';
import '../../widgets/pulse_animation.dart';
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
    NodeDatabase.instance.latestIncomingMessage.addListener(_onGlobalMessageReceived);
  }

  @override
  void dispose() {
    NodeDatabase.instance.latestIncomingMessage.removeListener(_onGlobalMessageReceived);
    super.dispose();
  }

  void _onGlobalMessageReceived() {
    final rawMsg = NodeDatabase.instance.latestIncomingMessage.value;
    if (rawMsg != null) {
      final parts = rawMsg.split('|');
      if (parts.length >= 2) {
        String type = parts[0];
        String text = parts[1];
        
        if (ModalRoute.of(context)?.isCurrent == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.only(bottom: 80, left: 16, right: 16),
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

  Widget _buildOptionButton({required IconData icon, required String label, required String subtitle, required VoidCallback onTap, Color color = const Color(0xFF22C55E)}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
        child: Row(
          children: [
            Container(width: 44, height: 44, decoration: BoxDecoration(color: color.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: color, size: 22)),
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
            const Icon(LucideIcons.chevronRight, color: AppColors.textDim, size: 20),
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
        await StorageService.clearLogs();
        NodeDatabase.instance.clearDatabase();
        await HardwareBridge.instance.disconnectAndUnpair();
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

  Widget _buildBlinkingHardwareLogo(bool isHardwareConnected) {
    return GestureDetector(
      onTap: isHardwareConnected ? _showHardwareMenu : widget.onAction,
      child: Container(
        color: Colors.transparent, width: 70, 
        child: Column(
          mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center,
          children: [
            PulseAnimation(
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: (isHardwareConnected ? AppColors.primary : Colors.orange).withValues(alpha: 0.2), shape: BoxShape.circle),
                child: Icon(isHardwareConnected ? LucideIcons.cpu : LucideIcons.scanLine, color: isHardwareConnected ? AppColors.primary : Colors.orange, size: 20),
              ),
            ),
            const SizedBox(height: 2),
            Text(isHardwareConnected ? "UPLINK" : "SCAN", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isHardwareConnected ? AppColors.primary : Colors.orange, letterSpacing: 0.5), maxLines: 1),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 👉 WATCHDOG WRAPPER: Listens to real-time hardware drops (like reboots)
    return ValueListenableBuilder<bool>(
      valueListenable: HardwareBridge.instance.isConnectedNotifier,
      builder: (context, isHardwareConnected, child) {
        return Scaffold(
          backgroundColor: AppColors.bg,
          floatingActionButton: _currentTabIndex == 0 && isHardwareConnected
              ? FloatingActionButton(
                  backgroundColor: AppColors.primary,
                  child: const Icon(LucideIcons.qrCode, color: Colors.black),
                  onPressed: () {
                    showDialog(context: context, builder: (context) => const SquadSetupDialog());
                  },
                )
              : null,

          body: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: _currentTabIndex == 0 
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                            child: Text(
                              "COMMUNICATION CHANNELS",
                              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.2),
                            ),
                          ),
                          Expanded(
                            child: ListView(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              children: [
                                ChatTile(
                                  name: "Global Mesh",
                                  message: isHardwareConnected ? "Public Channel 0 Active" : "Hardware disconnected...",
                                  time: "Live", 
                                  isUnread: false, 
                                  isConnected: isHardwareConnected, 
                                  onTap: isHardwareConnected ? () {
                                    Navigator.push(context, MaterialPageRoute(builder: (context) => ActiveChatScreen(
                                      chatName: "Global Mesh",
                                      onBack: () => Navigator.pop(context),
                                    )));
                                  } : () {},
                                ),
                                ChatTile(
                                  name: "Secure Squad",
                                  message: isHardwareConnected ? "AES-256 Encrypted (Channel 1)" : "Hardware disconnected...",
                                  time: "Live", 
                                  isUnread: true, 
                                  isConnected: isHardwareConnected, 
                                  onTap: isHardwareConnected ? () {
                                    Navigator.push(context, MaterialPageRoute(builder: (context) => ActiveChatScreen(
                                      chatName: "Secure Squad", 
                                      onBack: () => Navigator.pop(context),
                                    )));
                                  } : () {},
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    : _currentTabIndex == 1
                        ? const NodesScreen() 
                        : SettingsTab(isConnected: isHardwareConnected), 
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
                _buildBlinkingHardwareLogo(isHardwareConnected),
              ],
            ),
          ),
        );
      }
    );
  }
}

// ==========================================
// 🛡️ TACTICAL SQUAD PROVISIONING (OFFICIAL FLOW)
// ==========================================
class SquadSetupDialog extends StatefulWidget {
  const SquadSetupDialog({super.key});

  @override
  State<SquadSetupDialog> createState() => _SquadSetupDialogState();
}

class _SquadSetupDialogState extends State<SquadSetupDialog> {
  int _currentStep = 0; 
  
  final TextEditingController _nameController = TextEditingController(text: "SQUAD-1");
  late Channel _generatedChannel;
  String _qrDataString = "";
  bool _isChannelSaved = false;

  @override
  void initState() {
    super.initState();
    _generateNewSecureKey();
  }

  void _generateNewSecureKey() {
    final random = math.Random.secure();
    final aesKey = List<int>.generate(32, (i) => random.nextInt(256));
    
    _generatedChannel = Channel()
      ..index = 1
      ..role = Channel_Role.SECONDARY
      ..settings = (ChannelSettings()
        ..name = _nameController.text
        ..psk = aesKey);

    String base64Data = base64UrlEncode(_generatedChannel.writeToBuffer()).replaceAll('=', '');
    
    setState(() {
      _qrDataString = "https://meshtastic.org/e/#$base64Data";
    });
  }

  void _saveToRadio() {
    _generatedChannel.settings.name = _nameController.text;
    HardwareBridge.instance.provisionTacticalChannel(_generatedChannel);
    setState(() => _isChannelSaved = true);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("🟢 CHANNEL SAVED: Flashing hardware... Radio will reboot."), backgroundColor: Colors.green),
    );
  }

  void _processScannedQR(String qrCode) {
    if (qrCode.contains("meshtastic.org/e/#")) {
      try {
        String base64Data = qrCode.split("#").last;
        while (base64Data.length % 4 != 0) { base64Data += '='; }
        
        List<int> decodedBytes = base64Url.decode(base64Data);
        Channel scannedChannel = Channel.fromBuffer(decodedBytes);
        
        HardwareBridge.instance.provisionTacticalChannel(scannedChannel);
        
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("🟢 SECURE LINK JOINED: ${scannedChannel.settings.name}\nRadio is rebooting..."), 
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
          ),
        );
      } catch (e) {
        print("🔴 Invalid QR Format: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.bg,
      contentPadding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: AppColors.border)),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.85, // Use relative width instead of fixed
        child: SingleChildScrollView( // 👉 FIX: Prevents vertical pixel overflow
          child: Column(
            mainAxisSize: MainAxisSize.min, // 👉 FIX: Hug contents tightly
            children: [
              Container(
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    _buildTab(0, "CONFIG", LucideIcons.settings),
                    _buildTab(1, "SHARE", LucideIcons.qrCode),
                    _buildTab(2, "SCAN", LucideIcons.scan),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: _buildStepContent(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTab(int index, String title, IconData icon) {
    bool isActive = _currentStep == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _currentStep = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: isActive ? AppColors.primary : Colors.transparent, width: 3))),
          child: Column(
            children: [
              Icon(icon, color: isActive ? AppColors.primary : AppColors.textDim, size: 18),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(title, style: TextStyle(color: isActive ? AppColors.primary : AppColors.textDim, fontSize: 10, fontWeight: FontWeight.bold))
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepContent() {
    if (_currentStep == 0) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Channel Name", style: TextStyle(color: AppColors.textDim, fontSize: 12)),
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            decoration: const InputDecoration(filled: true, fillColor: AppColors.surface, border: OutlineInputBorder()),
            onChanged: (val) => _generateNewSecureKey(), 
          ),
          const SizedBox(height: 16),
          const Text("Encryption Key", style: TextStyle(color: AppColors.textDim, fontSize: 12)),
          const SizedBox(height: 8),
          Row(
            children: [
              const Expanded(
                child: Text("AES-256 (Maximum Security)", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
              ),
              IconButton(
                icon: const Icon(LucideIcons.refreshCw, color: AppColors.primary),
                onPressed: _generateNewSecureKey,
                tooltip: "Generate New Key",
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: _isChannelSaved ? AppColors.surface : AppColors.primary, padding: const EdgeInsets.symmetric(vertical: 14)),
              onPressed: _saveToRadio,
              icon: Icon(_isChannelSaved ? LucideIcons.checkCircle : LucideIcons.save, color: _isChannelSaved ? Colors.green : Colors.black),
              label: FittedBox( // 👉 FIX: Safely scale text on small devices
                fit: BoxFit.scaleDown,
                child: Text(_isChannelSaved ? "SAVED TO RADIO" : "SAVE TO RADIO", style: TextStyle(color: _isChannelSaved ? Colors.green : Colors.black, fontWeight: FontWeight.bold))
              ),
            ),
          ),
        ],
      );
    } else if (_currentStep == 1) {
      if (!_isChannelSaved) {
        return const Center(child: Text("⚠️ You must SAVE the channel in the CONFIG tab before sharing it.", textAlign: TextAlign.center, style: TextStyle(color: Colors.orange)));
      }
      return Column(
        children: [
          Text("Scan this with SentinLNK or the Official Meshtastic App to join '${_nameController.text}'.", textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textDim, fontSize: 12)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
            child: QrImageView(data: _qrDataString, version: QrVersions.auto, size: 200.0, backgroundColor: Colors.white),
          ),
        ],
      );
    } else {
      return Column(
        children: [
          const Text("Point camera at a Squad QR code. Hardware will auto-flash upon successful scan.", textAlign: TextAlign.center, style: TextStyle(color: AppColors.textDim, fontSize: 12)),
          const SizedBox(height: 16),
          SizedBox(
            height: 220,
            width: 220,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: MobileScanner(
                onDetect: (capture) {
                  for (final barcode in capture.barcodes) {
                    if (barcode.rawValue != null) {
                      _processScannedQR(barcode.rawValue!);
                      break; 
                    }
                  }
                },
              ),
            ),
          ),
        ],
      );
    }
  }
}