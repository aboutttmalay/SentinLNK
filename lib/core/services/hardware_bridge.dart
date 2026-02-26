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
          
          // 👉 FIX: Check for Text Messages regardless of which channel they arrived on
          if (data.portnum == PortNum.TEXT_MESSAGE_APP) {
             try {
               String messageText = utf8.decode(data.payload);
               if (senderId != NodeDatabase.instance.localNodeHexId) {
                 
                 // Check which channel the packet physically arrived on
                 bool isSquadMsg = (packet.channel == 1);
                 String type = isSquadMsg ? "SQUAD" : "GLOBAL";
                 
                 print("📥 INCOMING [$type] on Channel ${packet.channel}: $messageText");
                 
                 final timestamp = "${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}";
                 
                 StorageService.saveMessage(messageText, false, timestamp, isSquad: isSquadMsg);
                 NodeDatabase.instance.notifyNewMessage("$type|$messageText"); 
               }
             } catch(e) {
                 print("🔴 Failed to decode incoming text: $e");
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

  // =========================================================================
  // 🚀 REVERSE-ENGINEERED LORA TRANSMISSION LOGIC
  // =========================================================================
  Future<void> sendTacticalMessage(String text, {bool isSquad = false}) async {
    if (_toRadioChar == null) return;
    try {
      print("📤 TRANSMITTING [${isSquad ? "SQUAD" : "GLOBAL"}]: $text");
      
      final data = Data()
        ..portnum = PortNum.TEXT_MESSAGE_APP
        ..payload = utf8.encode(text);
      
      // 🚨 SENIOR FIX: DO NOT SET `id` OR `from`! 
      // If we fake these, the radio's anti-spoofing engine drops the packet.
      // By leaving them blank, the hardware natively signs, sequences, and encrypts it!
      final packet = MeshPacket()
        ..decoded = data
        ..to = 0xFFFFFFFF // Broadcast to all radios
        ..wantAck = false 
        ..channel = isSquad ? 1 : 0; // Hardware routes to physical Channel 0 or 1
        
      final toRadio = ToRadio()..packet = packet;
      await _toRadioChar!.write(toRadio.writeToBuffer(), withoutResponse: false);
      print("🟢 PACKET ACCEPTED BY HARDWARE SECURITY ENGINE.");
    } catch (e) {
      print("🔴 ERROR TRANSMITTING: $e");
    }
  }

  // =========================================================================
  // 🛡️ HARDWARE-FORCED AES-256 FLASH (Channel 1 Creation)
  // =========================================================================
  Future<void> setGroupCode(String groupCode) async {
    if (_toRadioChar == null) {
      print("🔴 FAILED: Hardware bridge not linked.");
      return;
    }
    try {
      print("🛡️ INITIATING HARDWARE FLASH: CHANNEL 1 ($groupCode)");
      
      // 1. Generate 32-byte AES-256 Key from the code
      List<int> aesKey = sha256.convert(utf8.encode(groupCode)).bytes;

      // 2. Build the exact Channel Settings required by the firmware
      // 👉 FIX: Removed modemConfig. Secondary channels inherit LoRa physical settings from Primary.
      ChannelSettings settings = ChannelSettings()
        ..name = groupCode
        ..psk = aesKey;

      // 3. Define the Channel object for Index 1
      Channel squadChannel = Channel()
        ..index = 1 
        ..settings = settings
        ..role = Channel_Role.SECONDARY; 

      // 4. Wrap it in the Admin Message (This tells the firmware "I am the owner")
      AdminMessage adminMsg = AdminMessage()..setChannel = squadChannel;
      
      // 5. Wrap it in Data payload for the internal Admin Port
      Data adminData = Data()
        ..portnum = PortNum.ADMIN_APP
        ..payload = adminMsg.writeToBuffer();

      // 6. Get the exact Node ID (Required for Admin commands to pass the firewall)
      int localNodeNum = 0xFFFFFFFF; 
      if (NodeDatabase.instance.localNodeHexId.isNotEmpty) {
         localNodeNum = int.parse(NodeDatabase.instance.localNodeHexId.replaceAll('!', ''), radix: 16);
      }

      // 7. Generate a unique ID so the hardware doesn't drop it as a duplicate
      int packetId = Random().nextInt(0x7FFFFFFF);

      // 8. The Master Wrapper: Routed to self (localNodeNum) on internal Channel 0
      MeshPacket adminPacket = MeshPacket()
        ..to = localNodeNum
        ..from = localNodeNum 
        ..id = packetId
        ..channel = 0 
        ..decoded = adminData
        ..wantAck = true; // Request acknowledgment that the flash memory saved it

      ToRadio request = ToRadio()..packet = adminPacket;

      print("📤 OVERWRITING HARDWARE CRYPTO CHIP ($localNodeNum)...");
      await _toRadioChar!.write(request.writeToBuffer(), withoutResponse: false);
      
      // 👉 NEW: Send a "Commit to Flash" command to force the radio to reboot/save
      await Future.delayed(const Duration(milliseconds: 500));
      AdminMessage commitMsg = AdminMessage()..commitEditSettings = true;
      Data commitData = Data()..portnum = PortNum.ADMIN_APP..payload = commitMsg.writeToBuffer();
      MeshPacket commitPacket = MeshPacket()..to = localNodeNum..from = localNodeNum..channel=0..id = Random().nextInt(0x7FFFFFFF)..decoded = commitData;
      await _toRadioChar!.write((ToRadio()..packet = commitPacket).writeToBuffer(), withoutResponse: false);

      // CRITICAL: Give hardware Non-Volatile Memory (Flash) time to rewrite and reboot
      await Future.delayed(const Duration(milliseconds: 2000));
      
      currentSquad.value = groupCode;
      print("🟢 SQUAD ENCRYPTION LOCKED & LOADED!");
      
    } catch (e) {
      print("🔴 SQUAD SETUP ERROR: $e");
    }
  }
}