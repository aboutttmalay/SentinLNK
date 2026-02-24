import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/storage/storage_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/chat_message.dart';
import '../../../data/models/node_database.dart'; 
import '../../../core/services/hardware_bridge.dart'; // 👉 NEW: Global Engine


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
    
    // 👉 1. CONNECT HARDWARE (If it isn't already)
    // This allows the user to open Chat before Nodes and still connect
    HardwareBridge.instance.connectAndSync(); 
    
    // 👉 2. LISTEN FOR BACKGROUND MESSAGES
    // The Global Engine will update this notifier when a new text arrives
    NodeDatabase.instance.latestIncomingMessage.addListener(_onNewRadioMessage);
  }

  @override
  void dispose() {
    NodeDatabase.instance.latestIncomingMessage.removeListener(_onNewRadioMessage);
    super.dispose();
  }

  Future<void> _loadMessages() async {
    final messages = StorageService.getHistory();
    setState(() {
      _messages.addAll(messages);
      _isLoading = false;
    });
    _scrollToBottom();
  }

  // ==========================================
  // 📥 HANDLE INCOMING MESSAGES
  // ==========================================
  void _onNewRadioMessage() {
    final payload = NodeDatabase.instance.latestIncomingMessage.value;
    if (payload != null && payload.isNotEmpty) {
      
      // 👉 Clean the hidden timestamp off the message
      final text = payload.split('|')[0]; 
      final timestamp = "${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}";
      
      if (mounted) {
        setState(() {
          _messages.add(ChatMessage(text: text, isMe: false, timestamp: timestamp));
        });
        _scrollToBottom();
      }
      
      // Note: HardwareBridge already saved this to StorageService in the background!
    }
  }
  // ==========================================
  // 📤 SEND MESSAGE (Via Global Engine)
  // ==========================================
  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    final timestamp = "${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}";
    
    // 1. Save to Local Memory
    await StorageService.saveMessage(text.trim(), true, timestamp);

    // 2. Update UI
    setState(() {
      _messages.add(ChatMessage(text: text.trim(), isMe: true, timestamp: timestamp));
      _messageController.clear();
    });
    _scrollToBottom();

    // 👉 3. FIRE THE MESSAGE VIA GLOBAL ENGINE
    await HardwareBridge.instance.sendTacticalMessage(text.trim());
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
              // Ask the Global Engine if we are online!
              HardwareBridge.instance.isConnected ? "🟢 SECURE LORA LINK ACTIVE" : "🔴 SCANNING FREQUENCIES...",
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