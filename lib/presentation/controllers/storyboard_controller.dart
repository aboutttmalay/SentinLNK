import 'dart:async';
import 'package:flutter/material.dart';
import '../screens/splash_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/scanning/scan_screen.dart';
import '../screens/chat/active_chat_screen.dart';

enum AppState { splash, disconnected, scanning, connected, chat }

class StoryboardController extends StatefulWidget {
  const StoryboardController({super.key});

  @override
  State<StoryboardController> createState() => _StoryboardControllerState();
}

class _StoryboardControllerState extends State<StoryboardController> {
  AppState _currentState = AppState.splash;

  @override
  void initState() {
    super.initState();
    // 1. Splash Timer
    Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _currentState = AppState.disconnected);
    });
  }

  // Navigation Actions
  void _startScan() => setState(() => _currentState = AppState.scanning);
  void _finishConnection() => setState(() => _currentState = AppState.connected);
  void _openChat() => setState(() => _currentState = AppState.chat);
  void _goBackToDashboard() => setState(() => _currentState = AppState.connected);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // This is crucial: It prevents the keyboard from pushing the UI up weirdly
      resizeToAvoidBottomInset: true, 
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 600),
        switchInCurve: Curves.easeOutExpo,
        switchOutCurve: Curves.easeInExpo,
        child: _buildPanel(),
      ),
    );
  }

  Widget _buildPanel() {
    switch (_currentState) {
      case AppState.splash:
        return const SplashScreen();
        
      case AppState.disconnected:
        return HomeScreen(
          isConnected: false, 
          onAction: _startScan
        );
        
      case AppState.scanning:
        return ScanScreen(
          onConnect: _finishConnection
        );
        
      case AppState.connected:
        return HomeScreen(
          isConnected: true, 
          onAction: _openChat
        );
        
      case AppState.chat:
        return ActiveChatScreen(
          onBack: _goBackToDashboard
        );
    }
  }
}