import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../models/review_model.dart';

/// Shared review card: star rating, original text, a translation in the
/// viewer's app language and a Translate button whenever the review was
/// written in a different language than the one the viewer is using.
class ReviewListTile extends StatefulWidget {
  final Review review;
  final Future<String> Function(String text)? onTranslate;

  /// Language code the viewer is using the app in (e.g. 'en', 'ur').
  /// Translations are produced for this language.
  final String viewerLanguage;

  const ReviewListTile({
    super.key,
    required this.review,
    this.onTranslate,
    this.viewerLanguage = 'en',
  });

  @override
  State<ReviewListTile> createState() => _ReviewListTileState();
}

class _ReviewListTileState extends State<ReviewListTile> {
  String? _translated;
  bool _translating = false;

  String get _viewerLanguage => widget.viewerLanguage;

  bool get _needsTranslation =>
      widget.review.originalLang.isNotEmpty &&
      widget.review.originalLang != _viewerLanguage;

  /// Best available translation for the viewer's language:
  /// per-language cache first, then the legacy English translation for
  /// English viewers, then a translation fetched in this session.
  String? get _visibleTranslation {
    final cached = widget.review.translations[_viewerLanguage];
    if (cached != null && cached.trim().isNotEmpty) return cached;
    if (_viewerLanguage == 'en') {
      final legacy = widget.review.translatedText;
      if (legacy != null && legacy.trim().isNotEmpty) return legacy;
    }
    if (_translated != null && _translated.trim().isNotEmpty) return _translated;
    return null;
  }

  Future<void> _handleTranslate() async {
    if (widget.onTranslate == null) return;
    setState(() => _translating = true);
    try {
      final result = await widget.onTranslate!(widget.review.originalText);
      if (mounted) setState(() => _translated = result);
    } finally {
      if (mounted) setState(() => _translating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final review = widget.review;
    final translation = _visibleTranslation;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.bgLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderGray),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ...List.generate(
                5,
                (i) => Icon(
                  i < review.rating.round() ? Icons.star : Icons.star_border,
                  size: 14,
                  color: i < review.rating.round()
                      ? AppTheme.accentYellow
                      : AppTheme.textMuted,
                ),
              ),
              const Spacer(),
              if (_needsTranslation && translation == null)
                _translating
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : GestureDetector(
                        key: const Key('translate-button'),
                        onTap: _handleTranslate,
                        child: const Row(
                          children: [
                            Icon(Icons.translate,
                                size: 14, color: AppTheme.brandBlue),
                            SizedBox(width: 2),
                            Text(
                              'Translate',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.brandBlue,
                              ),
                            ),
                          ],
                        ),
                      ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            review.originalText,
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textDark,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (translation != null && translation.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              translation,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.brandBlue,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
