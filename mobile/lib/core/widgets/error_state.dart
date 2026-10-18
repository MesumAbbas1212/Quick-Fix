import 'package:flutter/material.dart';
import 'package:quickfix/core/theme/app_theme.dart';

/// Centred error state for failed loads: icon, a short title, a human
/// message (never a raw exception string) and an optional Retry action.
class ErrorState extends StatelessWidget {
  final String message;

  /// When provided, a Retry button is rendered and invokes it.
  final VoidCallback? onRetry;

  const ErrorState({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off,
                size: 48,
                color: AppTheme.textMuted,
              ),
              const SizedBox(height: 14),
              const Text(
                'Something went wrong',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
              ),
              if (onRetry != null) ...[
                const SizedBox(height: 14),
                OutlinedButton(
                  key: const Key('error-retry-button'),
                  onPressed: onRetry,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.brandBlue,
                    side: const BorderSide(color: AppTheme.brandBlue, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Retry',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
