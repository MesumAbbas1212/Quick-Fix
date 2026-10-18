import 'package:quickfix/core/utils/content_direction.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:quickfix/core/theme/app_theme.dart';
import 'package:quickfix/services/review_service.dart';
import 'package:quickfix/services/translation_service.dart';

class ReviewScreen extends StatefulWidget {
  final String jobId;
  final String workerId;
  final String reviewerId;
  final ReviewService? reviewService;
  final TranslationService? translationService;

  /// Chosen target language for optional ML translation, not a claim about
  /// the language of entered text. The backend auto-detects the source.
  final String reviewerLanguage;

  const ReviewScreen({
    super.key,
    required this.jobId,
    required this.workerId,
    required this.reviewerId,
    this.reviewService,
    this.translationService,
    this.reviewerLanguage = 'en',
  });

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  int _rating = 0;
  final _textController = TextEditingController();
  bool _isSubmitting = false;

  late final ReviewService _reviewService =
      widget.reviewService ?? ReviewService();
  late final TranslationService _translationService =
      widget.translationService ?? TranslationService();

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    final text = _textController.text.trim();
    if (_rating == 0 || text.isEmpty || _isSubmitting) return;
    setState(() => _isSubmitting = true);

    try {
      // Preferred target language does not prove the language of entered text.
      // The ML proxy auto-detects source; do not guess Urdu/English by script.
      const lang = 'und';

      // 1) Save the review first — the submit must never depend on the
      // translation proxy being reachable.
      final reviewId = await _reviewService.submitReview(
        jobId: widget.jobId,
        reviewerId: widget.reviewerId,
        workerId: widget.workerId,
        rating: _rating.toDouble(),
        originalText: text,
        originalLang: lang,
      ).timeout(const Duration(seconds: 15));

      // Optional ML caching must not hold the submit UI hostage. Target the
      // chosen review language, never a fixed English target.
      unawaited(_cacheChosenTranslation(reviewId, text, widget.reviewerLanguage));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Review submitted')),
      );
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not submit your review. Check your connection and try again.')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _cacheChosenTranslation(String reviewId, String text, String target) async {
    try {
      final translated = await _translationService.translate(text, target).timeout(const Duration(seconds: 8));
      if (translated.trim().isNotEmpty && translated != text) {
        await _reviewService.setTranslation(reviewId, target, translated).timeout(const Duration(seconds: 8));
      }
    } catch (_) { /* Saved review remains usable; this optional task is bounded. */ }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
              const Text(
                'Rate this worker',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Tap a star to rate',
                style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
              ),
              const SizedBox(height: 16),
              _buildStars(),
              const SizedBox(height: 16),
              TextField(
                key: const Key('review-text'), enabled: !_isSubmitting,
                textDirection: contentDirection(_textController.text), onChanged: (_) => setState(() {}),
                controller: _textController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Write your review in any language',
                  hintStyle: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textMuted,
                  ),
                  filled: true,
                  fillColor: AppTheme.surfaceWhite,
                  contentPadding: const EdgeInsets.all(14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: AppTheme.borderGray),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                key: const Key('review-submit'),
                onPressed: _rating == 0 || _textController.text.trim().isEmpty || _isSubmitting ? null : _handleSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.ctaOrange,
                  foregroundColor: AppTheme.surfaceWhite,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(AppTheme.surfaceWhite),
                        ),
                      )
                    : const Text(
                        'Submit Review',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStars() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (index) {
        final filled = index < _rating;
        return IconButton(key: Key('review-star-${index + 1}'), tooltip: 'Rate ${index + 1} out of 5',
          onPressed: _isSubmitting ? null : () => setState(() { _rating = index + 1; }),
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44), padding: const EdgeInsets.all(2),
          icon: Icon(filled ? Icons.star : Icons.star_border, size: 40,
            color: filled ? AppTheme.accentYellow : AppTheme.borderGray));
      }),
    );
  }
}
