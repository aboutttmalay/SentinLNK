import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:meshtastic_flutter/generated/mesh.pb.dart';
import 'package:meshtastic_flutter/generated/portnums.pbenum.dart';
import 'package:meshtastic_flutter/generated/telemetry.pb.dart';

import '../../data/models/node_database.dart';

class HardwareBridge {
  static final HardwareBridge instance = HardwareBridge._init();
  HardwareBridge._init();

  BluetoothCharacteristic? _toRadioChar;
  StreamSubscription<List<int>>? _radioListener;
  bool _isHardwareConnected = false;
  bool _isSyncing = false; 
  bool _isReading = false;

  bool get isConnected => _isHardwareConnected;

  // ==========================================
  // 🚀 GLOBAL START 
  // ==========================================
  Future<void> connectAndSync() async {
    if (_isSyncing || _isHardwareConnected) return; 
    _isSyncing = true;

    try {
      var devices = FlutterBluePlus.connectedDevices;
      if (devices.isEmpty) return;
      
      BluetoothDevice device = devices.first;
      BluetoothCharacteristic? toRadio;
      BluetoothCharacteristic? fromRadio;
      BluetoothCharacteristic? fromNum;

      List<BluetoothService> services = await device.discoverServices();
      for (var s in services) {
        for (var c in s.characteristics) {
          String uuid = c.uuid.toString().toLowerCase();
          if (uuid.contains("f75c")) toRadio = c;       
          if (uuid.contains("2c55")) fromRadio = c;     
          if (uuid.contains("ed9d")) fromNum = c;       
        }
      }

      if (toRadio != null && fromRadio != null && fromNum != null) {
        _toRadioChar = toRadio;
        _isHardwareConnected = true;
        await _startRadioListener(fromRadio, fromNum); 
      }
    } catch (e) {
      print("Hardware Bridge Error: $e");
    } finally {
      _isSyncing = false;
    }
  }

  // ==========================================
  // 📥 THE BACKGROUND LISTENER
  // ==========================================
  Future<void> _startRadioListener(BluetoothCharacteristic fromRadio, BluetoothCharacteristic fromNum) async {
    print("🎧 [GLOBAL BRIDGE] SUBSCRIBING TO BELL...");
    await fromNum.setNotifyValue(true);

    _radioListener = fromNum.onValueReceived.listen((_) {
        print("🔔 BELL RANG AFTER SYNC");
      _drainMailbox(fromRadio); 
    });

    await Future.delayed(const Duration(milliseconds: 500));
    await _toRadioChar!.write([0x08, 0x01], withoutResponse: false);

    await Future.delayed(const Duration(milliseconds: 500));
    int randomConfigId = Random().nextInt(999999) + 1;
    print("📥 [GLOBAL BRIDGE] REQUESTING NODE DB SYNC (ID: $randomConfigId)...");
    
    final req = ToRadio()..wantConfigId = randomConfigId; 
    await _toRadioChar!.write(req.writeToBuffer(), withoutResponse: false);

    await Future.delayed(const Duration(milliseconds: 200));
    _drainMailbox(fromRadio); 
  }

  // ==========================================
  // 📨 HELPER: SAFE MAILBOX DRAINER
  // ==========================================
  Future<void> _drainMailbox(BluetoothCharacteristic fromRadio) async {
  if (_isReading) return;
  _isReading = true;

  try {
    // Keep reading until we get 3 consecutive empty reads
    int emptyCount = 0;
    while (emptyCount < 3) {
      List<int> bytes = await fromRadio.read();
      if (bytes.isEmpty) {
        emptyCount++;
        await Future.delayed(const Duration(milliseconds: 50));
      } else {
        emptyCount = 0;
        print("📡 RAW BYTES CAUGHT: ${bytes.length} bytes");
        _processDecodedPacket(bytes);
      }
    }
  } catch (e) {
    print("🔴 MAILBOX DRAIN ERROR: $e");
  } finally {
    _isReading = false;
  }
}
  // ==========================================
  // 📨 HELPER: OFFICIAL PROTOBUF STATE MACHINE
  // ==========================================
  void _processDecodedPacket(List<int> bytes) {
    try {
      final fromRadio = FromRadio.fromBuffer(bytes);

      if (fromRadio.hasMyInfo()) {
         String myHex = "!${fromRadio.myInfo.myNodeNum.toRadixString(16).toLowerCase()}";
         print("📍 SET LOCAL NODE: $myHex");
         NodeDatabase.instance.setLocalHardwareId(myHex);
         return; 
      }

      if (fromRadio.hasNodeInfo()) {
         print("📥 DOWNLOADED NODE: ${fromRadio.nodeInfo.user.longName}");
         NodeDatabase.instance.processDirectNodeInfo(fromRadio.nodeInfo);
         return; 
      }

      if (fromRadio.hasConfigCompleteId()) {
         print("✅ RADIO SYNC 100% COMPLETE!");
         return;
      }

      if (fromRadio.hasPacket() && fromRadio.packet.hasDecoded()) {
        final data = fromRadio.packet.decoded;
        final senderId = "!${fromRadio.packet.from.toRadixString(16).toLowerCase()}"; 
        
        if (data.portnum == PortNum.TEXT_MESSAGE_APP) {
           String messageText = utf8.decode(data.payload);
           NodeDatabase.instance.notifyNewMessage(messageText); 
        } 
        else if (data.portnum == PortNum.NODEINFO_APP) {
           final user = User.fromBuffer(data.payload);
           final tempInfo = NodeInfo()..num = fromRadio.packet.from..user = user;
           NodeDatabase.instance.processDirectNodeInfo(tempInfo);
        }
        else if (data.portnum == PortNum.TELEMETRY_APP) {
           final telemetry = Telemetry.fromBuffer(data.payload);
           if (telemetry.hasDeviceMetrics()) {
              print("🔋 HEALTH UPDATE: $senderId (${telemetry.deviceMetrics.batteryLevel}%)");
              double rxSnr = fromRadio.packet.hasRxSnr() ? fromRadio.packet.rxSnr.toDouble() : 0.0;
              int rxRssi = fromRadio.packet.hasRxRssi() ? fromRadio.packet.rxRssi : -100;
              
              NodeDatabase.instance.processTelemetry(
                senderId,
                telemetry.deviceMetrics.batteryLevel.toDouble(),
                telemetry.deviceMetrics.voltage.toDouble(),
                rxSnr,
                rxRssi
              );
           }
        }
      }
    } catch (e) {
      print("🔴 PACKET DECODE ERROR: $e");
    }
  }

  // ==========================================
  // 📤 GLOBAL TRANSMITTER
  // ==========================================
  Future<void> sendTacticalMessage(String text) async {
    if (_toRadioChar == null) return;
    try {
      final data = Data()..portnum = PortNum.TEXT_MESSAGE_APP..payload = utf8.encode(text);
      final packet = MeshPacket()..decoded = data..to = 0xFFFFFFFF..wantAck = true;
      final toRadio = ToRadio()..packet = packet;
      await _toRadioChar!.write(toRadio.writeToBuffer(), withoutResponse: false);
    } catch (e) {}
  }
}