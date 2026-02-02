import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_colors.dart';
import '../../widgets/radar_scanner.dart';
import '../../widgets/tactical_button.dart';

class ScanScreen extends StatefulWidget {
  final VoidCallback onConnect;
  const ScanScreen({super.key, required this.onConnect});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  bool _deviceFound = false;

  @override
  void initState() {
    super.initState();
    // Simulate finding a device after 2.5 seconds
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) setState(() => _deviceFound = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 1. Radar Visual
            Stack(
              alignment: Alignment.center,
              children: [
                RadarScanner(isScanning: true),
                // The "Blip" (Only appears when found)
                if (_deviceFound)
                  Positioned(
                    top: 60,
                    right: 60,
                    child: Container(
                      width: 12, height: 12,
                      decoration: const BoxDecoration(
                        color: AppColors.accent,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: AppColors.accent, blurRadius: 10)],
                      ),
                    ),
                  ),
              ],
            ),
            
            const SizedBox(height: 40),

            // 2. Status Text
            Text(
              _deviceFound ? "DEVICE DETECTED" : "SCANNING FREQUENCIES...",
              style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2),
            ),
            const SizedBox(height: 8),
            Text(
              _deviceFound ? "RAK-4631 // Signal: -42 dBm" : "Ensure LoRa hardware is powered on",
              style: const TextStyle(color: AppColors.textDim, fontSize: 10),
            ),

            const SizedBox(height: 40),

            // 3. Connect Button
            AnimatedOpacity(
              opacity: _deviceFound ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 500),
              child: TacticalButton(
                label: "ESTABLISH LINK",
                icon: LucideIcons.link,
                variant: TacticalButtonVariant.success,
                onTap: widget.onConnect,
              ),
            ),
          ],
        ),
      ),
    );
  }
}