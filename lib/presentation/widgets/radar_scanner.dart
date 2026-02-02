import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class RadarScanner extends StatefulWidget {
  final bool isScanning;
  const RadarScanner({super.key, required this.isScanning});

  @override
  State<RadarScanner> createState() => _RadarScannerState();
}

class _RadarScannerState extends State<RadarScanner> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 4))
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isScanning) {
      _controller.stop();
      return Container(
        width: 200, height: 200,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.border.withOpacity(0.5)),
        ),
        child: const Center(
          child: Icon(Icons.radar, size: 50, color: AppColors.textDim),
        ),
      );
    }

    _controller.repeat();

    return SizedBox(
      width: 200,
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Static Rings
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primary.withOpacity(0.3)),
            ),
          ),
          FractionallySizedBox(
            widthFactor: 0.6,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.primary.withOpacity(0.3)),
              ),
            ),
          ),
          
          // Rotating Sweep
          RotationTransition(
            turns: _controller,
            child: Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: SweepGradient(
                  center: Alignment.center,
                  colors: [Colors.transparent, AppColors.primary],
                  stops: [0.75, 1.0],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}