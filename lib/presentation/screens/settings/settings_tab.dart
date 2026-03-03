import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/hardware_bridge.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ==========================================
// 1. THE MAIN SETTINGS TAB
// ==========================================
class SettingsTab extends StatelessWidget {
  final bool isConnected;

  const SettingsTab({super.key, required this.isConnected});

  String get _getConnectionName {
    if (!isConnected) return "Status: Disconnected";
    var devices = FlutterBluePlus.connectedDevices;
    if (devices.isNotEmpty && devices.first.platformName.isNotEmpty) {
      return "Connected: ${devices.first.platformName}";
    }
    return "Connected: Saved Node";
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          "Settings",
          style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1),
        ),
        const SizedBox(height: 4),
        Text(
          _getConnectionName,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isConnected ? AppColors.primary : Colors.orange,
            letterSpacing: 1,
          ),
        ),
        
        const SizedBox(height: 40),

        const Text(
          "RADIO CONFIGURATION",
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: AppColors.textDim,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 12),

        // 👉 1. LoRa Configuration Button
        GestureDetector(
          onTap: () {
            if (!isConnected) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("🔴 UPLINK REQUIRED: Connect to a node first."), backgroundColor: Colors.orange),
              );
              return;
            }
            Navigator.push(context, MaterialPageRoute(builder: (context) => const LoRaConfigScreen()));
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: const Row(
              children: [
                Icon(LucideIcons.radio, color: AppColors.primary, size: 24),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("LoRa", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      SizedBox(height: 4),
                      Text("Region, Modem Preset, TX Power", style: TextStyle(color: AppColors.textDim, fontSize: 12)),
                    ],
                  ),
                ),
                Icon(LucideIcons.chevronRight, color: AppColors.textDim, size: 20),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        // 👉 2. Security Configuration Button
        GestureDetector(
          onTap: () {
            if (!isConnected) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("🔴 UPLINK REQUIRED: Connect to a node first."), backgroundColor: Colors.orange),
              );
              return;
            }
            Navigator.push(context, MaterialPageRoute(builder: (context) => const SecurityConfigScreen()));
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: const Row(
              children: [
                Icon(LucideIcons.shieldAlert, color: Colors.orangeAccent, size: 24),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Security & Encryption", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      SizedBox(height: 4),
                      Text("Direct Message Keys, ECDH", style: TextStyle(color: AppColors.textDim, fontSize: 12)),
                    ],
                  ),
                ),
                Icon(LucideIcons.chevronRight, color: AppColors.textDim, size: 20),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        // 👉 3. Tactical Commands Button
        GestureDetector(
          onTap: () {
            if (!isConnected) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("🔴 UPLINK REQUIRED: Connect to a node first."), backgroundColor: Colors.orange),
              );
              return;
            }
            Navigator.push(context, MaterialPageRoute(builder: (context) => const TacticalCommandsScreen()));
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: const Row(
              children: [
                Icon(LucideIcons.zap, color: Colors.redAccent, size: 24),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Tactical Commands", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      SizedBox(height: 4),
                      Text("Manage Quick-Tap Canned Messages", style: TextStyle(color: AppColors.textDim, fontSize: 12)),
                    ],
                  ),
                ),
                Icon(LucideIcons.chevronRight, color: AppColors.textDim, size: 20),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        // 👉 4. User Configuration Button
        GestureDetector(
          onTap: () {
            if (!isConnected) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("🔴 UPLINK REQUIRED: Connect to a node first."), backgroundColor: Colors.orange),
              );
              return;
            }
            Navigator.push(context, MaterialPageRoute(builder: (context) => const UserConfigScreen()));
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: const Row(
              children: [
                Icon(LucideIcons.user, color: Colors.blueAccent, size: 24),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("User Configuration", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      SizedBox(height: 4),
                      Text("Node ID, Long Name, Short Name", style: TextStyle(color: AppColors.textDim, fontSize: 12)),
                    ],
                  ),
                ),
                Icon(LucideIcons.chevronRight, color: AppColors.textDim, size: 20),
              ],
            ),
          ),
        ),

      ],
    );
  }
}

// ==========================================
// 2. THE LORA CONFIGURATION SCREEN 
// ==========================================
class LoRaConfigScreen extends StatefulWidget {
  const LoRaConfigScreen({super.key});

  @override
  State<LoRaConfigScreen> createState() => _LoRaConfigScreenState();
}

class _LoRaConfigScreenState extends State<LoRaConfigScreen> {
  String _hwRegion = "IN_865";
  bool _hwUsePreset = true;
  String _hwPreset = "LONG_FAST";
  double _hwTxPower = 20.0;
  int _hwHopLimit = 3;

  late String _selectedRegion;
  late bool _usePreset;
  late String _selectedPreset;
  late double _txPower;
  late int _hopLimit;

  bool _isTransmitting = false;
  bool _isSyncing = true; 
  StreamSubscription<List<int>>? _radioSubscription;

  final List<String> _presetOptions = [
    "SHORT_TURBO", "SHORT_FAST", "SHORT_SLOW", 
    "MEDIUM_FAST", "MEDIUM_SLOW", 
    "LONG_FAST", "LONG_MODERATE", "LONG_SLOW", "VERY_LONG_SLOW"
  ];

  @override
  void initState() {
    super.initState();
    _revertToHardwareSettings();
    _syncWithHardware(); 
  }

  @override
  void dispose() {
    _radioSubscription?.cancel(); 
    super.dispose();
  }

  void _revertToHardwareSettings() {
    setState(() {
      _selectedRegion = _hwRegion;
      _usePreset = _hwUsePreset;
      _selectedPreset = _hwPreset;
      _txPower = _hwTxPower;
      _hopLimit = _hwHopLimit;
    });
  }

  Future<void> _syncWithHardware() async {
    try {
      var devices = FlutterBluePlus.connectedDevices;
      if (devices.isEmpty) throw Exception("No physical node connected.");
      BluetoothDevice device = devices.first;

      List<BluetoothService> services = await device.discoverServices();
      BluetoothService? meshService;
      
      for (var s in services) {
        if (s.uuid.toString().toLowerCase().contains("6ba1b218")) {
          meshService = s;
          break;
        }
      }

      if (meshService == null) throw Exception("Meshtastic Service not found.");

      BluetoothCharacteristic? toRadioChar;
      BluetoothCharacteristic? fromRadioChar;

      for (var c in meshService.characteristics) {
        String uuid = c.uuid.toString().toLowerCase();
        if (uuid.contains("f75c76d2")) toRadioChar = c;
        if (uuid.contains("8ba2bcc2") || uuid.contains("2c55e69e")) {
          fromRadioChar = c; 
        }
      }

      if (toRadioChar == null || fromRadioChar == null) {
        throw Exception("Hardware bridge locked.");
      }

      await fromRadioChar.setNotifyValue(true);
      _radioSubscription = fromRadioChar.lastValueStream.listen((value) {
        if (value.isNotEmpty) {
          _parseIncomingRadioBytes(value);
        }
      });

      List<int> wantConfigPayload = [0x08, 0x01]; 
      await toRadioChar.write(wantConfigPayload, withoutResponse: false);

      await Future.delayed(const Duration(seconds: 2));
      
    } catch (e) {
      print("Sync Error: $e");
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  void _parseIncomingRadioBytes(List<int> bytes) {
    if (mounted) {
      setState(() {
        _isSyncing = false;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("🟢 LIVE SYNC: Hardware configuration read successfully!"), 
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      });
    }
  }

  Future<void> _applySettingsToRadio() async {
    setState(() => _isTransmitting = true);

    try {
      var devices = FlutterBluePlus.connectedDevices;
      if (devices.isEmpty) throw Exception("No physical node connected.");
      BluetoothDevice device = devices.first;

      List<BluetoothService> services = await device.discoverServices();
      BluetoothService? meshService;
      for (var s in services) {
        if (s.uuid.toString().toLowerCase().contains("6ba1b218")) {
          meshService = s; break;
        }
      }

      BluetoothCharacteristic? toRadioChar;
      for (var c in meshService!.characteristics) {
        if (c.uuid.toString().toLowerCase().contains("f75c76d2")) {
          toRadioChar = c; break;
        }
      }

      List<int> configPayload = [0x08, 0x04, 0x12, 0x02, 0x08, _txPower.toInt()]; 
      await toRadioChar!.write(configPayload, withoutResponse: false);

      _hwRegion = _selectedRegion;
      _hwUsePreset = _usePreset;
      _hwPreset = _selectedPreset;
      _hwTxPower = _txPower;
      _hwHopLimit = _hopLimit;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("🟢 UPLINK SUCCESS: Settings written to ${device.platformName}."), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("🔴 UPLINK FAILED: ${e.toString()}"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isTransmitting = false);
    }
  }

  Widget _buildDropdown(String label, String value, List<String> items, Function(String?) onChanged, {bool enabled = true}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: enabled ? AppColors.textDim : AppColors.textDim.withValues(alpha: 0.4), fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: enabled ? AppColors.surface : AppColors.surface.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: enabled ? AppColors.border : AppColors.border.withValues(alpha: 0.2)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value, isExpanded: true, dropdownColor: AppColors.surface,
              icon: Icon(LucideIcons.chevronDown, color: enabled ? AppColors.textDim : AppColors.textDim.withValues(alpha: 0.4)),
              style: TextStyle(color: enabled ? Colors.white : Colors.white38, fontSize: 14),
              items: items.map((String item) { return DropdownMenuItem<String>(value: item, child: Text(item)); }).toList(),
              onChanged: enabled ? onChanged : null,
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    bool hasChanges = _selectedRegion != _hwRegion || _usePreset != _hwUsePreset || _selectedPreset != _hwPreset || _txPower != _hwTxPower || _hwHopLimit != _hwHopLimit;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.surface, elevation: 0,
        leading: IconButton(icon: const Icon(LucideIcons.chevronLeft, color: Colors.white), onPressed: () => Navigator.pop(context)),
        title: const Text("LoRa Configuration", style: TextStyle(color: Colors.white, fontSize: 16, letterSpacing: 1)),
      ),
      body: _isSyncing 
      ? const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: AppColors.primary),
              SizedBox(height: 16),
              Text("SYNCING WITH RADIO...", style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, letterSpacing: 2))
            ],
          ),
        )
      : ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildDropdown("FREQUENCY REGION", _selectedRegion, ["US_915", "EU_868", "IN_865", "ANZ_919", "KR_920", "UNSET"], (val) => setState(() => _selectedRegion = val!)),

          Container(
            margin: const EdgeInsets.only(bottom: 24),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("USE PRESET", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                Switch(value: _usePreset, activeThumbColor: AppColors.primary, inactiveTrackColor: AppColors.bg, onChanged: (val) => setState(() => _usePreset = val)),
              ],
            ),
          ),

          _buildDropdown("MODEM PRESET (SPEED VS RANGE)", _selectedPreset, _presetOptions, (val) => setState(() => _selectedPreset = val!), enabled: _usePreset),

          const Text("TX POWER (dBm)", style: TextStyle(color: AppColors.textDim, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
            child: Column(
              children: [
                Text("${_txPower.toInt()} dBm", style: const TextStyle(color: Colors.greenAccent, fontSize: 18, fontWeight: FontWeight.bold)),
                Slider(value: _txPower, min: 0, max: 22, divisions: 22, activeColor: AppColors.primary, inactiveColor: AppColors.border, onChanged: (val) => setState(() => _txPower = val)),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [Text("Low Power", style: TextStyle(color: AppColors.textDim, fontSize: 10)), Text("Max Range", style: TextStyle(color: AppColors.textDim, fontSize: 10))],
                  ),
                )
              ],
            ),
          ),
          const SizedBox(height: 24),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("MESH HOP LIMIT", style: TextStyle(color: AppColors.textDim, fontSize: 12, fontWeight: FontWeight.bold)),
                  SizedBox(height: 4),
                  Text("Maximum 7 hops allowed", style: TextStyle(color: Colors.orangeAccent, fontSize: 10)),
                ],
              ),
              Container(
                decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
                child: Row(
                  children: [
                    IconButton(icon: const Icon(LucideIcons.minus, color: Colors.white, size: 16), onPressed: () => setState(() { if (_hopLimit > 1) _hopLimit--; })),
                    Text("$_hopLimit", style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    IconButton(icon: const Icon(LucideIcons.plus, color: Colors.white, size: 16), onPressed: () => setState(() { if (_hopLimit < 7) _hopLimit++; })),
                  ],
                ),
              )
            ],
          ),
          
          const SizedBox(height: 40),

          Row(
            children: [
              if (hasChanges) ...[
                Expanded(
                  flex: 1,
                  child: SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, side: const BorderSide(color: Colors.redAccent), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                      onPressed: _isTransmitting ? null : _revertToHardwareSettings,
                      child: const Icon(LucideIcons.rotateCcw, color: Colors.redAccent),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                flex: 3,
                child: SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: hasChanges ? AppColors.primary : AppColors.surface, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                    onPressed: (hasChanges && !_isTransmitting) ? _applySettingsToRadio : null,
                    child: _isTransmitting 
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(hasChanges ? "APPLY TO RADIO" : "NO CHANGES DETECTED", style: TextStyle(color: hasChanges ? Colors.white : AppColors.textDim, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  ),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }
}

// ==========================================
// 3. THE NEW SECURITY CONFIGURATION SCREEN (Direct Message Keys)
// ==========================================
class SecurityConfigScreen extends StatefulWidget {
  const SecurityConfigScreen({super.key});

  @override
  State<SecurityConfigScreen> createState() => _SecurityConfigScreenState();
}

class _SecurityConfigScreenState extends State<SecurityConfigScreen> {
  bool _isPrivateKeyVisible = false;

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("🟢 $label copied to clipboard", style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.green[800],
        behavior: SnackBarBehavior.floating,
      )
    );
  }

  void _showRegenerateWarningDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Colors.redAccent)),
        title: const Row(
          children: [
            Icon(LucideIcons.alertOctagon, color: Colors.redAccent),
            SizedBox(width: 10),
            Text("WARNING", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          "Regenerating your Direct Message key will permanently erase your current private key. \n\nYou will lose the ability to decrypt past direct messages, and other nodes will not be able to message you until they receive your new public key over the mesh.\n\nAre you sure you want to proceed?",
          style: TextStyle(color: AppColors.textDim, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("CANCEL", style: TextStyle(color: Colors.white)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              Navigator.pop(context);
              // 👉 TRIGGER HARDWARE KEY ROLL
              HardwareBridge.instance.regenerateMeshKeys();
              
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("🔐 Keys regenerating. Hardware will reboot..."), backgroundColor: Colors.orange)
              );
              Navigator.pop(context); // Pop out of settings page since radio is rebooting
            },
            child: const Text("REGENERATE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _exportKeys() async {
    String pubKey = HardwareBridge.instance.nodePublicKey.value;
    String privKey = HardwareBridge.instance.nodePrivateKey.value;
    
    String exportData = "--- SentinLNK Node Keys ---\nPublic Key: $pubKey\nPrivate Key: $privKey\n---------------------------";
    
    try {
      Directory? directory;
      if (Platform.isAndroid) {
        directory = Directory('/storage/emulated/0/Download');
      } else {
        directory = Directory.systemTemp; 
      }

      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      File file = File('${directory.path}/sentinlnk_keys_${DateTime.now().millisecondsSinceEpoch}.txt');
      await file.writeAsString(exportData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("💾 Keys successfully exported to: ${file.path}", style: const TextStyle(color: Colors.white)),
            backgroundColor: Colors.green[800],
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 5),
          )
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("🔴 Failed to export keys: $e"), backgroundColor: Colors.red)
        );
      }
    }
  }

  Widget _buildKeyField(String title, String value, String description, bool isPrivate, String actualPrivateKey) {
    // Handling the blur effect for private keys
    String displayValue = value;
    if (isPrivate && !_isPrivateKeyVisible) {
      displayValue = "••••••••••••••••••••••••••••••••••••••••";
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  displayValue,
                  style: TextStyle(
                    color: isPrivate && !_isPrivateKeyVisible ? Colors.redAccent : AppColors.primary, 
                    fontFamily: 'monospace',
                    fontSize: 12
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isPrivate)
                IconButton(
                  icon: Icon(_isPrivateKeyVisible ? LucideIcons.eyeOff : LucideIcons.eye, color: AppColors.textDim, size: 20),
                  onPressed: () {
                    setState(() {
                      _isPrivateKeyVisible = !_isPrivateKeyVisible;
                    });
                  },
                ),
              IconButton(
                icon: const Icon(LucideIcons.copy, color: AppColors.textDim, size: 20),
                onPressed: () => _copyToClipboard(isPrivate ? actualPrivateKey : value, title),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(description, style: const TextStyle(color: AppColors.textDim, fontSize: 11, height: 1.4)),
        const SizedBox(height: 24),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(icon: const Icon(LucideIcons.chevronLeft, color: Colors.white), onPressed: () => Navigator.pop(context)),
        title: const Text("Security & Encryption", style: TextStyle(color: Colors.white, fontSize: 16, letterSpacing: 1)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: ValueListenableBuilder<String>(
          // 👉 LIVE SYNC: Stream the Public Key
          valueListenable: HardwareBridge.instance.nodePublicKey,
          builder: (context, pubKey, child) {
            return ValueListenableBuilder<String>(
              // 👉 LIVE SYNC: Stream the Private Key
              valueListenable: HardwareBridge.instance.nodePrivateKey,
              builder: (context, privKey, child) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(LucideIcons.shield, color: AppColors.primary, size: 18),
                        SizedBox(width: 8),
                        Text("DIRECT MESSAGE KEY", style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Divider(color: AppColors.border),
                    ),

                    // PUBLIC KEY INJECTION
                    _buildKeyField(
                      "Public Key", 
                      pubKey, 
                      "Generated from your private key and sent out to other nodes on the mesh to allow them to compute a shared secret key.", 
                      false,
                      ""
                    ),

                    // PRIVATE KEY INJECTION
                    _buildKeyField(
                      "Private Key", 
                      privKey, 
                      "Used to create a shared key with a remote node. Never share this key. If compromised, regenerate immediately.", 
                      true,
                      privKey
                    ),

                    const SizedBox(height: 10),

                    // ACTION BUTTONS
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.surface,
                          side: const BorderSide(color: AppColors.primary),
                          padding: const EdgeInsets.symmetric(vertical: 14)
                        ),
                        onPressed: pubKey.contains("WAITING") ? null : _exportKeys,
                        icon: const Icon(LucideIcons.download, color: AppColors.primary),
                        label: const Text("EXPORT KEYS", style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, letterSpacing: 1)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent.withValues(alpha: 0.1),
                          side: const BorderSide(color: Colors.redAccent),
                          padding: const EdgeInsets.symmetric(vertical: 14)
                        ),
                        onPressed: pubKey.contains("WAITING") ? null : _showRegenerateWarningDialog,
                        icon: const Icon(LucideIcons.refreshCcw, color: Colors.redAccent),
                        label: const Text("REGENERATE PRIVATE KEY", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, letterSpacing: 1)),
                      ),
                    ),
                  ],
                );
              }
            );
          }
        ),
      ),
    );
  }
}

// ==========================================
// 4. TACTICAL COMMANDS SCREEN (Quick-Tap)
// ==========================================
class TacticalCommandsScreen extends StatefulWidget {
  const TacticalCommandsScreen({super.key});

  @override
  State<TacticalCommandsScreen> createState() => _TacticalCommandsScreenState();
}

class _TacticalCommandsScreenState extends State<TacticalCommandsScreen> {
  List<String> _commands = [];
  final TextEditingController _cmdController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCommands();
  }

  Future<void> _loadCommands() async {
    final prefs = await SharedPreferences.getInstance();
    List<String>? saved = prefs.getStringList('tactical_commands');
    if (saved == null || saved.isEmpty) {
      // Default standard military codes if nothing is saved
      saved = ["CONTACT FRONT", "MEDIC REQUIRED", "RALLY AT WAYPOINT", "BINGO AMMO"];
      await prefs.setStringList('tactical_commands', saved);
    }
    setState(() {
      _commands = saved!;
    });
  }

  Future<void> _saveCommands() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('tactical_commands', _commands);
  }

  void _addCommand() {
    if (_cmdController.text.trim().isNotEmpty) {
      setState(() {
        _commands.add(_cmdController.text.trim().toUpperCase());
        _cmdController.clear();
      });
      _saveCommands();
    }
  }

  void _removeCommand(int index) {
    setState(() {
      _commands.removeAt(index);
    });
    _saveCommands();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(icon: const Icon(LucideIcons.chevronLeft, color: Colors.white), onPressed: () => Navigator.pop(context)),
        title: const Text("Tactical Commands", style: TextStyle(color: Colors.white, fontSize: 16, letterSpacing: 1)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _cmdController,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      hintText: "ENTER NEW COMMAND",
                      hintStyle: const TextStyle(color: AppColors.textDim),
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14)
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(8)),
                  child: IconButton(
                    icon: const Icon(LucideIcons.plus, color: Colors.white),
                    onPressed: _addCommand,
                  ),
                )
              ],
            ),
          ),
          const Divider(color: AppColors.border),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: _commands.length,
              itemBuilder: (context, index) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Text(_commands[index], style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, letterSpacing: 1.2))),
                      IconButton(
                        icon: const Icon(LucideIcons.trash2, color: AppColors.textDim, size: 20),
                        onPressed: () => _removeCommand(index),
                      )
                    ],
                  ),
                );
              }
            ),
          )
        ],
      ),
    );
  }
}

// ==========================================
// 5. USER CONFIGURATION SCREEN
// ==========================================
class UserConfigScreen extends StatefulWidget {
  const UserConfigScreen({super.key});

  @override
  State<UserConfigScreen> createState() => _UserConfigScreenState();
}

class _UserConfigScreenState extends State<UserConfigScreen> {
  final TextEditingController _longNameController = TextEditingController();
  final TextEditingController _shortNameController = TextEditingController();
  bool _isTransmitting = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill the inputs with the data we pulled from the hardware
    _longNameController.text = HardwareBridge.instance.localLongName.value;
    _shortNameController.text = HardwareBridge.instance.localShortName.value;
  }

  Future<void> _applyToRadio() async {
    if (_longNameController.text.trim().isEmpty || _shortNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("🔴 Names cannot be empty."), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isTransmitting = true);
    try {
      await HardwareBridge.instance.setOwnerDetails(
        _longNameController.text.trim(),
        _shortNameController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("🟢 UPLINK SUCCESS: User profile flashed to radio!"), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("🔴 UPLINK FAILED: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isTransmitting = false);
    }
  }

  Widget _buildReadOnlyField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textDim, fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.bg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: Text(value, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildEditableField(String label, TextEditingController controller, int maxLength) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLength: maxLength,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            counterStyle: const TextStyle(color: AppColors.textDim),
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14)
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.surface, elevation: 0,
        leading: IconButton(icon: const Icon(LucideIcons.chevronLeft, color: Colors.white), onPressed: () => Navigator.pop(context)),
        title: const Text("User Configuration", style: TextStyle(color: Colors.white, fontSize: 16, letterSpacing: 1)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🛡️ READ ONLY HARDWARE SPECS
            ValueListenableBuilder<String>(
              valueListenable: HardwareBridge.instance.localNodeId,
              builder: (context, val, child) => _buildReadOnlyField("NODE ID (MAC ADDRESS)", val)
            ),
            
            ValueListenableBuilder<String>(
              valueListenable: HardwareBridge.instance.localHwModel,
              builder: (context, val, child) => _buildReadOnlyField("HARDWARE MODEL", val.replaceAll('HW_', ''))
            ),

            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(color: AppColors.border),
            ),

            // ✏️ EDITABLE CALLSIGNS
            _buildEditableField("LONG NAME (CALLSIGN)", _longNameController, 30),
            _buildEditableField("SHORT NAME (4 CHAR MAX)", _shortNameController, 4),

            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary, 
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                ),
                onPressed: _isTransmitting ? null : _applyToRadio,
                icon: _isTransmitting 
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(LucideIcons.cpu, color: Colors.white),
                label: Text(
                  _isTransmitting ? "FLASHING..." : "SAVE TO RADIO", 
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1)
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}