import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../../../core/theme/app_colors.dart';

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
                      Text("Security", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      SizedBox(height: 4),
                      Text("Encryption, Bluetooth PIN, Remote Admin", style: TextStyle(color: AppColors.textDim, fontSize: 12)),
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
        if (uuid.contains("8ba2bcc2")) fromRadioChar = c; 
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
    bool hasChanges = _selectedRegion != _hwRegion || _usePreset != _hwUsePreset || _selectedPreset != _hwPreset || _txPower != _hwTxPower || _hopLimit != _hwHopLimit;

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
// 3. THE NEW SECURITY CONFIGURATION SCREEN
// ==========================================
class SecurityConfigScreen extends StatefulWidget {
  const SecurityConfigScreen({super.key});

  @override
  State<SecurityConfigScreen> createState() => _SecurityConfigScreenState();
}

class _SecurityConfigScreenState extends State<SecurityConfigScreen> {
  // Temporary State Values (Simulated read from radio)
  String _btPairingMode = "Secure PIN";
  bool _allowRemoteAdmin = false;

  void _showWarningDialog(String title, String desc, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(title, style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
        content: Text(desc, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL", style: TextStyle(color: AppColors.textDim))),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onConfirm();
            },
            child: const Text("PROCEED", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
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
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          
          // --- BLUETOOTH SECURITY ---
          const Text("BLUETOOTH ACCESS", style: TextStyle(color: AppColors.textDim, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.surface, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _btPairingMode, isExpanded: true, dropdownColor: AppColors.surface,
                icon: const Icon(LucideIcons.chevronDown, color: AppColors.textDim),
                style: const TextStyle(color: Colors.white, fontSize: 14),
                items: ["Secure PIN", "Fixed PIN", "No PIN (Insecure)"].map((String item) { 
                  return DropdownMenuItem<String>(value: item, child: Text(item)); 
                }).toList(),
                onChanged: (val) => setState(() => _btPairingMode = val!),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text("Prevents unauthorized phones from linking to your physical node.", style: TextStyle(color: Colors.white38, fontSize: 11)),
          
          const SizedBox(height: 32),

          // --- NETWORK ENCRYPTION ---
          const Text("MESH ENCRYPTION (AES-256)", style: TextStyle(color: AppColors.textDim, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                const Row(
                  children: [
                    Icon(LucideIcons.key, color: AppColors.primary, size: 20),
                    SizedBox(width: 12),
                    Expanded(child: Text("Primary Channel Key", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold))),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(6)),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // 👉 FIX: Wrapped in Expanded to stop the 3.6 pixel overflow!
                      Expanded(
                        child: Text(
                          "••••••••••••••••••••••••", 
                          style: TextStyle(color: AppColors.textDim, letterSpacing: 2),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(LucideIcons.eye, color: AppColors.textDim, size: 16),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      _showWarningDialog("Regenerate Key?", "This will break communication with your current mesh. Other nodes will need to scan your new QR code to reconnect.", () {});
                    },
                    icon: const Icon(LucideIcons.refreshCw, color: Colors.orangeAccent, size: 16),
                    label: const Text("REGENERATE KEY", style: TextStyle(color: Colors.orangeAccent)),
                    style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.orangeAccent)),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // --- REMOTE ADMIN ---
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Remote Administration", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                      SizedBox(height: 4),
                      Text("Allow changing settings over the radio mesh via admin channel.", style: TextStyle(color: AppColors.textDim, fontSize: 11)),
                    ],
                  ),
                ),
                Switch(value: _allowRemoteAdmin, activeThumbColor: AppColors.primary, inactiveTrackColor: AppColors.bg, onChanged: (val) => setState(() => _allowRemoteAdmin = val)),
              ],
            ),
          ),

          const SizedBox(height: 48),

          // --- DANGER ZONE ---
          const Text("DANGER ZONE", style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.redAccent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                const Text("Wiping the node will erase all network databases, reset encryption keys, and reboot the hardware. This action is irreversible.", 
                  style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4)),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 45,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      _showWarningDialog("FACTORY RESET", "Are you absolutely sure? This will wipe the hardware completely.", () {});
                    },
                    icon: const Icon(LucideIcons.skull, color: Colors.white, size: 18),
                    label: const Text("FACTORY RESET NODE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1)),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  ),
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}