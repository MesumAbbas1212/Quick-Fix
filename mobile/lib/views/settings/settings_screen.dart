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
  final LanguageService? languageService;
  final TranslationService? translationService;
  const SettingsScreen({super.key, required this.user, this.authService, this.languageService, this.translationService});
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
    ])),
  );
}
