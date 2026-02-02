import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart'; // Add "intl: ^0.19.0" to pubspec.yaml if needed
import '../../../core/theme/app_colors.dart';

class ActiveChatScreen extends StatefulWidget {
  final VoidCallback onBack;
  const ActiveChatScreen({super.key, required this.onBack});

  @override
  State<ActiveChatScreen> createState() => _ActiveChatScreenState();
}

class _ActiveChatScreenState extends State<ActiveChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  // Mock Messages Data
  final List<Map<String, dynamic>> _messages = [
    {"text": "Sector 4 clear. Moving to extraction point.", "isMe": false, "time": DateFormat.Hm().format(DateTime.now())},
    {"text": "Copy. Holding position at WP-Charlie.", "isMe": true, "time": DateFormat.Hm().format(DateTime.now())},
  ];

  void _sendMessage() {
    if (_textController.text.trim().isEmpty) return;
    
    setState(() {
      _messages.add({
        "text": _textController.text,
        "isMe": true,
        "time": DateFormat.Hm().format(DateTime.now()), // Dynamic time using intl package
      });
    });
    _textController.clear();
    
    // Auto-scroll to bottom
    Future.delayed(const Duration(milliseconds: 100), () {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
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
                      Row(
                        children: [
                          Icon(LucideIcons.lock, size: 10, color: AppColors.accent),
                          SizedBox(width: 4),
                          Text("ENCRYPTED MESH LINK", style: TextStyle(color: AppColors.accent, fontSize: 10)),
                        ],
                      ),
                    ],
                  )
                ],
              ),
            ),

            // 2. Messages List
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final msg = _messages[index];
                  final isMe = msg['isMe'] as bool;
                  
                  return Align(
                    alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      constraints: const BoxConstraints(maxWidth: 260),
                      decoration: BoxDecoration(
                        color: isMe ? AppColors.primary : AppColors.surface,
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(12),
                          topRight: const Radius.circular(12),
                          bottomLeft: Radius.circular(isMe ? 12 : 0),
                          bottomRight: Radius.circular(isMe ? 0 : 12),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!isMe) 
                            const Text("[Encrypted]", style: TextStyle(color: AppColors.accent, fontSize: 9, fontFamily: 'Roboto Mono')),
                          Text(msg['text'], style: const TextStyle(fontSize: 14)),
                          const SizedBox(height: 4),
                          Text(msg['time'], style: const TextStyle(fontSize: 9, color: Colors.white38)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // 3. Input Area
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