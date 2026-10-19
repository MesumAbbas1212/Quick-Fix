import 'package:quickfix/views/settings/help_centre_screen.dart';
import 'package:quickfix/controllers/auth_controller.dart';
import 'package:quickfix/services/account_deletion_service.dart';
import 'package:quickfix/views/settings/delete_account_screen.dart';
import 'package:quickfix/views/settings/legal_screen.dart';
import 'package:flutter/material.dart';
import 'package:quickfix/core/theme/app_theme.dart';
import 'package:quickfix/core/widgets/app_card.dart';
import 'package:quickfix/models/app_language.dart';
import 'package:quickfix/models/user_model.dart';
import 'package:quickfix/services/auth_service.dart';
import 'package:quickfix/services/language_service.dart';
import 'package:quickfix/services/translation_service.dart';
import 'package:quickfix/views/settings/language_picker_screen.dart';

class SettingsScreen extends StatefulWidget {
  final UserModel user;
  final AuthService? authService;
  final AuthController? authController;
  final AccountDeletionService? accountDeletionService;
  final LanguageService? languageService;
  final TranslationService? translationService;
  const SettingsScreen({super.key, required this.user, this.authService, this.authController, this.accountDeletionService, this.languageService, this.translationService});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}
class _SettingsScreenState extends State<SettingsScreen> {
  late UserModel _user = widget.user;
  AppLanguage? _chosen;
  Future<void> _chooseLanguage() async {
    final selected = await Navigator.of(context).push<AppLanguage>(MaterialPageRoute(builder: (_) => LanguagePickerScreen(
      user: _user, languageService: widget.languageService, translationService: widget.translationService, authService: widget.authService)));
    if (!mounted || selected == null) return;
    setState(() { _chosen = selected; _user = _user.copyWith(preferredLanguage: selected.code); });
  }
  @override
  Widget build(BuildContext context) => Scaffold(backgroundColor: AppTheme.bgLight,
    appBar: AppBar(title: const Text('Settings')),
    body: SafeArea(child: ListView(padding: const EdgeInsets.all(16), children: [
      AppCard(padding: 0, child: ListTile(key: const Key('settings-language'), leading: const Icon(Icons.translate, color: AppTheme.brandBlue),
        title: const Text('Review language', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        subtitle: Text(_chosen?.displayName ?? _user.preferredLanguage, style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
        trailing: const Icon(Icons.chevron_right), onTap: _chooseLanguage)),
      const SizedBox(height: 12), const Text('This preference controls machine-translated reviews. Navigation and controls stay in English.',
        style: TextStyle(fontSize: 13, color: AppTheme.textMuted)),
      const SizedBox(height: 20), AppCard(padding: 0, child: Column(children: [
        ListTile(key: const Key('settings-help'), leading: const Icon(Icons.help_outline, color: AppTheme.brandBlue), title: const Text('Help centre'), trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HelpCentreScreen()))),
        ListTile(key: const Key('settings-terms'), leading: const Icon(Icons.description_outlined, color: AppTheme.brandBlue),
          title: const Text('Terms & app guide', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)), trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LegalScreen()))),
        const Divider(height: 1, color: AppTheme.borderGray),
        ListTile(key: const Key('settings-privacy'), leading: const Icon(Icons.privacy_tip_outlined, color: AppTheme.brandBlue),
          title: const Text('Privacy & data practices', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)), trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LegalScreen(initialTab: 1)))),
      ])),
      const SizedBox(height: 24), AppCard(padding: 0, child: ListTile(key: const Key('settings-delete-account'),
        leading: const Icon(Icons.delete_forever_outlined, color: AppTheme.dangerRed),
        title: const Text('Delete account', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.dangerRed)),
        subtitle: const Text('Danger zone • permanent cleanup', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
        trailing: const Icon(Icons.chevron_right, color: AppTheme.dangerRed), onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => DeleteAccountScreen(
          user: _user, authService: widget.authService, authController: widget.authController, accountDeletionService: widget.accountDeletionService))))),
    ])),
  );
}
