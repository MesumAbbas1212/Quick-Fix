import 'package:flutter/material.dart';
import 'package:quickfix/core/theme/app_theme.dart';
import 'package:quickfix/services/preferences_service.dart';

class OnboardingCarousel extends StatefulWidget {
  final PreferencesService? preferencesService;
  final VoidCallback? onFinished;
  const OnboardingCarousel({super.key, this.preferencesService, this.onFinished});
  @override
  State<OnboardingCarousel> createState() => _OnboardingCarouselState();
}

class _OnboardingCarouselState extends State<OnboardingCarousel> {
  late final PreferencesService _preferences = widget.preferencesService ?? PreferencesService();
  final _pages = PageController();
  int _page = 0;
  bool _saving = false;
  String? _error;
  static const _content = [
    (Icons.post_add_outlined, 'Post a job in a minute', 'Describe the work, set your budget and choose a time. You decide which worker to hire.'),
    (Icons.workspace_premium_outlined, 'Nearby workers, ranked by skill', 'Find professionals by service, distance and availability. Ranks reflect completed work in the last year.'),
    (Icons.translate_outlined, 'Reviews in your language', 'Choose the language used to translate reviews. Read original feedback too; the app interface stays in English.'),
  ];
  @override
  void dispose() { _pages.dispose(); super.dispose(); }

  Future<void> _finish() async {
    if (_saving) return;
    setState(() { _saving = true; _error = null; });
    try {
      await _preferences.markOnboardingSeen().timeout(const Duration(seconds: 5));
      if (!mounted) return;
      if (widget.onFinished != null) { widget.onFinished!(); }
      else { Navigator.of(context).pop(true); }
    } catch (_) {
      if (mounted) setState(() { _saving = false; _error = 'Could not save your preference. Please try again.'; });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(canPop: false, child: Scaffold(
    backgroundColor: AppTheme.bgLight,
    appBar: AppBar(automaticallyImplyLeading: false, backgroundColor: AppTheme.bgLight,
      title: const Text('QuickFix', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppTheme.brandBlue)),
      actions: [TextButton(key: const Key('onboarding-skip'), onPressed: _saving ? null : _finish, child: const Text('Skip'))]),
    body: SafeArea(child: Column(children: [
      Expanded(child: PageView.builder(controller: _pages, itemCount: _content.length,
        physics: _saving ? const NeverScrollableScrollPhysics() : null,
        onPageChanged: (page) => setState(() { _page = page; }),
        itemBuilder: (context, index) {
          final content = _content[index];
          return SingleChildScrollView(padding: const EdgeInsets.all(24), child: Column(children: [
            const SizedBox(height: 24), Icon(content.$1, size: 96, color: AppTheme.brandBlue),
            const SizedBox(height: 28), Text(content.$2, textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppTheme.textDark)),
            const SizedBox(height: 16), Text(content.$3, textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: AppTheme.textMuted)),
          ]));
        })),
      Padding(padding: const EdgeInsets.all(16), child: Column(children: [
        Semantics(label: 'Page ${_page + 1} of ${_content.length}', child: Row(mainAxisAlignment: MainAxisAlignment.center,
          children: [for (var i = 0; i < _content.length; i++) Container(margin: const EdgeInsets.all(4), width: 8, height: 8,
            decoration: BoxDecoration(shape: BoxShape.circle, color: i == _page ? AppTheme.brandBlue : AppTheme.borderGray))])),
        if (_error != null) Padding(padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(_error!, style: const TextStyle(fontSize: 13, color: AppTheme.dangerRed))),
        const SizedBox(height: 16), SizedBox(width: double.infinity, child: ElevatedButton(
          key: const Key('onboarding-next'), onPressed: _saving ? null : _page == 2 ? _finish :
            () => _pages.nextPage(duration: const Duration(milliseconds: 250), curve: Curves.easeOut),
          child: Text(_saving ? 'Saving…' : _page == 2 ? 'Get started' : 'Next'))),
      ])),
    ])),
  ));
}
