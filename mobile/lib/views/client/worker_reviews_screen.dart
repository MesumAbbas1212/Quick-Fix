import 'package:flutter/material.dart';
import 'package:quickfix/core/theme/app_theme.dart';
import 'package:quickfix/core/widgets/review_list_tile.dart';
import 'package:quickfix/models/review_model.dart';
import 'package:quickfix/services/review_service.dart';
import 'package:quickfix/services/translation_service.dart';

/// Full-screen review list for a worker: every review with rating, original
/// text, translation into the viewer's app language and the Translate
/// button. Opened from the "See all N reviews" button on the worker profile
/// so the profile (and its chat button) stays reachable.
class WorkerReviewsScreen extends StatelessWidget {
  final String workerUid;
  final String workerName;

  /// Average rating and review count from the worker's own document, shown
  /// in the header strip.
  final double rating;
  final int reviewCount;

  /// Language the viewer is using the app in; reviews translate into this.
  final String userLanguage;

  final ReviewService? reviewService;
  final TranslationService? translationService;

  const WorkerReviewsScreen({
    super.key,
    required this.workerUid,
    required this.workerName,
    required this.rating,
    required this.reviewCount,
    required this.userLanguage,
    this.reviewService,
    this.translationService,
  });

  ReviewService get _reviewService => reviewService ?? ReviewService();
  TranslationService get _translationService =>
      translationService ?? TranslationService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(
        backgroundColor: AppTheme.brandBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Reviews',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: StreamBuilder<List<Review>>(
          stream: _reviewService.watchReviewsForWorker(workerUid),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'Could not load reviews.',
                    style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
                  ),
                ),
              );
            }
            if (!snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.brandBlue,
                ),
              );
            }
            final reviews = snapshot.data!;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.star,
                        size: 16,
                        color: AppTheme.accentYellow,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        rating.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textDark,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$reviewCount reviews · $workerName',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: reviews.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: Text(
                              'No reviews yet',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppTheme.textMuted,
                              ),
                            ),
                          ),
                        )
                      : ListView(
                          padding: const EdgeInsets.all(14),
                          children: reviews
                              .map(
                                (review) => ReviewListTile(
                                  review: review,
                                  onTranslate: (text) =>
                                      _translationService.translate(
                                        text,
                                        userLanguage,
                                      ),
                                  viewerLanguage: userLanguage,
                                ),
                              )
                              .toList(),
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
