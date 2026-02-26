import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/storage/storage_service.dart';
import '../../../core/services/hardware_bridge.dart';

class ScanScreen extends StatefulWidget {
  final VoidCallback onConnect;
  final VoidCallback onBack;

  const ScanScreen({super.key, required this.onConnect, required this.onBack});

  @override
  _ScanScreenState createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final List<BluetoothDevice> _scannedDevices = [];
  Map<String, String> _savedNodes = {}; // Holds our saved devices
  final ScrollController _scrollController = ScrollController();
  
  bool _isScanning = false;
  String _statusMessage = "AWAITING SCAN COMMAND";
  final List<Map<String, String>> _scanLog = [];

  @override
  void initState() {
    super.initState();
    _loadSavedNodes();
  }

  // 👉 FEATURE 2: Load Saved Nodes from Memory
  Future<void> _loadSavedNodes() async {
    final nodes = await StorageService.getKnownDevices();
    setState(() {
      _savedNodes = nodes;
    });
    if (nodes.isNotEmpty) {
      _addScanLogEntry("MEMORY", "Loaded ${nodes.length} saved node(s).");
    }
  }

  // 👉 FEATURE 2: Unpair Node
  Future<void> _unpairNode(String remoteId) async {
    await StorageService.removeKnownDevice(remoteId);
    _addScanLogEntry("SYSTEM", "Node Unpaired and forgotten.");
    _loadSavedNodes(); // Refresh list
  }

  Future<void> _requestPermissionsAndScan() async {
    final bool bluetoothReady = await _ensureBluetoothReady();
    if (!bluetoothReady) return;

    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();

    if (statuses[Permission.bluetoothScan]!.isGranted && 
        statuses[Permission.bluetoothConnect]!.isGranted) {
      _startBleScan();
    } else {
      _addScanLogEntry("ERROR", "PERMISSION DENIED. CANNOT SCAN.");
    }
  }

  Future<bool> _ensureBluetoothReady() async {
    if (kIsWeb || !Platform.isAndroid) return true;
    final bool isSupported = await FlutterBluePlus.isSupported;
    if (!isSupported) return false;

    BluetoothAdapterState state = FlutterBluePlus.adapterStateNow;
    if (state == BluetoothAdapterState.unknown) {
      state = await FlutterBluePlus.adapterState.first;
    }
    if (state == BluetoothAdapterState.on) return true;

    try {
      await FlutterBluePlus.turnOn();
      return true;
    } catch (e) {
      return false;
    }
  }

  void _addScanLogEntry(String type, String message) {
    setState(() {
      _scanLog.add({
        'type': type, 'message': message, 'time': DateTime.now().toString().substring(11, 19),
      });
    });
    _scrollToBottom();
  }

  void _startBleScan() async {
    _addScanLogEntry("SYSTEM", "SWEEPING FREQUENCIES...");
    
    setState(() {
      _isScanning = true;
      _scannedDevices.clear();
      _statusMessage = "SWEEPING FREQUENCIES...";
    });

    var subscription = FlutterBluePlus.onScanResults.listen((results) {
      for (ScanResult r in results) {
        String deviceName = r.device.platformName.toLowerCase();
        String advName = r.advertisementData.advName.toLowerCase(); 
        
        if (deviceName.contains("meshtastic") || deviceName.contains("rak") || advName.contains("meshtastic") || advName.contains("rak")) {
          
          // Don't show it in the "New Devices" list if it's already in our "Saved Nodes" list
          if (!_savedNodes.containsKey(r.device.remoteId.str) && !_scannedDevices.any((d) => d.remoteId == r.device.remoteId)) {
            setState(() {
              _scannedDevices.add(r.device); 
            });
            String displayName = r.device.platformName.isNotEmpty ? r.device.platformName : advName;
            _addScanLogEntry("DETECTED", "Found new node: $displayName");
          }
        }
      }
    });

    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
    await Future.delayed(const Duration(seconds: 10));
    subscription.cancel();
    
    if (mounted) {
      setState(() {
        _isScanning = false;
        _statusMessage = "SCAN COMPLETE.";
      });
      _addScanLogEntry("SYSTEM", _statusMessage);
    }
  }

  Future<void> _connectToNode(BluetoothDevice device, String fallbackName) async {
    String dName = device.platformName.isNotEmpty ? device.platformName : fallbackName;
    _addScanLogEntry("CONNECTING", "Initiating handshake with $dName...");

    try {
      await device.connect(license: License.free, timeout: const Duration(seconds: 15));
      
      _addScanLogEntry("SUCCESS", "Secure link established!");
      
      // 👉 FEATURE 2: Trigger the Global Bridge to sync and save to memory!
      await HardwareBridge.instance.connectAndSync(device);
      
      Future.delayed(const Duration(milliseconds: 500), () {
        widget.onConnect();
      });
    } catch (e) {
      _addScanLogEntry("ERROR", "Connection failed.");
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut,
        );
      }
    });
  }

  Widget _buildDeviceCard(String name, String id, {BluetoothDevice? deviceToConnect, bool isSaved = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isSaved ? Colors.blueAccent.withValues(alpha: 0.5) : AppColors.border),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.bluetooth, color: isSaved ? Colors.blueAccent : Colors.greenAccent, size: 16),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                Text(id, style: const TextStyle(color: Colors.grey, fontSize: 10)),
              ],
            ),
          ),
          if (isSaved)
            IconButton(
              icon: const Icon(LucideIcons.trash2, color: Colors.redAccent, size: 18),
              onPressed: () => _unpairNode(id),
              tooltip: "Unpair Node",
            ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isSaved ? Colors.blue[800] : Colors.green[800],
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            onPressed: () {
              // If it's a saved device, we generate a BluetoothDevice object from the ID
              BluetoothDevice target = deviceToConnect ?? BluetoothDevice.fromId(id);
              _connectToNode(target, name);
            },
            child: Text("LINK", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
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
        leading: IconButton(icon: const Icon(LucideIcons.chevronLeft, color: Colors.white), onPressed: widget.onBack),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("NODE SCANNER", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 2.0, color: Colors.white)),
            Text("MESH NETWORK DISCOVERY", style: TextStyle(color: AppColors.accent, fontSize: 10)),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _scanLog.length,
              itemBuilder: (context, index) {
                final log = _scanLog[index];
                bool isError = log['type'] == 'ERROR';
                bool isSuccess = log['type'] == 'SUCCESS';
                bool isMemory = log['type'] == 'MEMORY';

                return Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    constraints: const BoxConstraints(maxWidth: 300),
                    decoration: BoxDecoration(
                      color: isError ? Colors.red[900] : isSuccess ? Colors.green[900] : isMemory ? Colors.blue[900] : AppColors.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isError ? Colors.red[700]! : isSuccess ? Colors.green[700]! : isMemory ? Colors.blue[700]! : AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(log['type']!, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isError ? Colors.red[300] : isSuccess ? Colors.green[300] : isMemory ? Colors.blue[300] : AppColors.accent, letterSpacing: 1)),
                        const SizedBox(height: 4),
                        Text(log['message']!, style: const TextStyle(fontSize: 13, color: Colors.white)),
                        const SizedBox(height: 4),
                        Text(log['time']!, style: const TextStyle(fontSize: 9, color: Colors.white38)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          if (_savedNodes.isNotEmpty || _scannedDevices.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(color: AppColors.surface, border: Border(top: BorderSide(color: AppColors.border))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 👉 SAVED NODES SECTION
                  if (_savedNodes.isNotEmpty) ...[
                    const Text("SAVED NODES", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1, color: Colors.blueAccent)),
                    const SizedBox(height: 12),
                    ..._savedNodes.entries.map((entry) => _buildDeviceCard(entry.value, entry.key, isSaved: true)),
                    const SizedBox(height: 12),
                  ],

                  // 👉 NEW SCANNED NODES SECTION
                  if (_scannedDevices.isNotEmpty) ...[
                    const Text("NEW DEVICES IN RANGE", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1, color: AppColors.accent)),
                    const SizedBox(height: 12),
                    ..._scannedDevices.map((device) => _buildDeviceCard(device.platformName.isNotEmpty ? device.platformName : "Unknown Node", device.remoteId.str, deviceToConnect: device)),
                  ],
                ],
              ),
            ),

          Container(
            padding: const EdgeInsets.all(16),
            color: AppColors.surface,
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isScanning ? Colors.grey[800] : Colors.orange[800],
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: _isScanning ? null : _requestPermissionsAndScan,
                child: Text(_isScanning ? "SCANNING..." : "INITIATE SCAN", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}