import 'package:flutter/material.dart';
import 'package:quickfix/core/theme/app_theme.dart';
import 'package:quickfix/core/utils/content_direction.dart';
import 'package:quickfix/core/widgets/app_card.dart';
import 'package:quickfix/core/widgets/empty_state.dart';
import 'package:quickfix/core/widgets/loading_list.dart';
import 'package:quickfix/models/app_language.dart';
import 'package:quickfix/models/user_model.dart';
import 'package:quickfix/services/auth_service.dart';
import 'package:quickfix/services/language_service.dart';
import 'package:quickfix/services/translation_service.dart';

/// Returns the selected AppLanguage for sign-up, or saves it for [user].
/// UI remains English; the choice targets machine-translated review content.
class LanguagePickerScreen extends StatefulWidget {
  final String initialCode;
  final UserModel? user;
  final LanguageService? languageService;
  final TranslationService? translationService;
  final AuthService? authService;
  const LanguagePickerScreen({super.key, this.initialCode = 'en', this.user,
    this.languageService, this.translationService, this.authService});
  @override
  State<LanguagePickerScreen> createState() => _LanguagePickerScreenState();
}
class _LanguagePickerScreenState extends State<LanguagePickerScreen> {
  static const _sample = 'The worker arrived on time and explained the repair clearly.';
  late final LanguageService _service = widget.languageService ?? LanguageService();
  late final TranslationService _translation = widget.translationService ?? TranslationService();
  final _search = TextEditingController();
  List<AppLanguage> _languages = [];
  AppLanguage? _selected;
  bool _loading = true;
  bool _fallback = false;
  bool _saving = false;
  bool _previewing = false;
  String? _preview;
  String? _saveError;
  int _generation = 0;
  @override
  void initState() { super.initState(); _load(); }
  @override
  void dispose() { _search.dispose(); super.dispose(); }
  Future<void> _load({bool refresh = false}) async {
    setState(() { _loading = true; });
    List<AppLanguage> languages;
    var fallback = false;
    try {
      if (refresh) { _service.clearCache(); }
      languages = await _service.getAvailableLanguages().timeout(const Duration(seconds: 13));
      fallback = _service.usedFallback == true || languages.isEmpty;
      if (languages.isEmpty) { languages = LanguageService.fallbackLanguages; }
    } catch (_) { languages = LanguageService.fallbackLanguages; fallback = true; }
    if (!mounted) { return; }
    final current = _selected?.code ?? widget.user?.preferredLanguage ?? widget.initialCode;
    setState(() {
      _languages = languages; _fallback = fallback; _loading = false;
      // An unknown old code is not silently overwritten: require a selection.
      _selected = null;
      for (final language in languages) { if (language.code == current) { _selected = language; } }
    });
    await _loadPreview();
  }
  bool _isEnglish(String code) => code.toLowerCase().split(RegExp('[-_]')).first == 'en';
  Future<void> _loadPreview() async {
    final language = _selected;
    final generation = ++_generation;
    if (language == null) { setState(() { _preview = null; _previewing = false; }); return; }
    if (_isEnglish(language.code)) { setState(() { _preview = _sample; _previewing = false; }); return; }
    setState(() { _preview = null; _previewing = true; });
    String? translated;
    try {
      final text = await _translation.translate(_sample, language.code).timeout(const Duration(seconds: 9));
      if (text.trim().isNotEmpty && text.trim() != _sample) { translated = text; }
    } catch (_) { /* An original-text fallback is not a translated preview. */ }
    if (!mounted || generation != _generation) { return; }
    setState(() { _preview = translated; _previewing = false; });
  }
  Future<void> _save() async {
    final selection = _selected;
    if (_saving || selection == null) { return; }
    setState(() { _saving = true; _saveError = null; });
    try {
      if (widget.user != null) { await (widget.authService ?? AuthService())
        .updateProfile(uid: widget.user!.uid, preferredLanguage: selection.code).timeout(const Duration(seconds: 10)); }
      if (mounted) { Navigator.of(context).pop(selection); }
    } catch (_) {
      if (mounted) { setState(() { _saving = false; _saveError = 'Could not save this language. Please try again.'; }); }
    }
  }
  Widget _previewCard() => AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    const Text('Review preview', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)), const SizedBox(height: 10),
    if (_selected == null) const Text('Choose a language to preview a review.', style: TextStyle(fontSize: 13, color: AppTheme.textMuted))
    else if (_previewing) const LoadingList(rows: 1)
    else if (_preview != null) Text(_preview!, key: const Key('language-preview-text'), textDirection: contentDirection(_preview!),
      textAlign: contentDirection(_preview!) == TextDirection.rtl ? TextAlign.right : TextAlign.left, style: const TextStyle(fontSize: 14))
    else ...[
      const Text('Machine translation preview is unavailable. You can still select this language; originals remain available when translation fails.',
        style: TextStyle(fontSize: 13, color: AppTheme.textMuted)),
      TextButton(key: const Key('language-preview-retry'), onPressed: _loadPreview, child: const Text('Retry preview')),
    ],
  ]));
  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final matches = _languages.where((language) => '${language.code} ${language.nativeName} ${language.englishName}'.toLowerCase().contains(query)).toList();
    return Scaffold(backgroundColor: AppTheme.bgLight,
      appBar: AppBar(title: const Text('Review language')),
      body: SafeArea(child: _loading ? const LoadingList(rows: 4) : CustomScrollView(slivers: [
        SliverPadding(padding: const EdgeInsets.all(16), sliver: SliverList.list(children: [
          const Text('Choose the language used for review translation. The app interface stays in English.', style: TextStyle(fontSize: 13, color: AppTheme.textMuted)),
          const SizedBox(height: 12), TextField(key: const Key('language-search'), controller: _search, onChanged: (_) => setState(() {}),
            decoration: InputDecoration(labelText: 'Search languages', prefixIcon: const Icon(Icons.search), suffixIcon: query.isEmpty ? null : IconButton(
              key: const Key('language-clear-search'), tooltip: 'Clear search', onPressed: () { _search.clear(); setState(() {}); }, icon: const Icon(Icons.clear)))),
          if (_fallback) ...[
            const SizedBox(height: 12), const Text('Language catalog unavailable. Showing a limited fallback, not the full supported list.', style: TextStyle(fontSize: 13, color: AppTheme.textMuted)),
            TextButton(key: const Key('language-catalog-retry'), onPressed: () => _load(refresh: true), child: const Text('Retry language catalog')),
          ],
          const SizedBox(height: 12), _previewCard(),
        ])),
        if (matches.isEmpty) SliverToBoxAdapter(child: EmptyState(icon: Icons.search_off_outlined, title: 'No matching languages',
          message: 'Try a native name, English name or language code.', action: TextButton(key: const Key('language-empty-clear'), onPressed: () { _search.clear(); setState(() {}); }, child: const Text('Clear search'))))
        else SliverList.builder(itemCount: matches.length, itemBuilder: (context, index) {
          final language = matches[index]; final selected = _selected?.code == language.code;
          return Padding(padding: const EdgeInsetsDirectional.only(start: 16, end: 16, bottom: 8), child: AppCard(padding: 0, child: ListTile(
            key: Key('language-${language.code}'), selected: selected, onTap: _saving ? null : () { setState(() { _selected = language; }); _loadPreview(); },
            title: Text(language.displayName, textDirection: contentDirection(language.displayName), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            subtitle: Text(language.englishName.isEmpty ? language.code : language.englishName, style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
            trailing: selected ? const Icon(Icons.check_circle, color: AppTheme.brandBlue, semanticLabel: 'Selected') : null,
          )));
        }),
      ])),
      bottomNavigationBar: SafeArea(child: Padding(padding: const EdgeInsets.all(16), child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (_saveError != null) Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(_saveError!, style: const TextStyle(fontSize: 13, color: AppTheme.dangerRed))),
        SizedBox(width: double.infinity, child: ElevatedButton(key: const Key('language-save'), onPressed: _selected == null || _saving || _loading ? null : _save,
          child: Text(_saving ? 'Saving…' : widget.user == null ? 'Use this language' : 'Save language'))),
      ]))),
    );
  }
}
