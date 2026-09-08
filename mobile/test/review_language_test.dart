import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quickfix/core/widgets/review_list_tile.dart';
import 'package:quickfix/models/review_model.dart';

void main() {
  Widget wrap(Widget child) =>
      MaterialApp(home: Scaffold(body: Center(child: child)));

  group('ReviewListTile viewer language', () {
    testWidgets('hides translate button when review matches viewer language',
        (tester) async {
      final review = Review(
        id: 'r1',
        jobId: 'j1',
        reviewerId: 'u1',
        workerId: 'w1',
        rating: 5,
        originalText: 'Great work',
        originalLang: 'en',
        createdAt: DateTime(2026, 8, 11),
      );
      await tester.pumpWidget(
        wrap(ReviewListTile(review: review, viewerLanguage: 'en')),
      );
      expect(find.text('Translate'), findsNothing);
    });

    testWidgets(
        'shows translate button for a Latin review when viewer uses a '
        'non-Latin language', (tester) async {
      final review = Review(
        id: 'r1',
        jobId: 'j1',
        reviewerId: 'u1',
        workerId: 'w1',
        rating: 5,
        originalText: 'Great work',
        originalLang: 'en',
        createdAt: DateTime(2026, 8, 11),
      );
      await tester.pumpWidget(
        wrap(ReviewListTile(review: review, viewerLanguage: 'ur')),
      );
      expect(find.text('Translate'), findsOneWidget);
    });

    testWidgets('translates via onTranslate into the viewer language',
        (tester) async {
      final review = Review(
        id: 'r1',
        jobId: 'j1',
        reviewerId: 'u1',
        workerId: 'w1',
        rating: 5,
        originalText: 'Great work',
        originalLang: 'en',
        createdAt: DateTime(2026, 8, 11),
      );
      await tester.pumpWidget(wrap(ReviewListTile(
        review: review,
        viewerLanguage: 'ur',
        onTranslate: (text) async => 'کام بہت اچھا تھا',
      )));

      await tester.tap(find.text('Translate'));
      await tester.pump();
      await tester.pump();

      expect(find.text('کام بہت اچھا تھا'), findsOneWidget);
      expect(find.text('Translate'), findsNothing);
    });

    testWidgets(
        'prefers the per-language cached translation over the legacy English one',
        (tester) async {
      final review = Review(
        id: 'r1',
        jobId: 'j1',
        reviewerId: 'u1',
        workerId: 'w1',
        rating: 5,
        originalText: 'Travail excellent',
        originalLang: 'fr',
        translatedText: 'Excellent work',
        translations: const {'ur': 'کام بہت اچھا تھا'},
        createdAt: DateTime(2026, 8, 11),
      );
      await tester.pumpWidget(
        wrap(ReviewListTile(review: review, viewerLanguage: 'ur')),
      );
      expect(find.text('کام بہت اچھا تھا'), findsOneWidget);
      expect(find.text('Excellent work'), findsNothing);
      expect(find.text('Translate'), findsNothing);
    });

    testWidgets('English viewer still uses the legacy translatedText',
        (tester) async {
      final review = Review(
        id: 'r1',
        jobId: 'j1',
        reviewerId: 'u1',
        workerId: 'w1',
        rating: 5,
        originalText: 'Travail excellent',
        originalLang: 'fr',
        translatedText: 'Excellent work',
        createdAt: DateTime(2026, 8, 11),
      );
      await tester.pumpWidget(
        wrap(ReviewListTile(review: review, viewerLanguage: 'en')),
      );
      expect(find.text('Excellent work'), findsOneWidget);
      expect(find.text('Translate'), findsNothing);
    });
  });

  group('Review translations field', () {
    test('fromMap reads the translations map', () {
      final review = Review.fromMap({
        'jobId': 'j1',
        'reviewerId': 'u1',
        'workerId': 'w1',
        'rating': 5,
        'originalText': 'Travail excellent',
        'originalLang': 'fr',
        'translations': {'en': 'Excellent work', 'ur': 'کام بہت اچھا تھا'},
      }, 'r1');
      expect(review.translations['en'], 'Excellent work');
      expect(review.translations['ur'], 'کام بہت اچھا تھا');
    });

    test('fromMap defaults translations to an empty map', () {
      final review = Review.fromMap({
        'jobId': 'j1',
        'reviewerId': 'u1',
        'workerId': 'w1',
        'rating': 5,
        'originalText': 'Great work',
      }, 'r1');
      expect(review.translations, isEmpty);
    });

    test('toMap exports the translations map', () {
      final review = Review(
        id: 'r1',
        jobId: 'j1',
        reviewerId: 'u1',
        workerId: 'w1',
        rating: 5,
        originalText: 'Great work',
        originalLang: 'en',
        translations: const {'ur': 'کام بہت اچھا تھا'},
        createdAt: DateTime(2026, 8, 11),
      );
      final map = review.toMap();
      expect(map['translations'], {'ur': 'کام بہت اچھا تھا'});
    });
  });
}
