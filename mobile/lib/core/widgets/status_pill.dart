import 'package:flutter/material.dart';
import 'package:quickfix/core/theme/app_theme.dart';

class StatusPill extends StatelessWidget {
  final String label;
  final Color color;
  const StatusPill({super.key, required this.label, this.color = AppTheme.brandBlue});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(20)),
    child: Text(label, style: TextStyle(color: color, fontSize: 11,
      fontWeight: FontWeight.w600)),
  );
}
