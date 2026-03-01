import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'core/theme/app_colors.dart';
import 'core/storage/storage_service.dart';
import 'presentation/controllers/storyboard_controller.dart';
// import 'data/models/node_database.dart'; 

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Database
  await StorageService.init();

  // Transparent Status Bar for "Edge-to-Edge" look
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  
  runApp(const SentinLNKApp());
}

class SentinLNKApp extends StatefulWidget {
  const SentinLNKApp({super.key});

  @override
  State<SentinLNKApp> createState() => _SentinLNKAppState();
}

class _SentinLNKAppState extends State<SentinLNKApp> {
  
  @override
  void initState() {
    super.initState();
    // 🛑 The old global SnackBar listener has been permanently deleted from here!
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SentinLNK',
      
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: AppColors.bg,
        primaryColor: AppColors.primary,
        textTheme: GoogleFonts.robotoMonoTextTheme(ThemeData.dark().textTheme).apply(
          bodyColor: AppColors.text,
          displayColor: AppColors.text,
        ),
      ),
      
      home: const StoryboardController(),
    );
  }
}