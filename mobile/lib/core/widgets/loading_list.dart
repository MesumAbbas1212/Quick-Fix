import 'package:flutter/material.dart';
import 'package:quickfix/core/theme/app_theme.dart';

/// Skeleton rows for lists that are still loading: card-shaped placeholders
/// matching the app's card style. Replaces the old "spinner in the middle of
/// a blank page" so a loading list reads as content appearing.
class LoadingList extends StatelessWidget {
  /// Number of skeleton rows to render.
  final int rows;

  const LoadingList({super.key, this.rows = 4});

  @override
  Widget build(BuildContext context) {
    // Scrollable so a tall skeleton never overflows a tight
    // viewport at a large accessibility text scale; when space
    // is ample the rows simply stack as before.
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: List.generate(
            rows,
            (i) => Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.surfaceWhite,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
                border: Border.all(color: AppTheme.borderGray),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: AppTheme.borderGray,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(height: 12, color: AppTheme.borderGray),
                        const SizedBox(height: 8),
                        Container(
                          height: 10,
                          color: AppTheme.borderGray,
                          width: MediaQuery.sizeOf(context).width * 0.4,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
