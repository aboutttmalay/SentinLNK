import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/storage/storage_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/chat_message.dart';
import '../../../data/models/node_database.dart'; 
import '../../../core/services/hardware_bridge.dart'; 
import 'package:shared_preferences/shared_preferences.dart';

class ActiveChatScreen extends StatefulWidget {
  // 👉 THE FIX: This is the global tracker that home_screen looks for!
  static String? currentOpenChat; 

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
  List<String> _quickCommands = [];

  @override
  void initState() {
    super.initState();
    _loadQuickCommands();
    // 👉 Tell the app exactly which chat is open right now
    ActiveChatScreen.currentOpenChat = widget.chatName; 
    
    _loadMessages();
    NodeDatabase.instance.latestIncomingMessage.addListener(_onNewRadioMessage);
  }

  @override
  void dispose() {
    // 👉 Clear the tracker when the user closes the chat screen
    ActiveChatScreen.currentOpenChat = null; 
    
    NodeDatabase.instance.latestIncomingMessage.removeListener(_onNewRadioMessage);
    super.dispose();
  }

  Future<void> _loadQuickCommands() async {
    final prefs = await SharedPreferences.getInstance();
    List<String>? saved = prefs.getStringList('tactical_commands');
    if (saved == null || saved.isEmpty) {
      saved = ["CONTACT FRONT", "MEDIC REQUIRED", "RALLY AT WAYPOINT", "BINGO AMMO"];
    }
    setState(() {
      _quickCommands = saved!;
    });
  }

  Future<void> _loadMessages() async {
    bool isSquadMode = widget.chatName != "Global Mesh";
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
      
      if (parts.length >= 4) {
        String msgType = parts[0];
        String senderName = parts[1];
        String msgText = parts[2];

        bool isSquadMode = HardwareBridge.instance.currentSquad.value != "Global Mesh";

        if ((isSquadMode && msgType == "SQUAD") || (!isSquadMode && msgType == "GLOBAL")) {
           setState(() {
             _messages.add(ChatMessage(text: msgText, isMe: false, timestamp: "Now", senderName: senderName));
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

  // ==========================================
  // ⚡ QUICK-TAP HORIZONTAL BAR
  // ==========================================
  Widget _buildQuickTapBar() {
    if (_quickCommands.isEmpty) return const SizedBox.shrink();
    
    return Container(
      height: 45,
      margin: const EdgeInsets.only(bottom: 8, top: 4),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _quickCommands.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent.withValues(alpha: 0.15),
                side: const BorderSide(color: Colors.redAccent, width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              onPressed: () {
                // Instantly send the hardware command using the main _sendMessage router!
                _sendMessage(_quickCommands[index]);
              },
              child: Text(
                _quickCommands[index], 
                style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, letterSpacing: 1)
              ),
            ),
          );
        },
      ),
    );
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
              HardwareBridge.instance.isConnected ? "🟢 SECURE LORA LINK ACTIVE" : "🟠 OFFLINE",
              style: TextStyle(
                color: HardwareBridge.instance.isConnected ? AppColors.primary : Colors.orangeAccent, 
                fontSize: 10, 
                letterSpacing: 1.5
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.trash2, color: Colors.redAccent, size: 20),
            tooltip: "Clear Chat History",
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: AppColors.bg,
                  title: const Row(
                    children: [
                      Icon(LucideIcons.alertTriangle, color: Colors.red),
                      SizedBox(width: 10),
                      Text("WIPE DATA?", style: TextStyle(color: Colors.white)),
                    ],
                  ),
                  content: const Text("This will permanently delete all saved messages. This action cannot be undone.", style: TextStyle(color: AppColors.textDim)),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context), 
                      child: const Text("CANCEL", style: TextStyle(color: Colors.grey))
                    ),
                    TextButton(
                      onPressed: () async {
                        await StorageService.clearLogs();
                        setState(() {
                          _messages.clear();
                        });
                        Navigator.pop(context);
                      }, 
                      child: const Text("CONFIRM WIPE", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))
                    ),
                  ],
                ),
              );
            },
          ),
        ],
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
                              if (!isMe)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Text(
                                    msg.senderName ?? "Unknown Node",
                                    style: TextStyle(color: AppColors.primary.withValues(alpha: 0.8), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                                  ),
                                ),
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
          
          // 👉 NEW: Tactical Quick-Tap Bar inserted right above the chat box!
          _buildQuickTapBar(),
          
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