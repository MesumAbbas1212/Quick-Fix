import 'package:flutter/material.dart';
import 'package:quickfix/core/theme/app_theme.dart';

/// Section header used across list/detail screens: a 13 w700 title with an
/// optional trailing widget (usually a "See all" text button) and an
/// optional divider below the row.
class SectionHeader extends StatelessWidget {
  final String title;

  /// Optional trailing action, e.g. a "See all" [TextButton].
  final Widget? trailing;

  /// Draws a 1 px divider under the row.
  final bool showDivider;

  const SectionHeader({
    super.key,
    required this.title,
    this.trailing,
    this.showDivider = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textDark,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 6),
              trailing!,
            ],
          ],
        ),
        if (showDivider) ...[
          const SizedBox(height: 8),
          const Divider(height: 1, color: AppTheme.borderGray),
        ],
      ],
    );
  }
}
