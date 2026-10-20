import 'package:flutter/material.dart';
import 'package:quickfix/core/theme/app_theme.dart';

/// Centred empty state: 48 px muted icon, a 13 w600 title, a 12 px
/// explanation, and an optional call-to-action. Every empty list must use
/// this instead of a bare "No data" line — the message should name the
/// reason and the next action.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  /// Optional CTA (e.g. "Post your first job").
  final Widget? action;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    // Scrollable so a tall empty state (a long message at a large
    // accessibility text scale) never overflows a tight viewport;
    // when space is ample the content simply centres as before.
    return SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 48, color: AppTheme.textMuted),
                const SizedBox(height: 14),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textMuted,
                  ),
                ),
                if (action != null) ...[
                  const SizedBox(height: 14),
                  action!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
