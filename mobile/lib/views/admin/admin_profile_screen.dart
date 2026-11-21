import 'package:flutter/material.dart';
import 'package:quickfix/core/theme/app_theme.dart';
import 'package:quickfix/core/widgets/user_avatar.dart';
import 'package:quickfix/models/user_model.dart';
import 'package:quickfix/services/auth_service.dart';
import 'package:quickfix/views/admin/admin_widgets.dart';
import 'package:quickfix/views/auth/login_screen.dart';
import 'package:quickfix/views/client/client_shell.dart';

class AdminProfileScreen extends StatefulWidget {
  final UserModel user;
  final AuthService? authService;
  const AdminProfileScreen({super.key, required this.user, this.authService});
  @override
  State<AdminProfileScreen> createState() => _AdminProfileScreenState();
}

class _AdminProfileScreenState extends State<AdminProfileScreen> {
  late final AuthService _auth = widget.authService ?? AuthService();
  static const _version = String.fromEnvironment('APP_VERSION', defaultValue: 'not set');
  static const _build = String.fromEnvironment('APP_BUILD_NUMBER', defaultValue: 'not set');

  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(14), children: [
    AdminCard(child: Row(children: [UserAvatar(fullName: widget.user.fullName, avatarUrl: widget.user.avatarUrl, size: 58), const SizedBox(width: 14), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(widget.user.fullName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)), Text(widget.user.email, style: const TextStyle(fontSize: 13, color: AppTheme.textMuted)), const SizedBox(height: 8),
      Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4), decoration: BoxDecoration(color: AppTheme.brandBlue.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(18)), child: const Text('ADMIN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.brandBlue))),
    ]))])),
    const SizedBox(height: 14),
    AdminCard(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('Client view', style: TextStyle(fontWeight: FontWeight.w700)), const SizedBox(height: 6),
      const Text('Open the customer shell to check what clients see. Your administrator role is unchanged.', style: TextStyle(fontSize: 13, color: AppTheme.textMuted)), const SizedBox(height: 12),
      OutlinedButton.icon(key: const Key('admin-open-client-view'), onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ClientShell(user: widget.user, authService: _auth))), icon: const Icon(Icons.open_in_new), label: const Text('Open client view')),
    ])),
    const SizedBox(height: 14),
    AdminCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Build information', style: TextStyle(fontWeight: FontWeight.w700)), const SizedBox(height: 6),
      Text('App version: $_version', style: const TextStyle(fontSize: 13, color: AppTheme.textMuted)),
      Text('Build number: $_build', style: const TextStyle(fontSize: 13, color: AppTheme.textMuted)),
    ])),
    const SizedBox(height: 20),
    ElevatedButton(key: const Key('admin-sign-out'), style: ElevatedButton.styleFrom(backgroundColor: AppTheme.dangerRed), onPressed: _confirmSignOut, child: const Text('Sign out')),
  ]);

  Future<void> _confirmSignOut() async {
    final yes = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: const Text('Sign out of QuickFix?'), content: const Text('You will leave the administrator session and return to the sign-in screen.'),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), ElevatedButton(key: const Key('admin-sign-out-confirm'), onPressed: () => Navigator.pop(context, true), child: const Text('Sign out'))],
    ));
    if (yes != true || !mounted) return;
    await _auth.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
  }
}
