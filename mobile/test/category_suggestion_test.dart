import 'package:flutter_test/flutter_test.dart';
import 'package:quickfix/services/category_suggestion.dart';
import 'package:quickfix/shared/models/job_model.dart';

void main() {
  group('suggestCategory', () {
    test('maps plumbing labels to plumbing', () {
      final result = suggestCategory([
        (label: 'plumbing', confidence: 0.87),
        (label: 'pipe', confidence: 0.72),
      ]);
      expect(result, isNotNull);
      expect(result!.category, JobCategory.plumbing);
      expect(result.confidence, closeTo(1.59, 0.001));
    });

    test('maps cleaning labels to cleaning', () {
      final result = suggestCategory([(label: 'mop', confidence: 0.6)]);
      expect(result!.category, JobCategory.cleaning);
    });

    test('paint keyword matches the painting label', () {
      final result = suggestCategory([(label: 'painting', confidence: 0.9)]);
      expect(result!.category, JobCategory.painting);
    });

    test('wins by score across categories', () {
      final result = suggestCategory([
        (label: 'sink', confidence: 0.5),
        (label: 'wrench', confidence: 0.4),
        (label: 'broom', confidence: 0.2),
      ]);
      expect(result!.category, JobCategory.plumbing);
    });

    test('tie goes to the first listed category', () {
      final result = suggestCategory([
        (label: 'sink', confidence: 0.5),
        (label: 'mop', confidence: 0.5),
      ]);
      expect(result!.category, JobCategory.cleaning);
    });

    test('returns null below threshold', () {
      final result = suggestCategory([(label: 'sink', confidence: 0.15)]);
      expect(result, isNull);
    });

    test('throws on empty label list', () {
      expect(() => suggestCategory(const []), throwsArgumentError);
    });

    test('never maps to other', () {
      final result = suggestCategory([(label: 'misc stuff', confidence: 0.99)]);
      expect(result, isNull);
    });

    test('matching is case-insensitive', () {
      final result = suggestCategory([(label: 'MOUSE Tap', confidence: 0.8)]);
      expect(result!.category, JobCategory.plumbing);
    });
  });
}