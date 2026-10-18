import 'package:flutter/material.dart';
import 'package:quickfix/core/theme/app_theme.dart';

/// Standard QuickFix surface (spec §3.4), shared by the new detail screens.
class AppCard extends StatelessWidget {
  final Widget child;
  final double padding;

  const AppCard({super.key, required this.child, this.padding = 14});

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.all(padding),
        decoration: BoxDecoration(
          color: AppTheme.surfaceWhite,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.borderGray),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: child,
      );
}
