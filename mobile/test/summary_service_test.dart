import 'package:flutter_test/flutter_test.dart';
import 'package:quickfix/services/summary_service.dart';

ReviewInput _rev(String text, {String lang = 'en', double rating = 5}) =>
    (text: text, lang: lang, rating: rating);

void main() {
  group('SummaryService.summarizeLocal (offline TF-IDF)', () {
    test('up to 4 reviews yields a single paragraph with a lead sentence',
        () {
      final paragraphs = SummaryService.summarizeLocal(
        workerName: 'Ahmed',
        reviews: [
          _rev('The AC cooling is excellent now.'),
          _rev('Good work, fast service.', rating: 4.5),
        ],
        target: 'en',
      );

      expect(paragraphs.length, 1);
      // The lead sentence states the average rating across the review count.
      expect(paragraphs.first, contains('Ahmed'));
      expect(paragraphs.first, contains('4.8/5'));
      expect(paragraphs.first, contains('2 reviews'));
    });

    test('more than 4 reviews yields two paragraphs', () {
      final paragraphs = SummaryService.summarizeLocal(
        workerName: 'Imran',
        reviews: [
          _rev('Excellent service, very professional.'),
          _rev('On time and within budget.'),
          _rev('The wiring was done safely and neatly.', rating: 4.5),
          _rev('Good work, fair price.', rating: 4),
          _rev('He explained everything clearly.'),
          _rev('He arrived late but fixed everything.', rating: 3.5),
        ],
        target: 'en',
      );

      expect(paragraphs.length, 2);
    });

    test('the second paragraph surfaces negative feedback when present', () {
      final paragraphs = SummaryService.summarizeLocal(
        workerName: 'Imran',
        reviews: [
          _rev('Excellent service, very professional.'),
          _rev('On time and within budget.'),
          _rev('The wiring was done safely.', rating: 4.5),
          _rev('Good work, fair price.', rating: 4),
          _rev('He explained everything clearly.'),
          _rev('He arrived late and the tap leaked again the next day.',
              rating: 2.5),
        ],
        target: 'en',
      );

      expect(paragraphs.length, 2);
      // The negative sentence (late + leaked) is captured, not dropped.
      final joined = paragraphs.join(' ');
      expect(joined, contains('late'));
      expect(joined, contains('leaked'));
    });

    test('empty reviews produce no paragraphs', () {
      expect(
        SummaryService.summarizeLocal(
          workerName: 'X',
          reviews: const [],
          target: 'en',
        ),
        isEmpty,
      );
    });

    test('supports a non-English target language', () {
      final paragraphs = SummaryService.summarizeLocal(
        workerName: 'Ahmed',
        reviews: [
          _rev('کام بہت اچھا ہے۔', lang: 'ur'),
          _rev('وہ وقت پر آیا۔', lang: 'ur', rating: 4.5),
        ],
        target: 'ur',
      );
      expect(paragraphs.length, 1);
      expect(paragraphs.first, contains('4.8/5'));
      // The Urdu lead uses native script, not English.
      expect(paragraphs.first, isNot(contains('Overall')));
    });

    test('deterministic for the same input', () {
      final reviews = [
        _rev('Great and quick.'),
        _rev('Polite and on time.'),
        _rev('A bit late overall.'),
      ];
      final a = SummaryService.summarizeLocal(
        workerName: 'Z',
        reviews: reviews,
        target: 'en',
      );
      final b = SummaryService.summarizeLocal(
        workerName: 'Z',
        reviews: reviews,
        target: 'en',
      );
      expect(a, b);
    });
  });
}
