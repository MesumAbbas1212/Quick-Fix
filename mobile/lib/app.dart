import 'package:flutter/material.dart';
import 'package:quickfix/core/theme/app_theme.dart';
import 'package:quickfix/views/auth/splash_screen.dart';

class QuickFixApp extends StatelessWidget {
  const QuickFixApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QuickFix',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      // SplashScreen resolves the auth state: signed-in users go straight to
      // their shell, everyone else lands on the login screen.
      home: const SplashScreen(),
    );
  }
}