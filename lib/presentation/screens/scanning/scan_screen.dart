import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_colors.dart';

class ScanScreen extends StatefulWidget {
  final VoidCallback onConnect;
  final VoidCallback onBack;

  // 1. TACTICAL MEMORY: Remembers the last connected node
  static BluetoothDevice? lastKnownNode;

  const ScanScreen({super.key, required this.onConnect, required this.onBack});

  @override
  _ScanScreenState createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  // Changed from ScanResult to BluetoothDevice to support injecting memory
  final List<BluetoothDevice> _meshtasticDevices = [];
  final ScrollController _scrollController = ScrollController();
  bool _isScanning = false;
  String _statusMessage = "AWAITING SCAN COMMAND";
  final List<Map<String, String>> _scanLog = [];

  // 1. Request Permissions
  Future<void> _requestPermissionsAndScan() async {
    final bool bluetoothReady = await _ensureBluetoothReady();
    if (!bluetoothReady) {
      return;
    }

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
      setState(() {
        _statusMessage = "PERMISSION DENIED. CANNOT SCAN.";
      });
    }
  }

  Future<bool> _ensureBluetoothReady() async {
    if (kIsWeb || !Platform.isAndroid) {
      return true;
    }

    final bool isSupported = await FlutterBluePlus.isSupported;
    if (!isSupported) {
      _addScanLogEntry("ERROR", "BLUETOOTH NOT SUPPORTED ON THIS DEVICE.");
      setState(() {
        _statusMessage = "BLUETOOTH NOT SUPPORTED.";
      });
      return false;
    }

    BluetoothAdapterState state = FlutterBluePlus.adapterStateNow;
    if (state == BluetoothAdapterState.unknown) {
      state = await FlutterBluePlus.adapterState.first;
    }

    if (state == BluetoothAdapterState.on) {
      return true;
    }

    _addScanLogEntry("ERROR", "BLUETOOTH IS OFF. ENABLE TO SCAN.");
    setState(() {
      _statusMessage = "BLUETOOTH IS OFF. ENABLE TO SCAN.";
    });

    if (!mounted) {
      return false;
    }

    final bool? shouldTurnOn = await _showBluetoothOffDialog();
    if (shouldTurnOn != true) {
      return false;
    }

    try {
      await FlutterBluePlus.turnOn();
      return true;
    } catch (e) {
      _addScanLogEntry("ERROR", "BLUETOOTH ENABLE FAILED.");
      if (!mounted) {
        return false;
      }
      setState(() {
        _statusMessage = "BLUETOOTH ENABLE FAILED.";
      });
      return false;
    }
  }

  Future<bool?> _showBluetoothOffDialog() {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text(
            "BLUETOOTH OFF",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: const Text(
            "TURN ON BLUETOOTH TO START SCANNING.",
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text(
                "CANCEL",
                style: TextStyle(color: Colors.white70),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange[800],
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text(
                "TURN ON",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  void _addScanLogEntry(String type, String message) {
    setState(() {
      _scanLog.add({
        'type': type,
        'message': message,
        'time': DateTime.now().toString().substring(11, 19),
      });
    });
    _scrollToBottom();
  }

  // 2. Start the Bluetooth Scan
  void _startBleScan() async {
    _addScanLogEntry("SYSTEM", "SWEEPING FREQUENCIES...");
    
    setState(() {
      _isScanning = true;
      _meshtasticDevices.clear();
      _statusMessage = "SWEEPING FREQUENCIES...";

      // 2. TACTICAL MEMORY INJECTION
      if (ScanScreen.lastKnownNode != null) {
        _meshtasticDevices.add(ScanScreen.lastKnownNode!);
        String name = ScanScreen.lastKnownNode!.platformName;
        _addScanLogEntry("MEMORY", "Loaded saved node: ${name.isNotEmpty ? name : 'Ghost Node'}");
      }
    });

    // Listen to scan results
    var subscription = FlutterBluePlus.onScanResults.listen((results) {
      for (ScanResult r in results) {
        String deviceName = r.device.platformName.toLowerCase();
        // 3. CHECK FOR GHOST PINGS (Blank names saved in advert data)
        String advName = r.advertisementData.advName.toLowerCase(); 
        
        if (deviceName.contains("meshtastic") || deviceName.contains("rak") ||
            advName.contains("meshtastic") || advName.contains("rak")) {
          // Prevent duplicates
          if (!_meshtasticDevices.any((d) => d.remoteId == r.device.remoteId)) {
            setState(() {
              _meshtasticDevices.add(r.device); // Add just the device
            });
            String displayName = r.device.platformName.isNotEmpty ? r.device.platformName : advName;
            _addScanLogEntry("DETECTED", "Found node: $displayName");
          }
        }
      }
    });

    // Scan for 10 seconds
    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
    
    // Cleanup after scan
    await Future.delayed(const Duration(seconds: 10));
    subscription.cancel();
    
    if (!mounted) return;
    setState(() {
      _isScanning = false;
      _statusMessage = _meshtasticDevices.isEmpty 
          ? "NO NODES DETECTED" 
          : "NODES FOUND. READY TO LINK.";
    });
    
    _addScanLogEntry("SYSTEM", _statusMessage);
  }

  // 3. Connect to the Device
  Future<void> _connectToNode(BluetoothDevice device, int index) async {
    String dName = device.platformName.isNotEmpty ? device.platformName : "Saved Node";
    _addScanLogEntry("CONNECTING", "Initiating handshake with $dName...");
    setState(() {
      _statusMessage = "INITIATING HANDSHAKE WITH $dName...";
    });

    try {
      await device.connect(
        license: License.free, 
        timeout: const Duration(seconds: 15),
      );
      
      // 4. SAVE TO MEMORY UPON SUCCESS
      ScanScreen.lastKnownNode = device;
      
      if (!mounted) return;
      setState(() {
        _statusMessage = "SECURE LINK ESTABLISHED!";
      });
      
      _addScanLogEntry("SUCCESS", "Secure link established with $dName!");
      
      // Tell the Storyboard to change the screen to the Dashboard
      Future.delayed(const Duration(milliseconds: 500), () {
        widget.onConnect();
      });
    } catch (e) {
      if (!mounted) return;
      _addScanLogEntry("ERROR", "Connection failed: ${e.toString()}");
      setState(() {
        _statusMessage = "CONNECTION FAILED: ${e.toString()}";
      });
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft, color: Colors.white),
          onPressed: widget.onBack,
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "NODE SCANNER",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                letterSpacing: 2.0,
                color: Colors.white,
              ),
            ),
            Text(
              "MESH NETWORK DISCOVERY",
              style: TextStyle(
                color: AppColors.accent,
                fontSize: 10,
              ),
            ),
          ],
        ),
        centerTitle: false,
      ),
      body: Column(
        children: [
          // 1. Scan Log (Chat-style)
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
                      color: isError 
                          ? Colors.red[900] 
                          : isSuccess
                              ? Colors.green[900]
                              : isMemory 
                                  ? Colors.blue[900] // Added blue color for memory log
                                  : AppColors.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isError
                            ? Colors.red[700]!
                            : isSuccess
                                ? Colors.green[700]!
                                : isMemory
                                    ? Colors.blue[700]!
                                    : AppColors.border,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          log['type']!,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isError
                                ? Colors.red[300]
                                : isSuccess
                                    ? Colors.green[300]
                                    : isMemory 
                                        ? Colors.blue[300]
                                        : AppColors.accent,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          log['message']!,
                          style: const TextStyle(fontSize: 13, color: Colors.white),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          log['time']!,
                          style: const TextStyle(fontSize: 9, color: Colors.white38),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // 2. Device List Section
          if (_meshtasticDevices.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "AVAILABLE NODES (${_meshtasticDevices.length})",
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                      color: AppColors.accent,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...List.generate(_meshtasticDevices.length, (index) {
                    final device = _meshtasticDevices[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.bg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            LucideIcons.bluetooth,
                            color: Colors.greenAccent,
                            size: 16,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  device.platformName.isNotEmpty
                                      ? device.platformName
                                      : "Saved Node",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  device.remoteId.toString(),
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green[800],
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            onPressed: () => _connectToNode(device, index),
                            child: const Text(
                              "LINK",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),

          // 3. Scan Button
          Container(
            padding: const EdgeInsets.all(16),
            color: AppColors.surface,
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isScanning ? Colors.grey[800] : Colors.orange[800],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: _isScanning ? null : _requestPermissionsAndScan,
                child: Text(
                  _isScanning ? "SCANNING..." : "INITIATE SCAN",
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}