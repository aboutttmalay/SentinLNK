import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart'; // Add "intl: ^0.19.0" to pubspec.yaml if needed
import '../../../core/theme/app_colors.dart';
import '../../../core/storage/storage_service.dart';
import '../../../data/models/chat_message.dart';
import '../../../core/security/security_manager.dart'; 

class ActiveChatScreen extends StatefulWidget {
  final VoidCallback onBack;
  const ActiveChatScreen({super.key, required this.onBack});

  @override
  State<ActiveChatScreen> createState() => _ActiveChatScreenState();
}

class _ActiveChatScreenState extends State<ActiveChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  // We start with an empty list, and load from DB
  List<ChatMessage> _messages = [];

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  void _loadMessages() {
    // Load history from Hive
    setState(() {
      _messages = StorageService.getHistory();
    });
    // Scroll to bottom after loading
    Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
  }

  void _sendMessage() {
    String rawText = _textController.text.trim();
    if (rawText.isEmpty) return;

    // --- STEP 1: MILITARY ENCRYPTION (AES-256) ---
    // We encrypt the data to simulate secure transmission.
    var encryptedBytes = SecurityManager.encryptMessage(rawText);
    
    // We print the "Secret Code" to the Console so you can show the Judges.
    String debugBase64 = base64Encode(encryptedBytes);
    print("------------------------------------------------");
    print("TACTICAL LOG // SECURE TRANSMISSION:");
    print("Plaintext: $rawText");
    print("AES-256 Ciphertext: $debugBase64"); 
    print("------------------------------------------------");

    // --- STEP 2: DECRYPTION & STORAGE ---
    // In a real scenario, the *receiver* does this. 
    // Ideally, you store the DECRYPTED text for your own history log.
    
    // Decrypt back to text (Simulating reception)
    String decryptedText = SecurityManager.decryptMessage(encryptedBytes);
    String timeNow = DateFormat.Hm().format(DateTime.now());

    // Save to Offline Database (Hive)
    StorageService.saveMessage(decryptedText, true, timeNow);

    // --- STEP 3: UPDATE UI ---
    setState(() {
      _messages.add(ChatMessage(
        text: decryptedText, 
        isMe: true, 
        timestamp: timeNow
      ));
    });
    
    _textController.clear();
    
    // Auto-scroll
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

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            // 1. Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(LucideIcons.chevronLeft, color: Colors.white70),
                    onPressed: widget.onBack,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 16),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Alpha Squad", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      Text("ENCRYPTED MESH LOG", style: TextStyle(color: AppColors.accent, fontSize: 10)),
                    ],
                  )
                ],
              ),
            ),

            // 2. Messages List (Updated for Hive Object)
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final msg = _messages[index];
                  
                  return Align(
                    alignment: msg.isMe ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      constraints: const BoxConstraints(maxWidth: 260),
                      decoration: BoxDecoration(
                        color: msg.isMe ? AppColors.primary : AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(msg.text, style: const TextStyle(fontSize: 14)),
                          const SizedBox(height: 4),
                          Text(msg.timestamp, style: const TextStyle(fontSize: 9, color: Colors.white38)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // 4. Input Area
            Container(
              padding: const EdgeInsets.all(16),
              color: AppColors.surface,
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 45,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: AppColors.bg,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: TextField(
                        controller: _textController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: "Encrypted message...",
                          hintStyle: TextStyle(color: AppColors.textDim, fontSize: 12),
                          border: InputBorder.none,
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: _sendMessage,
                    child: Container(
                      width: 45, height: 45,
                      decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.primary),
                      child: const Icon(LucideIcons.send, size: 20, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}