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

  /// Language code the reviewer is using the app in; used to tag the
  /// review's original language (e.g. 'en', 'ur', 'fr').
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

  /// Infers the review's language from the text script and the reviewer's
  /// app language: non-Latin script matches a non-Latin reviewer language
  /// (e.g. an Urdu user writing in Urdu), otherwise it falls back to the
  /// platform's common pair (Urdu for non-Latin, English for Latin).
  String _resolveOriginalLang(bool textIsNonLatin) {
    final reviewerLang = widget.reviewerLanguage;
    final reviewerIsNonLatin = TranslationService.isNonLatinCode(reviewerLang);
    if (textIsNonLatin) {
      return reviewerIsNonLatin ? reviewerLang : 'ur';
    }
    return reviewerIsNonLatin ? 'en' : reviewerLang;
  }

  Future<void> _handleSubmit() async {
    final text = _textController.text.trim();
    if (_rating == 0 || text.isEmpty) return;
    setState(() => _isSubmitting = true);

    try {
      final isNonLatin = TranslationService.isNonLatin(text);
      final lang = _resolveOriginalLang(isNonLatin);

      // 1) Save the review first — the submit must never depend on the
      // translation proxy being reachable.
      final reviewId = await _reviewService.submitReview(
        jobId: widget.jobId,
        reviewerId: widget.reviewerId,
        workerId: widget.workerId,
        rating: _rating.toDouble(),
        originalText: text,
        originalLang: lang,
      );

      // 2) Best-effort English translation with a hard timeout, so an
      // unreachable proxy can never hang the UI.
      if (isNonLatin) {
        try {
          final translated = await _translationService
              .translate(text, 'en')
              .timeout(const Duration(seconds: 10));
          if (translated != null &&
              translated.trim().isNotEmpty &&
              translated != text) {
            await _reviewService.setTranslation(reviewId, 'en', translated);
          }
        } catch (_) {
          // Translation is optional — the review is already saved.
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Review submitted')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not submit your review. Please try again. ($e)'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
                controller: _textController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Write your review (Urdu or English)',
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
                onPressed: _rating == 0 || _isSubmitting ? null : _handleSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.ctaOrange,
                  foregroundColor: Colors.white,
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
                          valueColor: AlwaysStoppedAnimation(Colors.white),
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
      ),
    );
  }

  Widget _buildStars() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (index) {
        final filled = index < _rating;
        return GestureDetector(
          onTap: () => setState(() => _rating = index + 1),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Icon(
              filled ? Icons.star : Icons.star_border,
              size: 40,
              color: filled ? AppTheme.accentYellow : AppTheme.borderGray,
            ),
          ),
        );
      }),
    );
  }
}
