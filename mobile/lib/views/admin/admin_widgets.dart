import 'package:flutter/material.dart';
import 'package:quickfix/core/theme/app_theme.dart';
import 'package:quickfix/core/widgets/empty_state.dart';
import 'package:quickfix/core/widgets/error_state.dart';
import 'package:quickfix/core/widgets/loading_list.dart';

class AdminCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const AdminCard({super.key, required this.child, this.padding = const EdgeInsets.all(14)});
  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: AppTheme.surfaceWhite,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppTheme.borderGray),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
    ),
    child: child,
  );
}

class AdminLoading extends StatelessWidget {
  final int rows;
  const AdminLoading({super.key, this.rows = 4});
  @override
  Widget build(BuildContext context) => LoadingList(rows: rows);
}

class AdminEmpty extends StatelessWidget {
  final String title;
  final String message;
  const AdminEmpty({super.key, required this.title, required this.message});
  @override
  Widget build(BuildContext context) => EmptyState(icon: Icons.inbox_outlined, title: title, message: message);
}

class AdminError extends StatelessWidget {
  final VoidCallback onRetry;
  const AdminError({super.key, required this.onRetry});
  @override
  Widget build(BuildContext context) => ErrorState(message: 'Could not load admin data. Check your connection and retry.', onRetry: onRetry);
}

class AdminModeBadge extends StatelessWidget {
  const AdminModeBadge({super.key});
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5), decoration: BoxDecoration(color: AppTheme.brandBlue.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(20)), child: const Text('ADMIN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.brandBlue)));
}

class AdminSectionTitle extends StatelessWidget {
  final String text;
  const AdminSectionTitle(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textDark));
}

Color adminStatusColor(String status) => switch (status.toLowerCase()) {
  'open' || 'pending' => AppTheme.accentYellow,
  'resolved' || 'verified' || 'approved' => AppTheme.successGreen,
  'dismissed' || 'blocked' || 'rejected' => AppTheme.textMuted,
  'cancelled' => AppTheme.dangerRed,
  _ => AppTheme.brandBlue,
};
