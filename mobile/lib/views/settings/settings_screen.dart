import 'package:quickfix/views/worker/job_alert_preferences_screen.dart';
import 'package:quickfix/services/profile_service.dart';
import 'package:flutter/material.dart';
import 'package:quickfix/controllers/auth_controller.dart';
import 'package:quickfix/core/theme/app_theme.dart';
import 'package:quickfix/core/utils/content_direction.dart';
import 'package:quickfix/core/widgets/app_card.dart';
import 'package:quickfix/models/app_language.dart';
import 'package:quickfix/models/app_notification.dart';
import 'package:quickfix/models/user_model.dart';
import 'package:quickfix/services/account_deletion_service.dart';
import 'package:quickfix/services/app_release_service.dart';
import 'package:quickfix/services/auth_service.dart';
import 'package:quickfix/services/language_service.dart';
import 'package:quickfix/services/location_service.dart';
import 'package:quickfix/services/support_service.dart';
import 'package:quickfix/services/translation_service.dart';
import 'package:quickfix/views/settings/delete_account_screen.dart';
import 'package:quickfix/views/settings/help_centre_screen.dart';
import 'package:quickfix/views/settings/language_picker_screen.dart';
import 'package:quickfix/views/settings/legal_screen.dart';
import 'package:quickfix/views/settings/permission_explainer_screen.dart';

class SettingsScreen extends StatefulWidget {
  final UserModel user;
  final ProfileService? profileService;
  final AuthService? authService;
  final AuthController? authController;
  final AccountDeletionService? accountDeletionService;
  final LanguageService? languageService;
  final TranslationService? translationService;
  final LocationService? locationService;
  final SupportService? supportService;
  const SettingsScreen({super.key, required this.user, this.profileService, this.authService, this.authController, this.accountDeletionService,
    this.languageService, this.translationService, this.locationService, this.supportService});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}
class _SettingsScreenState extends State<SettingsScreen> {
  late UserModel _user = widget.user;
  late final AuthService _auth = widget.authService ?? AuthService();
  late Stream<UserModel?> _stream = _watch();
  UserModel? _last;
  AppLanguage? _chosen;
  final _saving = <String>{};
  bool _resetting = false;
  Stream<UserModel?> _watch() { try { return _auth.watchUser(widget.user.uid); } catch (error, stack) { return Stream.error(error, stack); } }
  void _message(String text) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text))); }
  Future<void> _chooseLanguage() async {
    final selected = await Navigator.of(context).push<AppLanguage>(MaterialPageRoute(builder: (_) => LanguagePickerScreen(
      user: _user, languageService: widget.languageService, translationService: widget.translationService, authService: widget.authService)));
    if (selected != null && mounted) setState(() { _chosen = selected; _user = _user.copyWith(preferredLanguage: selected.code); });
  }
  Future<void> _toggle(String key, bool value) async {
    if (_saving.contains(key)) return;
    setState(() { _saving.add(key); });
    try {
      await _auth.updateNotificationPreference(uid: _user.uid, key: key, value: value);
      if (mounted) setState(() { _user = _user.copyWith(notificationPrefs: NotificationPrefs.fromMap({..._user.notificationPrefs.toMap(), key: value})); });
    } catch (_) { _message('Preference save was not confirmed. Refresh the settings before retrying.'); }
    finally { if (mounted) setState(() { _saving.remove(key); }); }
  }
  Future<void> _resetPassword() async {
    if (_resetting) return; setState(() { _resetting = true; });
    try { await _auth.requestCurrentPasswordReset(_user.uid); _message('Password reset requested for your signed-in email. Check your inbox.'); }
    catch (_) { _message('Could not request a password reset. Check your connection and try again.'); }
    finally { if (mounted) setState(() { _resetting = false; }); }
  }
  Widget _heading(String text) => Padding(padding: const EdgeInsets.only(top: 20, bottom: 10), child: Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.brandBlue)));
  @override
  Widget build(BuildContext context) => Scaffold(backgroundColor: AppTheme.bgLight, appBar: AppBar(title: const Text('Settings')),
    body: SafeArea(child: StreamBuilder<UserModel?>(stream: _stream, builder: (context, snapshot) {
      if (snapshot.hasData && !identical(_last, snapshot.data)) { _last = snapshot.data; _user = snapshot.data!; }
      return ListView(padding: const EdgeInsets.all(16), children: [
        if (snapshot.hasError) AppCard(child: Column(children: [const Text('Could not refresh account preferences. Showing the last loaded profile.', style: TextStyle(fontSize: 13)),
          TextButton(key: const Key('settings-retry'), onPressed: () => setState(() { _stream = _watch(); }), child: const Text('Retry'))])),
        _heading('Account'), AppCard(padding: 0, child: Column(children: [
          ListTile(leading: const Icon(Icons.email_outlined, color: AppTheme.brandBlue), title: const Text('Signed-in profile email'), subtitle: Text(_user.email, textDirection: contentDirection(_user.email))),
          ListTile(key: const Key('settings-reset-password'), leading: const Icon(Icons.lock_reset_outlined, color: AppTheme.brandBlue), title: Text(_resetting ? 'Requesting reset…' : 'Change password'),
            subtitle: const Text('Send a reset link to the authenticated account’s email'), trailing: const Icon(Icons.chevron_right), onTap: _resetting ? null : _resetPassword),
        ])),
        if (_user.role == UserRole.worker) ListTile(key: const Key('settings-job-preferences'), leading: const Icon(Icons.filter_list, color: AppTheme.brandBlue), title: const Text('Job alert preferences'),
          trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => JobAlertPreferencesScreen(workerId: _user.uid, profileService: widget.profileService)))),
        _heading('Preferences'), AppCard(padding: 0, child: Column(children: [
          ListTile(key: const Key('settings-language'), leading: const Icon(Icons.translate, color: AppTheme.brandBlue), title: const Text('Review language'),
            subtitle: Text(_chosen?.code == _user.preferredLanguage ? _chosen!.displayName : _user.preferredLanguage), trailing: const Icon(Icons.chevron_right), onTap: _chooseLanguage),
          for (final item in <(String, String, bool)>[('jobUpdates', 'Job updates', _user.notificationPrefs.jobUpdates), ('messages', 'Messages', _user.notificationPrefs.messages), ('promotions', 'Promotions', _user.notificationPrefs.promotions)])
            SwitchListTile(key: Key('settings-pref-${item.$1}'), title: Text(item.$2), subtitle: _saving.contains(item.$1) ? const Text('Saving…') : null,
              value: item.$3, onChanged: _saving.contains(item.$1) ? null : (value) => _toggle(item.$1, value)),
        ])),
        const SizedBox(height: 10), const Text('Preferences filter in-app notifications only; records can still be stored. No push/email delivery is enabled. Review language changes ML review translation, not English navigation.', style: TextStyle(fontSize: 13, color: AppTheme.textMuted)),
        _heading('Privacy'), AppCard(padding: 0, child: Column(children: [
          ListTile(key: const Key('settings-location-permission'), leading: const Icon(Icons.location_on_outlined, color: AppTheme.brandBlue), title: const Text('Location permission'),
            subtitle: const Text('Explicit one-shot use, never continuous tracking'), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PermissionExplainerScreen(
              purpose: 'Choose permission for nearby browsing, job pins and explicit sharing', locationService: widget.locationService)))),
          const Padding(padding: EdgeInsets.all(14), child: Text('Account/contact information, jobs, reviews and chats are stored in Firebase. New photos stay on this device; selected reviews can be processed by the translation proxy. Read Privacy for precise retention and deletion limits.', style: TextStyle(fontSize: 13, color: AppTheme.textMuted))),
        ])),
        _heading('About'), AppCard(padding: 0, child: Column(children: [
          ListTile(key: const Key('settings-help'), leading: const Icon(Icons.help_outline, color: AppTheme.brandBlue), title: const Text('Help centre'), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => HelpCentreScreen(supportService: widget.supportService)))),
          ListTile(key: const Key('settings-terms'), leading: const Icon(Icons.description_outlined, color: AppTheme.brandBlue), title: const Text('Terms & app guide'), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LegalScreen()))),
          ListTile(key: const Key('settings-privacy'), leading: const Icon(Icons.privacy_tip_outlined, color: AppTheme.brandBlue), title: const Text('Privacy & data practices'), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LegalScreen(initialTab: 1)))),
          const ListTile(leading: Icon(Icons.info_outline, color: AppTheme.brandBlue), title: Text('QuickFix prototype'), subtitle: Text('Version ${String.fromEnvironment('APP_VERSION', defaultValue: '1.0.0')} • build ${AppReleaseService.currentBuildNumber}')),
        ])),
        _heading('Danger zone'), AppCard(padding: 0, child: ListTile(key: const Key('settings-delete-account'), leading: const Icon(Icons.delete_forever_outlined, color: AppTheme.dangerRed),
          title: const Text('Delete account', style: TextStyle(color: AppTheme.dangerRed)), subtitle: const Text('Permanent, reauthenticated cleanup; active work blocks deletion'), trailing: const Icon(Icons.chevron_right, color: AppTheme.dangerRed),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => DeleteAccountScreen(user: _user, authService: widget.authService, authController: widget.authController, accountDeletionService: widget.accountDeletionService))))),
      ]);
    })),
  );
}
