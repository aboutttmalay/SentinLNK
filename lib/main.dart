import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/theme/app_colors.dart';
import 'core/storage/storage_service.dart';
import 'presentation/controllers/storyboard_controller.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Database
  await StorageService.init();

  // 1. Transparent Status Bar for "Edge-to-Edge" look
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  
  runApp(const SentinLNKApp());
}

class SentinLNKApp extends StatelessWidget {
  const SentinLNKApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SentinLNK',
      
      // 2. Global Theme Setup
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: AppColors.bg,
        primaryColor: AppColors.primary,
        // Apply Roboto Mono to all standard text
        textTheme: GoogleFonts.robotoMonoTextTheme(ThemeData.dark().textTheme).apply(
          bodyColor: AppColors.text,
          displayColor: AppColors.text,
        ),
      ),
      
      // 3. Start with Splash
      home: const StoryboardController(),
    );
  }
}