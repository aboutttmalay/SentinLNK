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
  StreamSubscription<BluetoothConnectionState>? _connectionStateListener; // 👉 Watchdog Listener
  
  // 👉 THE FIX: The missing notifier that home_screen is looking for!
  final ValueNotifier<bool> isConnectedNotifier = ValueNotifier(false); 
  
  bool _isSyncing = false; 
  bool _isReading = false;
  final ValueNotifier<String> currentSquad = ValueNotifier("Global Mesh");
  BluetoothDevice? connectedDevice;

  bool get isConnected => isConnectedNotifier.value;

  Future<void> connectAndSync(BluetoothDevice device) async {
    if (_isSyncing || isConnectedNotifier.value) return; 
    _isSyncing = true;
    connectedDevice = device; 

    try {
      print("HardwareBridge: Connecting to ${device.platformName}...");
      
      // Connect to the hardware
      await device.connect(license: License.free, autoConnect: false);
      StorageService.saveKnownDevice(device.remoteId.str, device.platformName);

      // 👉 THE WATCHDOG: Listen for unexpected drops (like when the radio reboots)
      _connectionStateListener?.cancel();
      _connectionStateListener = device.connectionState.listen((BluetoothConnectionState state) {
        if (state == BluetoothConnectionState.disconnected) {
          print("⚠️ HARDWARE DISCONNECTED (Likely Rebooting). Initiating Watchdog...");
          _handleDisconnection();
        }
      });

      await Future.delayed(const Duration(milliseconds: 500));
      List<BluetoothService> services = await device.discoverServices();
      
      BluetoothCharacteristic? fromRadio;
      BluetoothCharacteristic? fromNum;

      for (var s in services) {
        for (var c in s.characteristics) {
          String uuid = c.uuid.toString().toLowerCase();
          if (uuid.contains("f75c")) _toRadioChar = c;
          if (uuid.contains("2c55")) fromRadio = c;
          if (uuid.contains("ed9d")) fromNum = c;
        }
      }

      if (_toRadioChar != null && fromRadio != null && fromNum != null) {
        print("HardwareBridge: Pipelines Linked! Starting Listener...");
        await _startRadioListener(fromRadio, fromNum); 
        isConnectedNotifier.value = true; // Tell the UI we are ready!
      } else {
        print("🔴 HardwareBridge: Missing required characteristics!");
      }
    } catch (e) {
      print("Hardware Bridge Error: $e");
      _handleDisconnection();
    } finally {
      _isSyncing = false;
    }
  }

  Timer? _watchdogTimer; // 👉 NEW: The Auto-Reconnect Engine

  // =========================================================================
  // 🔄 OFFICIAL AUTO-RECONNECT WATCHDOG
  // =========================================================================
  void _handleDisconnection() {
    isConnectedNotifier.value = false;
    _toRadioChar = null;
    _radioListener?.cancel();
    _radioListener = null;

    // If we have a known device and the watchdog isn't already running, start it!
    if (connectedDevice != null && !(_watchdogTimer?.isActive ?? false)) {
      print("⚠️ LINK SEVERED (Radio Rebooting). Engaging Auto-Reconnect Watchdog...");
      
      _watchdogTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
        if (isConnectedNotifier.value) {
          print("🟢 WATCHDOG: Hardware lock re-established. Standing down.");
          timer.cancel();
          return;
        }
        try {
          print("🔄 WATCHDOG: Scanning for ${connectedDevice!.platformName}...");
          await connectAndSync(connectedDevice!);
        } catch (e) {
          print("🔄 WATCHDOG: Hardware still offline. Retrying in 5s...");
        }
      });
    }
  }

  Future<void> disconnectAndUnpair() async {
    print("HardwareBridge: Unpairing and Disconnecting...");
    _watchdogTimer?.cancel(); // 👉 CRITICAL: Kill watchdog so it doesn't reconnect if user intentionally logs out
    
    if (connectedDevice != null) {
      await StorageService.removeKnownDevice(connectedDevice!.remoteId.str);
      await connectedDevice!.disconnect();
    }
    connectedDevice = null; // Clear memory
    
    isConnectedNotifier.value = false;
    _toRadioChar = null;
    _radioListener?.cancel();
    _radioListener = null;
    currentSquad.value = "Global Mesh"; 
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
    } finally {
      _isReading = false; 
    }
  }

  // =========================================================================
  // 📥 INCOMING MESSAGE ROUTER & TELEMETRY ENGINE
  // =========================================================================
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
          
          // 👉 THE FIX: Channel Isolation for Text Messages
          if (data.portnum == PortNum.TEXT_MESSAGE_APP) {
             try {
               String messageText = utf8.decode(data.payload);
               
               if (senderId != NodeDatabase.instance.localNodeHexId) {
                 bool isSquadMsg = (packet.channel == 1);
                 String type = isSquadMsg ? "SQUAD" : "GLOBAL";
                 
                 // 👉 NEW: Look up the sender's actual node name from the Radar Map
                 String sName = senderId;
                 final radarMap = NodeDatabase.instance.radarMap.value;
                 if (radarMap.containsKey(senderId)) {
                     sName = radarMap[senderId]!.shortName; // Uses the 4-character short name
                 }

                 print("📥 INCOMING [$type] from $sName on Channel ${packet.channel}: $messageText");
                 final timestamp = "${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}";
                 
                 // Pass the senderName to Storage
                 StorageService.saveMessage(messageText, false, timestamp, isSquad: isSquadMsg, senderName: sName);
                 
                 // Pass the senderName into the Pulse generator
                 NodeDatabase.instance.notifyNewMessage("$type|$sName|$messageText"); 
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
    } catch (e) {
      print("🔴 Packet Decode Error: $e");
    }
  }

  // =========================================================================
  // 🚀 HARDWARE-DELEGATED LORA TRANSMISSION
  // =========================================================================
  Future<void> sendTacticalMessage(String text, {bool isSquad = false}) async {
    if (_toRadioChar == null) return;
    try {
      print("📤 TRANSMITTING [${isSquad ? "SQUAD (Ch1)" : "GLOBAL (Ch0)"}]: $text");
      
      final data = Data()
        ..portnum = PortNum.TEXT_MESSAGE_APP
        ..payload = utf8.encode(text);
      
      // 👉 THE MASTER FIX: Let the hardware handle the crypto!
      // If Squad, route to Channel 1. If Global, route to Channel 0.
      final packet = MeshPacket()
        ..decoded = data
        ..to = 0xFFFFFFFF // Broadcast
        ..wantAck = false 
        ..channel = isSquad ? 1 : 0; 
        
      final toRadio = ToRadio()..packet = packet;
      await _toRadioChar!.write(toRadio.writeToBuffer(), withoutResponse: false);
      print("🟢 PACKET HANDED TO HARDWARE LORA MODEM.");
    } catch (e) {
      print("🔴 ERROR TRANSMITTING: $e");
    }
  }

  // NOTE: setGroupCode() and Squad Setup logic has been entirely removed.
  // Hardware encryption keys are now managed securely by the Official App.

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
  // =========================================================================
  // 🛡️ PHASE 1: NATIVE HARDWARE PROVISIONING (OFFICIAL FLOW REPLICA)
  // =========================================================================
  Future<void> provisionTacticalChannel(Channel squadChannel) async {
    if (_toRadioChar == null) {
      print("🔴 FAILED: Hardware bridge not linked.");
      return;
    }
    try {
      String channelName = squadChannel.settings.name;
      print("🛡️ PROVISIONING HARDWARE: CHANNEL 1 ($channelName)");
      
      // 1. Get Local Node Num to ensure the hardware knows the command is for itself
      int localNodeNum = 0xFFFFFFFF; 
      if (NodeDatabase.instance.localNodeHexId.isNotEmpty) {
         localNodeNum = int.parse(NodeDatabase.instance.localNodeHexId.replaceAll('!', ''), radix: 16);
      }

      // Enforce Channel 1 and Secondary Role (just in case the QR code was formatted weirdly)
      squadChannel.index = 1;
      squadChannel.role = Channel_Role.SECONDARY;

      // 2. Properly package the SetChannel command into an AdminMessage
      AdminMessage adminMsg = AdminMessage()..setChannel = squadChannel;
      Data adminData = Data()
        ..portnum = PortNum.ADMIN_APP
        ..payload = adminMsg.writeToBuffer();
        
      MeshPacket adminPacket = MeshPacket()
        ..to = localNodeNum
        ..from = localNodeNum 
        ..id = Random().nextInt(0x7FFFFFFF)
        ..channel = 0 
        ..decoded = adminData
        ..wantAck = true;

      ToRadio channelReq = ToRadio()..packet = adminPacket;

      print("📤 BURNING SECURE KEY TO LOCAL FLASH MEMORY...");
      await _toRadioChar!.write(channelReq.writeToBuffer(), withoutResponse: false);
      
      // Give the hardware a moment to process the byte stream
      await Future.delayed(const Duration(milliseconds: 1000));

      // 3. Properly package the Commit command into an AdminMessage
      AdminMessage commitMsg = AdminMessage()..commitEditSettings = true;
      Data commitData = Data()
        ..portnum = PortNum.ADMIN_APP
        ..payload = commitMsg.writeToBuffer();
        
      MeshPacket commitPacket = MeshPacket()
        ..to = localNodeNum
        ..from = localNodeNum 
        ..id = Random().nextInt(0x7FFFFFFF)
        ..channel = 0 
        ..decoded = commitData
        ..wantAck = true;

      ToRadio commitReq = ToRadio()..packet = commitPacket;

      print("📤 COMMITTING SETTINGS & REBOOTING RADIO...");
      await _toRadioChar!.write(commitReq.writeToBuffer(), withoutResponse: false);

      // 4. Update UI State
      currentSquad.value = channelName;
      print("🟢 SQUAD SECURE LINK INSTALLED SUCCESSFULLY!");
      
    } catch (e) {
      print("🔴 SQUAD SETUP ERROR: $e");
    }
  }
}