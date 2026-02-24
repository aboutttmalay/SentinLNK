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
      if (devices.isEmpty) {
        print("HardwareBridge: No Bluetooth devices connected.");
        return;
      }
      
      BluetoothDevice device = devices.first;
      print("HardwareBridge: Connected to ${device.platformName}, discovering services...");

      // 👉 FIX: Give the radio a second to settle before discovering services
      await Future.delayed(const Duration(milliseconds: 500));
      List<BluetoothService> services = await device.discoverServices();
      
      for (var s in services) {
        // The main Meshtastic UUID usually contains "6ba1b218" or we can just scan all characteristics
        for (var c in s.characteristics) {
          String uuid = c.uuid.toString().toLowerCase();
          
          // Write to Radio (TX)
          if (uuid.contains("f75c")) {
            _toRadioChar = c;
            print("HardwareBridge: Linked TX Pipeline (toRadio)");
          }       
          // Read from Radio (RX Mailbox)
          if (uuid.contains("2c55")) {
            print("HardwareBridge: Linked RX Mailbox (fromRadio)");
            await _startRadioListener(c, s.characteristics.firstWhere((char) => char.uuid.toString().toLowerCase().contains("ed9d"))); 
          }
        }
      }

      if (_toRadioChar != null) {
        _isHardwareConnected = true;
        print("HardwareBridge: Fully Linked and Operational!");
      } else {
        print("HardwareBridge: ERROR - Could not find TX pipeline.");
      }

    } catch (e) {
      print("Hardware Bridge Error: $e");
    } finally {
      _isSyncing = false;
    }
  }

  // 👉 NEW: FLUSHES THE PIPELINES AND RESETS THE SQUAD
  void disconnectAndWipe() {
    print("HardwareBridge: Wiping active connections and buffers...");
    _radioListener?.cancel();
    _radioListener = null;
    _toRadioChar = null;
    _isHardwareConnected = false;
    _isSyncing = false;
    _isReading = false;
    currentSquad.value = "Global Mesh"; // Reset squad
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
    } finally {
      _isReading = false; 
    }
  }

  void _processDecodedPacket(List<int> bytes) {
    try {
      final fromRadio = FromRadio.fromBuffer(bytes);

      if (fromRadio.hasMyInfo()) {
         String myHex = "!${fromRadio.myInfo.myNodeNum.toRadixString(16).toLowerCase().padLeft(8, '0')}";
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
               // 👉 CRITICAL FIX: Only show incoming message if it wasn't sent by our own local hardware
               if (senderId != NodeDatabase.instance.localNodeHexId) {
                 print("📥 INCOMING CHAT: $messageText");
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
      final data = Data()..portnum = PortNum.TEXT_MESSAGE_APP..payload = utf8.encode(text);
      
      final packet = MeshPacket()
        ..id = Random().nextInt(0xFFFFFFFF) // 👉 CRITICAL FIX: Hardware requires a unique packet ID
        ..decoded = data
        ..to = 0xFFFFFFFF
        ..wantAck = true;
        
      final toRadio = ToRadio()..packet = packet;
      await _toRadioChar!.write(toRadio.writeToBuffer(), withoutResponse: false);
    } catch (e) {
      print("🔴 ERROR SENDING MESSAGE: $e");
    }
  }

  // ==========================================
  // 🛡️ TACTICAL SQUAD GROUP CODE SYSTEM
  // ==========================================
  Future<void> setGroupCode(String groupCode) async {
    // 👉 FIX: The bridge will now correctly hold _toRadioChar and pass this gate!
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