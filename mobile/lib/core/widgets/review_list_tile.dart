import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../models/review_model.dart';
import '../../services/translation_service.dart';

/// Shared review card: star rating, original text, inline translated text and
/// a Translate button for non-Latin reviews without a cached translation.
class ReviewListTile extends StatefulWidget {
  final Review review;
  final Future<String> Function(String text)? onTranslate;

  const ReviewListTile({super.key, required this.review, this.onTranslate});

  @override
  State<ReviewListTile> createState() => _ReviewListTileState();
}

class _ReviewListTileState extends State<ReviewListTile> {
  String? _translated;
  bool _translating = false;

  bool get _isNonLatin => TranslationService.isNonLatin(widget.review.originalText);

  String? get _visibleTranslation =>
      widget.review.translatedText ?? _translated;

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
              if (_isNonLatin && translation == null)
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
