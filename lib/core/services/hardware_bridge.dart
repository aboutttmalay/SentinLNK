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

  Future<void> _startRadioListener(BluetoothCharacteristic fromRadio, BluetoothCharacteristic fromNum) async {
    await fromNum.setNotifyValue(true);

    _radioListener = fromNum.onValueReceived.listen((_) {
      _drainMailbox(fromRadio); 
    });

    await Future.delayed(const Duration(milliseconds: 500));
    await _toRadioChar!.write([0x08, 0x01], withoutResponse: false);

    await Future.delayed(const Duration(milliseconds: 500));
    int randomConfigId = Random().nextInt(999999) + 1;
    final req = ToRadio()..wantConfigId = randomConfigId; 
    await _toRadioChar!.write(req.writeToBuffer(), withoutResponse: false);

    await Future.delayed(const Duration(milliseconds: 200));
    _drainMailbox(fromRadio); 
  }

  Future<void> _drainMailbox(BluetoothCharacteristic fromRadio) async {
    if (_isReading) return;
    _isReading = true;

    try {
      int emptyCount = 0;
      while (emptyCount < 2) {
        List<int> bytes = await fromRadio.read();
        
        if (bytes.isEmpty) {
          emptyCount++;
        } else {
          emptyCount = 0; 
          _processDecodedPacket(bytes); 
        }
        await Future.delayed(const Duration(milliseconds: 100)); 
      }
    } catch (e) {
    } finally {
      _isReading = false; 
    }
  }

  void _processDecodedPacket(List<int> bytes) {
    try {
      final fromRadio = FromRadio.fromBuffer(bytes);

      if (fromRadio.hasMyInfo()) {
         String myHex = "!${fromRadio.myInfo.myNodeNum.toRadixString(16).toLowerCase()}";
         NodeDatabase.instance.setLocalHardwareId(myHex);
         return; 
      }
      if (fromRadio.hasNodeInfo()) {
         NodeDatabase.instance.processDirectNodeInfo(fromRadio.nodeInfo);
         return; 
      }
      if (fromRadio.hasConfigCompleteId()) { return; }

      // 👉 EXTRACT LIVE SIGNAL DATA FROM EVERY PACKET
      if (fromRadio.hasPacket()) {
        final packet = fromRadio.packet;
        final senderId = "!${packet.from.toRadixString(16).toLowerCase()}"; 
        
        if (packet.hasRxRssi() || packet.hasRxSnr()) {
           double rxSnr = packet.hasRxSnr() ? packet.rxSnr.toDouble() : 0.0;
           int rxRssi = packet.hasRxRssi() ? packet.rxRssi : -100;
           NodeDatabase.instance.updateSignalMetrics(senderId, rxSnr, rxRssi);
        }

        if (packet.hasDecoded()) {
          final data = packet.decoded;
          
          if (data.portnum == PortNum.TEXT_MESSAGE_APP) {
             String messageText = utf8.decode(data.payload);
             NodeDatabase.instance.notifyNewMessage(messageText); 
          } 
          else if (data.portnum == PortNum.NODEINFO_APP) {
             final user = User.fromBuffer(data.payload);
             final tempInfo = NodeInfo()..num = packet.from..user = user;
             NodeDatabase.instance.processDirectNodeInfo(tempInfo);
          }
          else if (data.portnum == PortNum.TELEMETRY_APP) {
             final telemetry = Telemetry.fromBuffer(data.payload);
             if (telemetry.hasDeviceMetrics()) {
                double rxSnr = packet.hasRxSnr() ? packet.rxSnr.toDouble() : 0.0;
                int rxRssi = packet.hasRxRssi() ? packet.rxRssi : -100;
                NodeDatabase.instance.processTelemetry(
                  senderId, telemetry.deviceMetrics.batteryLevel.toDouble(),
                  telemetry.deviceMetrics.voltage.toDouble(), rxSnr, rxRssi
                );
             }
          }
        }
      }
    } catch (e) {}
  }

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