import 'package:flutter/material.dart';
import 'package:quickfix/core/theme/app_theme.dart';
import 'package:quickfix/services/auth_service.dart';
import 'package:quickfix/views/auth/app_shell.dart';
import 'package:quickfix/views/auth/login_screen.dart';

/// An authenticated Firebase user whose public profile document is absent.
/// This is deliberately diagnostic: the app never creates an administrator
/// profile (or any other profile) as a recovery side effect.
class ProfileMissingScreen extends StatefulWidget {
  final String uid;
  final AuthService? authService;
  final bool initialNetworkError;

  const ProfileMissingScreen({super.key, required this.uid, this.authService, this.initialNetworkError = false});

  @override
  State<ProfileMissingScreen> createState() => _ProfileMissingScreenState();
}

class _ProfileMissingScreenState extends State<ProfileMissingScreen> {
  late final AuthService _auth = widget.authService ?? AuthService();
  late bool _networkError = widget.initialNetworkError;
  bool _loading = false;
  bool _showSteps = false;

  Future<void> _retry() async {
    setState(() { _loading = true; _networkError = false; });
    try {
      final profile = await _auth.getUserProfile(widget.uid, serverOnly: true).timeout(const Duration(seconds: 10));
      if (!mounted) return;
      if (profile == null) {
        setState(() { _loading = false; _networkError = false; });
      } else if (profile.blocked) {
        await _auth.signOut();
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
      } else {
        Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => AppShell(user: profile, authService: _auth)), (_) => false);
      }
    } catch (_) {
      if (mounted) setState(() { _loading = false; _networkError = true; });
    }
  }

  Future<void> _signOut() async {
    await _auth.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final title = _networkError ? "Can't reach Firestore" : 'Your profile is missing';
    final body = _networkError
        ? 'QuickFix could not verify your account profile. Check your connection and retry.'
        : 'Firebase Authentication accepted this account, but Firestore has no users/${widget.uid} document. The app will not create it automatically.';
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(title: const Text('Account setup')),
      body: SafeArea(child: ListView(padding: const EdgeInsets.all(20), children: [
        const SizedBox(height: 18),
        const Icon(Icons.account_box_outlined, size: 56, color: AppTheme.brandBlue),
        const SizedBox(height: 18),
        Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.textDark)),
        const SizedBox(height: 12),
        Text(body, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, color: AppTheme.textMuted)),
        if (!_networkError) ...[
          const SizedBox(height: 18),
          SelectableText('UID: ${widget.uid}', textAlign: TextAlign.center, key: const Key('profile-missing-uid'), style: const TextStyle(fontSize: 13, color: AppTheme.textDark)),
          const SizedBox(height: 14),
          Card(elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: AppTheme.borderGray)),
            child: ExpansionTile(key: const Key('profile-missing-steps'), title: const Text('What to do'), onExpansionChanged: (value) => setState(() => _showSteps = value),
              initiallyExpanded: _showSteps, children: [Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), child: Text(
                'A project administrator must create users/${widget.uid} in Firestore with the correct role. For a demo account, the authorized operator can also run backend/seed/create-accounts.js with a service account. Administrator profiles are provisioned out of band; this app cannot create one.',
                style: const TextStyle(fontSize: 14, color: AppTheme.textMuted),
              ))])),
        ],
        const SizedBox(height: 18),
        ElevatedButton.icon(key: const Key('profile-missing-retry'), onPressed: _loading ? null : _retry,
          icon: _loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.surfaceWhite)) : const Icon(Icons.refresh),
          label: Text(_networkError ? 'Retry connection' : 'Check again')),
        TextButton(key: const Key('profile-missing-signout'), onPressed: _loading ? null : _signOut, child: const Text('Sign out')),
      ])),
    );
  }
}
