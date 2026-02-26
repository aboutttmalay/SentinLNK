import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/storage/storage_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/chat_message.dart';
import '../../../data/models/node_database.dart'; 
import '../../../core/services/hardware_bridge.dart'; 

class ActiveChatScreen extends StatefulWidget {
  final VoidCallback onBack;
  final String chatName;

  const ActiveChatScreen({
    super.key,
    required this.onBack,
    this.chatName = "ALPHA SQUAD",
  });

  @override
  _ActiveChatScreenState createState() => _ActiveChatScreenState();
}

class _ActiveChatScreenState extends State<ActiveChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    
    // 👉 REMOVED: connectAndSync() call here.
    // It is no longer needed here because connection is now strictly handled
    // by the ScanScreen when a user explicitly selects a device. 
    
    // Listen for background messages
    NodeDatabase.instance.latestIncomingMessage.addListener(_onNewRadioMessage);
  }

  @override
  void dispose() {
    NodeDatabase.instance.latestIncomingMessage.removeListener(_onNewRadioMessage);
    super.dispose();
  }

  Future<void> _loadMessages() async {
    // 👉 FIX: Check mode and load ONLY that specific history
    bool isSquadMode = HardwareBridge.instance.currentSquad.value != "Global Mesh";
    final messages = StorageService.getHistory(isSquad: isSquadMode);
    
    setState(() {
      _messages.addAll(messages);
      _isLoading = false;
    });
    _scrollToBottom();
  }

  // ==========================================
  // 📥 HANDLE INCOMING MESSAGES (MULTI-CHANNEL)
  // ==========================================
  void _onNewRadioMessage() {
    final rawMsg = NodeDatabase.instance.latestIncomingMessage.value;
    if (rawMsg != null) {
      final parts = rawMsg.split('|');
      
      // Expected Format: "SQUAD|Hello|16281923" or "GLOBAL|Hello|16281923"
      if (parts.length >= 3) {
        String msgType = parts[0];
        String msgText = parts[1];

        // CHECK: Are we currently in Squad Mode?
        bool isSquadMode = HardwareBridge.instance.currentSquad.value != "Global Mesh";

        // FILTER: 
        // Only show SQUAD messages if we are in Squad mode.
        // Only show GLOBAL messages if we are in Global mode.
        if ((isSquadMode && msgType == "SQUAD") || (!isSquadMode && msgType == "GLOBAL")) {
           setState(() {
             _messages.add(ChatMessage(text: msgText, isMe: false, timestamp: "Now"));
           });
           _scrollToBottom();
        }
      }
    }
  }

  // ==========================================
  // 📤 SEND MESSAGE (MULTI-CHANNEL)
  // ==========================================
  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    final timestamp = "${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}";
    bool isSquadMode = HardwareBridge.instance.currentSquad.value != "Global Mesh";
    
    // 👉 FIX: Save to the correct database box
    await StorageService.saveMessage(text.trim(), true, timestamp, isSquad: isSquadMode);

    setState(() {
      _messages.add(ChatMessage(text: text.trim(), isMe: true, timestamp: timestamp));
      _messageController.clear();
    });
    _scrollToBottom();

    await HardwareBridge.instance.sendTacticalMessage(text.trim(), isSquad: isSquadMode);
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.chatName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white, letterSpacing: 1),
            ),
            Text(
              HardwareBridge.instance.isConnected ? "🟢 SECURE LORA LINK ACTIVE" : "🔴 OFFLINE",
              style: TextStyle(
                color: HardwareBridge.instance.isConnected ? AppColors.primary : Colors.orangeAccent, 
                fontSize: 10, 
                letterSpacing: 1.5
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      final isMe = msg.isMe;
                      return Align(
                        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.75,
                          ),
                          decoration: BoxDecoration(
                            color: isMe ? AppColors.primary.withValues(alpha: 0.1) : AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isMe ? AppColors.primary.withValues(alpha: 0.3) : AppColors.border,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                msg.text,
                                style: const TextStyle(color: Colors.white, fontSize: 14),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    LucideIcons.lock,
                                    size: 10,
                                    color: AppColors.primary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    msg.timestamp,
                                    style: const TextStyle(color: AppColors.textDim, fontSize: 10),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: "Transmit encrypted message...",
                      hintStyle: const TextStyle(color: AppColors.textDim),
                      filled: true,
                      fillColor: AppColors.bg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onSubmitted: (val) => _sendMessage(val),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(LucideIcons.send, color: Colors.white, size: 20),
                    onPressed: () => _sendMessage(_messageController.text),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}