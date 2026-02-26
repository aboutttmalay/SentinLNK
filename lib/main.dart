import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'core/theme/app_colors.dart';
import 'core/storage/storage_service.dart';
import 'presentation/controllers/storyboard_controller.dart';
import 'data/models/node_database.dart'; // 👉 NEW: Import NodeDatabase

// 👉 1. Create a Global Key for the Scaffold Messenger
final GlobalKey<ScaffoldMessengerState> globalMessengerKey = GlobalKey<ScaffoldMessengerState>();

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

// 👉 2. Change to StatefulWidget to use initState
class SentinLNKApp extends StatefulWidget {
  const SentinLNKApp({super.key});

  @override
  State<SentinLNKApp> createState() => _SentinLNKAppState();
}

class _SentinLNKAppState extends State<SentinLNKApp> {
  
  @override
  void initState() {
    super.initState();
    // 👉 3. Start listening for incoming messages globally
    NodeDatabase.instance.latestIncomingMessage.addListener(_showGlobalNotification);
  }

  @override
  void dispose() {
    NodeDatabase.instance.latestIncomingMessage.removeListener(_showGlobalNotification);
    super.dispose();
  }

  // 👉 4. The Global Pop-up Logic
  void _showGlobalNotification() {
    final rawMsg = NodeDatabase.instance.latestIncomingMessage.value;
    if (rawMsg != null) {
       final parts = rawMsg.split('|');
       // Expected: "SQUAD|Message Text|Timestamp"
       if (parts.length >= 2) {
         String type = parts[0]; 
         String text = parts[1];
         
         // Use the Global Key to show the SnackBar from anywhere!
         globalMessengerKey.currentState?.showSnackBar(
           SnackBar(
             content: Row(
               children: [
                 const Icon(Icons.satellite_alt, color: Colors.white, size: 20),
                 const SizedBox(width: 12),
                 Expanded(
                   child: Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     mainAxisSize: MainAxisSize.min,
                     children: [
                       Text(
                         "INCOMING $type TRANSMISSION", 
                         style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 1, color: Colors.white70),
                       ),
                       Text(
                         text,
                         style: const TextStyle(color: Colors.white, fontSize: 14),
                         maxLines: 1,
                         overflow: TextOverflow.ellipsis,
                       ),
                     ],
                   ),
                 ),
               ],
             ),
             backgroundColor: type == "SQUAD" ? Colors.green[800] : AppColors.primary,
             behavior: SnackBarBehavior.floating, // Makes it float above the bottom navigation bar
             margin: const EdgeInsets.all(16),
             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
             duration: const Duration(seconds: 4),
           )
         );
       }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SentinLNK',
      
      // 👉 5. Attach the Global Key to the MaterialApp
      scaffoldMessengerKey: globalMessengerKey,
      
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