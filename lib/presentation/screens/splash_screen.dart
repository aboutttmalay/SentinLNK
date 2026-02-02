import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../widgets/pulse_animation.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 1. The Pulsing Logo
            PulseAnimation(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primaryDim, width: 2),
                ),
                child: const Icon(LucideIcons.shield, size: 60, color: AppColors.primary),
              ),
            ),
            
            const SizedBox(height: 40),
            
            // 2. The Title
            RichText(
              text: TextSpan(
                style: GoogleFonts.robotoMono(
                  fontSize: 28, 
                  fontWeight: FontWeight.bold, 
                  letterSpacing: 4,
                ),
                children: const [
                  TextSpan(text: "SENTIN", style: TextStyle(color: AppColors.text)),
                  TextSpan(text: "LNK", style: TextStyle(color: AppColors.primary)),
                ],
              ),
            ),
            
            const SizedBox(height: 12),
            
            // 3. Subtitle
            Text(
              "TACTICAL MESH SYSTEMS",
              style: GoogleFonts.inter(
                color: AppColors.textDim, 
                fontSize: 10, 
                letterSpacing: 2,
                fontWeight: FontWeight.w600
              ),
            ),
          ],
        ),
      ),
    );
  }
}