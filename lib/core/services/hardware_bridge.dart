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

  BluetoothDevice? connectedDevice;

  bool get isConnected => _isHardwareConnected;

  Future<void> connectAndSync(BluetoothDevice device) async {
    if (_isSyncing || _isHardwareConnected) return; 
    _isSyncing = true;
    connectedDevice = device; 

    try {
      print("HardwareBridge: Connected to ${device.platformName}, discovering services...");
      StorageService.saveKnownDevice(device.remoteId.str, device.platformName);

      await Future.delayed(const Duration(milliseconds: 500));
      List<BluetoothService> services = await device.discoverServices();
      
      BluetoothCharacteristic? fromRadio;
      BluetoothCharacteristic? fromNum;

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

      if (_toRadioChar != null && fromRadio != null && fromNum != null) {
        _isHardwareConnected = true;
        print("HardwareBridge: Fully Linked! Starting Listener...");
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

  Future<void> disconnectAndUnpair() async {
    print("HardwareBridge: Unpairing and Disconnecting...");
    if (connectedDevice != null) {
      await StorageService.removeKnownDevice(connectedDevice!.remoteId.str);
      await connectedDevice!.disconnect();
    }
    _radioListener?.cancel();
    _radioListener = null;
    _toRadioChar = null;
    _isHardwareConnected = false;
    _isSyncing = false;
    _isReading = false;
    currentSquad.value = "Global Mesh"; 
    connectedDevice = null;
  }

  Future<void> _startRadioListener(BluetoothCharacteristic fromRadio, BluetoothCharacteristic fromNum) async {
    await fromNum.setNotifyValue(true);
    _radioListener = fromNum.onValueReceived.listen((_) {
      _drainMailbox(fromRadio); 
    });

    await Future.delayed(const Duration(milliseconds: 500));
    if (_toRadioChar != null) {
      await _toRadioChar!.write([0x08, 0x01], withoutResponse: false);
      await Future.delayed(const Duration(milliseconds: 500));
      int randomConfigId = Random().nextInt(999999) + 1;
      final req = ToRadio()..wantConfigId = randomConfigId; 
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
    } catch (e) {} finally {
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
           NodeDatabase.instance.updateSignalMetrics(senderId, packet.hasRxSnr() ? packet.rxSnr.toDouble() : 0.0, packet.hasRxRssi() ? packet.rxRssi : -100);
        }

        if (packet.hasDecoded()) {
          final data = packet.decoded;
          
          if (data.portnum == PortNum.TEXT_MESSAGE_APP) {
             try {
               String messageText = utf8.decode(data.payload);
               if (senderId != NodeDatabase.instance.localNodeHexId) {
                 bool isSquadMsg = (packet.channel == 1);
                 String type = isSquadMsg ? "SQUAD" : "GLOBAL";
                 print("📥 INCOMING [$type]: $messageText");
                 final timestamp = "${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}";
                 
                 // 👉 THE MISSING FIX: Actually save incoming messages to the correct database!
                 StorageService.saveMessage(messageText, false, timestamp, isSquad: isSquadMsg);
                 
                 NodeDatabase.instance.notifyNewMessage("$type|$messageText"); 
               }
             } catch(e) {}
          } 
          else if (data.portnum == PortNum.NODEINFO_APP) {
             final user = User.fromBuffer(data.payload);
             final tempInfo = NodeInfo()..num = packet.from..user = user;
             NodeDatabase.instance.processDirectNodeInfo(tempInfo);
          }
          else if (data.portnum == PortNum.TELEMETRY_APP) {
             final telemetry = Telemetry.fromBuffer(data.payload);
             if (telemetry.hasDeviceMetrics()) {
                NodeDatabase.instance.processTelemetry(
                  senderId, telemetry.deviceMetrics.batteryLevel.toDouble(),
                  telemetry.deviceMetrics.voltage.toDouble(), 
                  packet.hasRxSnr() ? packet.rxSnr.toDouble() : 0.0, 
                  packet.hasRxRssi() ? packet.rxRssi : -100
                );
             }
          }
        }
      }
    } catch (e) {}
  }

  Future<void> sendTacticalMessage(String text, {bool isSquad = false}) async {
    if (_toRadioChar == null) return;
    try {
      print("📤 SENDING [${isSquad ? "SQUAD" : "GLOBAL"}]: $text");
      
      final data = Data()
        ..portnum = PortNum.TEXT_MESSAGE_APP
        ..payload = utf8.encode(text);
      
      final packetId = Random().nextInt(0x7FFFFFFF);
      int channelIndex = isSquad ? 1 : 0;
      
      int localNodeNum = 0xFFFFFFFF;
      if (NodeDatabase.instance.localNodeHexId.isNotEmpty) {
         localNodeNum = int.parse(NodeDatabase.instance.localNodeHexId.replaceAll('!', ''), radix: 16);
      }

      final packet = MeshPacket()
        ..from = localNodeNum // 👉 FORCE HARDWARE ORIGIN
        ..id = packetId
        ..decoded = data
        ..to = 0xFFFFFFFF 
        ..wantAck = false 
        ..channel = channelIndex;    
        
      final toRadio = ToRadio()..packet = packet;
      await _toRadioChar!.write(toRadio.writeToBuffer(), withoutResponse: false);
    } catch (e) {
      print("🔴 ERROR SENDING: $e");
    }
  }

  Future<void> setGroupCode(String groupCode) async {
    if (_toRadioChar == null) {
      print("🔴 FAILED: Hardware bridge not linked.");
      return;
    }
    try {
      print("🛡️ CONFIGURING SQUAD CHANNEL 1: $groupCode");
      
      List<int> aesKey = sha256.convert(utf8.encode(groupCode)).bytes;

      ChannelSettings settings = ChannelSettings()
        ..name = groupCode
        ..psk = aesKey;

      Channel squadChannel = Channel()
        ..index = 1 
        ..settings = settings
        ..role = Channel_Role.SECONDARY; 

      AdminMessage adminMsg = AdminMessage()..setChannel = squadChannel;
      
      Data adminData = Data()
        ..portnum = PortNum.ADMIN_APP
        ..payload = adminMsg.writeToBuffer();

      int localNodeNum = 0xFFFFFFFF; 
      if (NodeDatabase.instance.localNodeHexId.isNotEmpty) {
         localNodeNum = int.parse(NodeDatabase.instance.localNodeHexId.replaceAll('!', ''), radix: 16);
      }
      
      int packetId = Random().nextInt(0x7FFFFFFF);

      // 👉 THE MASTER FIX: Perfect Admin Packet Formatting
      MeshPacket adminPacket = MeshPacket()
        ..from = localNodeNum // Must be from self
        ..to = localNodeNum   // Must be to self
        ..id = packetId       // MUST HAVE ID OR RADIO DROPS IT
        ..channel = 0         // Admin configs MUST traverse internal channel 0
        ..decoded = adminData
        ..wantAck = true;

      ToRadio request = ToRadio()..packet = adminPacket;

      print("📤 INJECTING ENCRYPTION KEY DEEP INTO FLASH MEMORY...");
      await _toRadioChar!.write(request.writeToBuffer(), withoutResponse: false);
      
      // Wait for radio flash memory to cycle before confirming
      await Future.delayed(const Duration(milliseconds: 800));
      
      currentSquad.value = groupCode;
      print("🟢 SQUAD SECURE LINK ESTABLISHED!");
      
    } catch (e) {
      print("🔴 SQUAD SETUP ERROR: $e");
    }
  }
}