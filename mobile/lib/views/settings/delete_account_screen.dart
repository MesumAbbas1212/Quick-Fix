import 'package:flutter/material.dart';
import 'package:quickfix/controllers/auth_controller.dart';
import 'package:quickfix/core/theme/app_theme.dart';
import 'package:quickfix/core/utils/content_direction.dart';
import 'package:quickfix/core/widgets/app_card.dart';
import 'package:quickfix/models/account_deletion_policy.dart';
import 'package:quickfix/models/user_model.dart';
import 'package:quickfix/services/account_deletion_service.dart';
import 'package:quickfix/services/auth_service.dart';
import 'package:quickfix/views/auth/login_screen.dart';
import 'package:quickfix/views/settings/legal_screen.dart';

class DeleteAccountScreen extends StatefulWidget {
  final UserModel user;
  final AccountDeletionService? accountDeletionService;
  final AuthService? authService;
  final AuthController? authController;
  const DeleteAccountScreen({super.key, required this.user, this.accountDeletionService, this.authService, this.authController});
  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}
class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  late final AccountDeletionService _service = widget.accountDeletionService ?? AccountDeletionService();
  final _confirmation = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _leaving = false;
  String? _error;
  @override
  void dispose() { _confirmation.dispose(); _password.dispose(); super.dispose(); }
  Future<void> _delete() async {
    if (_busy || _confirmation.text != 'DELETE' || _password.text.isEmpty) { return; }
    final confirmed = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(
      title: const Text('Permanently delete this account?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      content: const SingleChildScrollView(child: Text('This removes the data listed on this page. Completed counterparty history and simulated receipts are anonymized; moderation/progress records can remain. '
        'Cleanup can be partial on failure and must be resumed. This cannot be undone.', style: TextStyle(fontSize: 13))),
      actions: [TextButton(key: const Key('delete-account-cancel'), onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Keep account')),
        TextButton(key: const Key('delete-account-confirm'), style: TextButton.styleFrom(foregroundColor: AppTheme.dangerRed),
          onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Delete account'))],
    ));
    if (confirmed != true || !mounted || _busy) { return; }
    final password = _password.text;
    setState(() { _busy = true; _error = null; _password.clear(); });
    try {
      // The service reauthenticates before writing, caps each server call and
      // each cleanup pass, and never reports a partial operation as success.
      await _service.deleteAccount(uid: widget.user.uid, password: password);
      if (!mounted) { return; }
      widget.authController?.clearSession();
      Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => LoginScreen(authService: widget.authService)), (_) => false);
    } catch (error) {
      if (mounted) { setState(() { _error = error is AccountDeletionException ? error.message :
        'Deletion was not confirmed. Some cleanup may already have completed. Re-enter your password and retry to resume safely.'; }); }
    } finally { if (mounted) { setState(() { _busy = false; }); } }
  }
  Future<void> _leaveRecovery() async {
    if (_busy) { return; }
    setState(() { _busy = true; _leaving = true; _error = null; });
    try {
      await (widget.authService ?? AuthService()).signOut().timeout(const Duration(seconds: 10));
      if (!mounted) { return; }
      widget.authController?.clearSession();
      Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => LoginScreen(authService: widget.authService)), (_) => false);
    } catch (_) { if (mounted) { setState(() { _error = 'Could not sign out. Check your connection and try this action again.'; }); } }
    finally { if (mounted) { setState(() { _busy = false; _leaving = false; }); } }
  }
  @override
  Widget build(BuildContext context) => PopScope(canPop: !_busy, child: Scaffold(backgroundColor: AppTheme.bgLight,
    appBar: AppBar(title: const Text('Delete account', maxLines: 1, overflow: TextOverflow.ellipsis)),
    body: SafeArea(child: ListView(padding: const EdgeInsets.all(16), children: [
      if (widget.user.deletionPending) ...[
        const AppCard(child: Text('Unfinished deletion detected. This account is paused for new work. Re-enter your password to resume cleanup and Auth deletion.',
          style: TextStyle(fontSize: 13, color: AppTheme.dangerRed))), const SizedBox(height: 14),
      ],
      AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Account to delete', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)), const SizedBox(height: 8),
        Text(widget.user.email, textDirection: contentDirection(widget.user.email), style: const TextStyle(fontSize: 13)),
        const SizedBox(height: 8), const Text('This is permanent. Active assigned or in-progress work must be completed or cancelled first.',
          style: TextStyle(fontSize: 13, color: AppTheme.textMuted)),
      ])), const SizedBox(height: 14),
      const AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Removed by this flow', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)), SizedBox(height: 10),
        Text('• User/worker profiles and private payout preferences\n• Private verification references and saved address book\n• Posted jobs not needed for completed counterparty history\n• Reviews written by you or about your worker profile\n• Your quote inquiries/replies, applications, notification inbox and chats\n• App-managed photo/SharedPreferences caches on this device\n• Your Firebase Auth account, after profile cleanup', style: TextStyle(fontSize: 13, height: 1.6)),
      ])), const SizedBox(height: 14),
      const AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('What can remain', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)), SizedBox(height: 10),
        Text('Completed counterparty history, simulated receipts and de-identified withdrawal records keep amounts, dates and status, with your ID replaced by a shared deleted-account label and identifying job fields removed. Anonymous aggregate ratings/counts may remain. '
          'Moderation reports/disputes and a private minimal deletion progress/tombstone record remain for admin review; there is no automatic expiry in this demo. '
          'Document/receipt reference IDs remain; this is de-identification, not a guarantee of irreversible anonymity. This does not wipe other devices, screenshots, gallery/platform/Firebase caches, quoted free text or provider logs/backups.', style: TextStyle(fontSize: 13, height: 1.5, color: AppTheme.textMuted)),
      ])),
      TextButton(key: const Key('delete-account-privacy'), onPressed: _busy ? null : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LegalScreen(initialTab: 1))), child: const Text('Read full privacy practices')),
      const SizedBox(height: 8), TextField(key: const Key('delete-account-typed'), controller: _confirmation, enabled: !_busy,
        onChanged: (_) => setState(() {}), autocorrect: false, enableSuggestions: false,
        decoration: const InputDecoration(labelText: 'Type DELETE to confirm', helperText: 'Use the exact uppercase word DELETE.')),
      const SizedBox(height: 16), TextField(key: const Key('delete-account-password'), controller: _password, enabled: !_busy,
        obscureText: true, autocorrect: false, enableSuggestions: false, onChanged: (_) => setState(() {}),
        decoration: const InputDecoration(labelText: 'Current account password', helperText: 'Used only to reauthenticate, never stored by this flow.')),
      if (_error != null) Padding(padding: const EdgeInsets.symmetric(vertical: 14), child: Text(_error!, key: const Key('delete-account-error'), style: const TextStyle(fontSize: 13, color: AppTheme.dangerRed))),
      const SizedBox(height: 20), ElevatedButton(key: const Key('delete-account-submit'),
        onPressed: _busy || _confirmation.text != 'DELETE' || _password.text.isEmpty ? null : _delete,
        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.dangerRed, foregroundColor: AppTheme.surfaceWhite),
        child: Text(_busy ? (_leaving ? 'Signing out…' : 'Deleting — keep this page open…') : widget.user.deletionPending ? 'Resume account deletion' : 'Delete my account')),
      if (widget.user.deletionPending || _error != null) TextButton(key: const Key('delete-account-leave-recovery'), onPressed: _busy ? null : _leaveRecovery,
        child: const Text('Sign out and return to sign in')),
      if (_busy && !_leaving) const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('Server calls are bounded. Large accounts may need more than one pass. If a step fails, re-enter your password and retry.',
        style: TextStyle(fontSize: 13, color: AppTheme.textMuted))),
    ])),
  ));
}
