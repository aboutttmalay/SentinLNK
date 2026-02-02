import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/theme/app_colors.dart';

class ChatTile extends StatelessWidget {
  final String name;
  final String message;
  final String time;
  final bool isUnread;
  final bool isConnected;
  final VoidCallback onTap;

  const ChatTile({
    super.key,
    required this.name,
    required this.message,
    required this.time,
    required this.isUnread,
    required this.isConnected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Ghost mode if disconnected
    final double opacity = isConnected ? 1.0 : 0.4;
    final bool showUnread = isUnread && isConnected;

    return GestureDetector(
      onTap: isConnected ? onTap : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: showUnread ? Colors.white.withOpacity(0.05) : Colors.transparent,
          border: Border.all(
            color: showUnread ? AppColors.primary.withOpacity(0.5) : AppColors.border,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Opacity(
          opacity: opacity,
          child: Row(
            children: [
              // Avatar
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: showUnread ? AppColors.primary : AppColors.surface,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  name[0],
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: showUnread ? Colors.white : Colors.white54,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              
              // Text Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text(time, style: const TextStyle(fontSize: 10, color: AppColors.textDim)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isConnected ? message : "Connection required...",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: AppColors.textDim),
                    ),
                  ],
                ),
              ),
              
              // Status Icon
              const SizedBox(width: 12),
              Icon(
                isConnected ? LucideIcons.chevronRight : LucideIcons.lock,
                size: 16,
                color: AppColors.textDim,
              ),
            ],
          ),
        ),
      ),
    );
  }
}