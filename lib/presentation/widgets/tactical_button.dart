import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import 'package:google_fonts/google_fonts.dart';

enum TacticalButtonVariant { primary, danger, success }

class TacticalButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onTap;
  final TacticalButtonVariant variant;

  const TacticalButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.variant = TacticalButtonVariant.primary,
  });

  @override
  Widget build(BuildContext context) {
    // Determine colors based on variant
    Color bgColor;
    Color textColor = Colors.white;

    switch (variant) {
      case TacticalButtonVariant.primary:
        bgColor = AppColors.primary;
        break;
      case TacticalButtonVariant.danger:
        bgColor = AppColors.alert;
        break;
      case TacticalButtonVariant.success:
        bgColor = AppColors.accent;
        break;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, color: textColor, size: 20),
                const SizedBox(width: 12),
              ],
              Text(
                label.toUpperCase(),
                style: GoogleFonts.inter(
                  color: textColor,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}