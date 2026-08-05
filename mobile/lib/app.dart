import 'package:flutter/material.dart';
import 'package:quickfix/core/theme/app_theme.dart';

class QuickFixApp extends StatelessWidget {
  const QuickFixApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QuickFix',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const _AppRoot(),
    );
  }
}

class _AppRoot extends StatelessWidget {
  const _AppRoot();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.build_circle,
              size: 80,
              color: AppTheme.ctaOrange,
            ),
            const SizedBox(height: 16),
            Text(
              'QuickFix',
              style: Theme.of(context).textTheme.displayMedium?.copyWith(
                color: AppTheme.brandBlue,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'On-Demand Local Services',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppTheme.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}