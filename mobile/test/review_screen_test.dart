import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quickfix/services/review_service.dart';
import 'package:quickfix/services/translation_service.dart';
import 'package:quickfix/views/reviews/review_screen.dart';

class MockReviewService extends Mock implements ReviewService {}
class MockTranslationService extends Mock implements TranslationService {}

void main() {
  testWidgets('ReviewScreen renders stars, text field and submit button',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: ReviewScreen(
              jobId: 'job1',
              workerId: 'worker1',
              reviewerId: 'user1',
            ),
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.star_border), findsNWidgets(5));
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Submit Review'), findsOneWidget);
  });

  testWidgets('tapping the third star selects 3 stars', (tester) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: ReviewScreen(
              jobId: 'job1',
              workerId: 'worker1',
              reviewerId: 'user1',
            ),
          ),
        ),
      ),
    );

    final stars = find.byIcon(Icons.star_border);
    await tester.tap(stars.at(2));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.star), findsNWidgets(3));
    expect(find.byIcon(Icons.star_border), findsNWidgets(2));
  });

  testWidgets('submit calls ReviewService and pops with success snackbar',
      (tester) async {
    final reviewService = MockReviewService();
    final translationService = MockTranslationService();
    when(() => reviewService.submitReview(
          jobId: any(named: 'jobId'),
          reviewerId: any(named: 'reviewerId'),
          workerId: any(named: 'workerId'),
          rating: any(named: 'rating'),
          originalText: any(named: 'originalText'),
          originalLang: any(named: 'originalLang'),
          translatedText: any(named: 'translatedText'),
        )).thenAnswer((_) async => 'review-1');
    when(() => translationService.translate('Great work', 'en'))
        .thenAnswer((_) async => 'Great work');

    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ReviewScreen(
                    jobId: 'job1',
                    workerId: 'worker1',
                    reviewerId: 'user1',
                    reviewService: reviewService,
                    translationService: translationService,
                  ),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.star_border).at(3));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'Great work');
    await tester.tap(find.text('Submit Review'));
    await tester.pumpAndSettle();

    verify(() => reviewService.submitReview(
          jobId: 'job1',
          reviewerId: 'user1',
          workerId: 'worker1',
          rating: 4,
          originalText: 'Great work',
          originalLang: 'en',
          translatedText: any(named: 'translatedText'),
        )).called(1);

    expect(find.byType(ReviewScreen), findsNothing);
    expect(find.text('Review submitted'), findsOneWidget);
  });

  testWidgets('non-Latin review is translated before submit', (tester) async {
    final reviewService = MockReviewService();
    final translationService = MockTranslationService();
    when(() => reviewService.submitReview(
          jobId: any(named: 'jobId'),
          reviewerId: any(named: 'reviewerId'),
          workerId: any(named: 'workerId'),
          rating: any(named: 'rating'),
          originalText: any(named: 'originalText'),
          originalLang: any(named: 'originalLang'),
          translatedText: any(named: 'translatedText'),
        )).thenAnswer((_) async => 'review-1');
    when(() => translationService.translate('بہت اچھا کام', 'en'))
        .thenAnswer((_) async => 'Very good work');

    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: ReviewScreen(
        jobId: 'job1',
        workerId: 'worker1',
        reviewerId: 'user1',
        reviewService: reviewService,
        translationService: translationService,
      ),
    ));

    await tester.tap(find.byIcon(Icons.star_border).at(4));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'بہت اچھا کام');
    await tester.tap(find.text('Submit Review'));
    await tester.pumpAndSettle();

    verify(() => translationService.translate('بہت اچھا کام', 'en')).called(1);
    verify(() => reviewService.submitReview(
          jobId: 'job1',
          reviewerId: 'user1',
          workerId: 'worker1',
          rating: 5,
          originalText: 'بہت اچھا کام',
          originalLang: 'ur',
          translatedText: 'Very good work',
        )).called(1);
  });
}
