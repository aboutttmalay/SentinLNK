import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart'; 
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:meshtastic_flutter/generated/mesh.pb.dart';
import 'package:meshtastic_flutter/generated/portnums.pbenum.dart';
import 'package:meshtastic_flutter/generated/telemetry.pb.dart';
import 'package:crypto/crypto.dart';
import 'package:meshtastic_flutter/generated/channel.pb.dart';
import 'package:meshtastic_flutter/generated/admin.pb.dart';

import '../../data/models/node_database.dart';
import '../storage/storage_service.dart';

class HardwareBridge {
  static final HardwareBridge instance = HardwareBridge._init();
  HardwareBridge._init();

  BluetoothCharacteristic? _toRadioChar;
  StreamSubscription<List<int>>? _radioListener;
  bool _isHardwareConnected = false;
  bool _isSyncing = false; 
  bool _isReading = false;

  final ValueNotifier<String> currentSquad = ValueNotifier("Global Mesh");

  bool get isConnected => _isHardwareConnected;

  Future<void> connectAndSync() async {
    if (_isSyncing || _isHardwareConnected) return; 
    _isSyncing = true;

    try {
      var devices = FlutterBluePlus.connectedDevices;
      if (devices.isEmpty) return;
      
      BluetoothDevice device = devices.first;
      print("HardwareBridge: Connected to ${device.platformName}, discovering services...");

      await Future.delayed(const Duration(milliseconds: 500));
      List<BluetoothService> services = await device.discoverServices();
      
      BluetoothCharacteristic? fromRadio;
      BluetoothCharacteristic? fromNum;

      // 👉 THE FIX: We collect ALL characteristics first before doing anything!
      for (var s in services) {
        for (var c in s.characteristics) {
          String uuid = c.uuid.toString().toLowerCase();
          
          if (uuid.contains("f75c")) {
            _toRadioChar = c;
            print("HardwareBridge: Linked TX Pipeline (toRadio)");
          }       
          if (uuid.contains("2c55")) {
            fromRadio = c;
            print("HardwareBridge: Linked RX Mailbox (fromRadio)");
          }
          if (uuid.contains("ed9d")) {
            fromNum = c;
            print("HardwareBridge: Linked Notification Pipeline (fromNum)");
          }
        }
      }

      // 👉 Once we have all three pipelines, THEN we start the listener!
      if (_toRadioChar != null && fromRadio != null && fromNum != null) {
        _isHardwareConnected = true;
        print("HardwareBridge: Fully Linked and Operational! Starting Listener...");
        await _startRadioListener(fromRadio, fromNum); 
      } else {
        print("🔴 HardwareBridge: Missing required characteristics!");
      }
    } catch (e) {
      print("Hardware Bridge Error: $e");
    } finally {
      _isSyncing = false;
    }
  }

  void disconnectAndWipe() {
    print("HardwareBridge: Wiping active connections and buffers...");
    _radioListener?.cancel();
    _radioListener = null;
    _toRadioChar = null;
    _isHardwareConnected = false;
    _isSyncing = false;
    _isReading = false;
    currentSquad.value = "Global Mesh"; 
  }

  Future<void> _startRadioListener(BluetoothCharacteristic fromRadio, BluetoothCharacteristic fromNum) async {
    await fromNum.setNotifyValue(true);

    _radioListener = fromNum.onValueReceived.listen((_) {
      _drainMailbox(fromRadio); 
    });

    await Future.delayed(const Duration(milliseconds: 500));
    
    if (_toRadioChar != null) {
      print("HardwareBridge: Sending Wakeup Command");
      await _toRadioChar!.write([0x08, 0x01], withoutResponse: false);

      await Future.delayed(const Duration(milliseconds: 500));
      int randomConfigId = Random().nextInt(999999) + 1;
      final req = ToRadio()..wantConfigId = randomConfigId; 
      
      print("HardwareBridge: Requesting Node DB Sync...");
      await _toRadioChar!.write(req.writeToBuffer(), withoutResponse: false);
    }

    await Future.delayed(const Duration(milliseconds: 200));
    _drainMailbox(fromRadio); 
  }

  Future<void> _drainMailbox(BluetoothCharacteristic fromRadio) async {
    if (_isReading) return;
    _isReading = true;

    try {
      int emptyCount = 0;
      while (emptyCount < 15) {
        List<int> bytes = await fromRadio.read();
        if (bytes.isEmpty) {
          emptyCount++;
          await Future.delayed(const Duration(milliseconds: 100)); 
        } else {
          emptyCount = 0; 
          _processDecodedPacket(bytes); 
          await Future.delayed(const Duration(milliseconds: 10)); 
        }
      }
    } catch (e) {
      print("Drain Mailbox Error: $e");
    } finally {
      _isReading = false; 
    }
  }

  void _processDecodedPacket(List<int> bytes) {
    try {
      final fromRadio = FromRadio.fromBuffer(bytes);

      if (fromRadio.hasMyInfo()) {
         int nodeNum = fromRadio.myInfo.myNodeNum; 
         String myHex = "!${nodeNum.toRadixString(16).toLowerCase().padLeft(8, '0')}";
         NodeDatabase.instance.setLocalHardwareId(myHex);
         return; 
      }
      if (fromRadio.hasNodeInfo()) {
         NodeDatabase.instance.processDirectNodeInfo(fromRadio.nodeInfo);
         return; 
      }
      if (fromRadio.hasConfigCompleteId()) { return; }

      if (fromRadio.hasPacket()) {
        final packet = fromRadio.packet;
        final senderId = "!${packet.from.toRadixString(16).toLowerCase().padLeft(8, '0')}"; 
        
        if (packet.hasRxRssi() || packet.hasRxSnr()) {
           double rxSnr = packet.hasRxSnr() ? packet.rxSnr.toDouble() : 0.0;
           int rxRssi = packet.hasRxRssi() ? packet.rxRssi : -100;
           NodeDatabase.instance.updateSignalMetrics(senderId, rxSnr, rxRssi);
        }

        if (packet.hasDecoded()) {
          final data = packet.decoded;
          
          if (data.portnum == PortNum.TEXT_MESSAGE_APP) {
             try {
               String messageText = utf8.decode(data.payload);
               if (senderId != NodeDatabase.instance.localNodeHexId) {
                 print("📥 INCOMING CHAT: $messageText");
                 final timestamp = "${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}";
                 StorageService.saveMessage(messageText, false, timestamp);
                 
                 // Fire UI Pulse
                 NodeDatabase.instance.notifyNewMessage(messageText); 
               }
             } catch(e) {
               print("🔴 FAILED TO DECODE MESSAGE: $e");
             }
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
      print("📤 SENDING MESSAGE: $text");
      
      final data = Data()
        ..portnum = PortNum.TEXT_MESSAGE_APP
        ..payload = utf8.encode(text);
      
      final packetId = Random().nextInt(0x7FFFFFFF);

      final packet = MeshPacket()
        ..id = packetId
        ..decoded = data
        ..to = 0xFFFFFFFF // Broadcast address
        ..wantAck = false // Prevents radio from dropping the broadcast
        ..channel = 0;    // Broadcast channel
        
      final toRadio = ToRadio()..packet = packet;
      await _toRadioChar!.write(toRadio.writeToBuffer(), withoutResponse: false);
      print("🟢 MESSAGE INJECTED TO HARDWARE TX BUFFER. ID: $packetId");
    } catch (e) {
      print("🔴 ERROR SENDING MESSAGE: $e");
    }
  }

  Future<void> setGroupCode(String groupCode) async {
    if (_toRadioChar == null) {
      print("🔴 FAILED: Hardware bridge not linked. Ensure Bluetooth is connected.");
      return;
    }
    try {
      print("🛡️ GENERATING AES-256 KEY FOR SQUAD: $groupCode");
      List<int> aesKey = sha256.convert(utf8.encode(groupCode)).bytes;

      ChannelSettings settings = ChannelSettings()
        ..name = groupCode
        ..psk = aesKey;

      Channel primaryChannel = Channel()
        ..index = 0
        ..settings = settings
        ..role = Channel_Role.PRIMARY;

      AdminMessage adminMsg = AdminMessage()..setChannel = primaryChannel;
      
      Data adminData = Data()
        ..portnum = PortNum.ADMIN_APP
        ..payload = adminMsg.writeToBuffer();

      MeshPacket adminPacket = MeshPacket()
        ..decoded = adminData
        ..to = 0xFFFFFFFF 
        ..wantAck = true;

      ToRadio request = ToRadio()..packet = adminPacket;

      print("📤 TRANSMITTING SQUAD ENCRYPTION TO HARDWARE...");
      await _toRadioChar!.write(request.writeToBuffer(), withoutResponse: false);
      
      currentSquad.value = groupCode;
      print("🟢 SQUAD CHANNEL SET! Radio will now reboot onto the private mesh.");
      
    } catch (e) {
      print("🔴 SQUAD SETUP ERROR: $e");
    }
  }
}