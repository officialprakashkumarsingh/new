import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'auth_and_profile_pages.dart';
import 'auth_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize the AuthService singleton so it's available everywhere
  AuthService(); 
  
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    systemNavigationBarColor: Color(0xFFF7F7F7),
    statusBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.dark,
    statusBarIconBrightness: Brightness.dark,
  ));
  runApp(const AhamAIApp());
}

class AhamAIApp extends StatelessWidget {
  const AhamAIApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AhamAI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.grey,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF7F7F7),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF7F7F7),
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        fontFamily: 'Inter',
      ),
      // AuthGate will decide which page to show
      home: const AuthGate(),
    );
  }
}