import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quickfix/models/review_model.dart';

void main() {
  group('Review', () {
    test('fromMap round-trips all fields', () {
      final map = {
        'jobId': 'job1',
        'reviewerId': 'user1',
        'workerId': 'worker1',
        'rating': 4.5,
        'originalText': 'بہت اچھا کام',
        'originalLang': 'ur',
        'translatedText': 'Great work',
        'createdAt': Timestamp.fromDate(DateTime(2024, 6, 1, 10, 0)),
      };

      final review = Review.fromMap(map, 'rev1');

      expect(review.id, 'rev1');
      expect(review.jobId, 'job1');
      expect(review.reviewerId, 'user1');
      expect(review.workerId, 'worker1');
      expect(review.rating, 4.5);
      expect(review.originalText, 'بہت اچھا کام');
      expect(review.originalLang, 'ur');
      expect(review.translatedText, 'Great work');
      expect(review.createdAt, DateTime(2024, 6, 1, 10, 0));
    });

    test('fromMap defaults language to en and handles missing optional fields', () {
      final map = {
        'jobId': 'job1',
        'reviewerId': 'user1',
        'workerId': 'worker1',
        'rating': 5.0,
        'originalText': 'Amazing',
      };

      final review = Review.fromMap(map, 'rev2');

      expect(review.originalLang, 'en');
      expect(review.translatedText, isNull);
      expect(review.rating, 5.0);
    });

    test('toMap exports translatedText and language tag', () {
      final review = Review(
        id: 'rev1',
        jobId: 'job1',
        reviewerId: 'user1',
        workerId: 'worker1',
        rating: 4,
        originalText: 'بہت اچھا',
        originalLang: 'ur',
        translatedText: 'Very nice',
        createdAt: DateTime(2024, 6, 1),
      );

      final map = review.toMap();

      expect(map['rating'], 4);
      expect(map['originalText'], 'بہت اچھا');
      expect(map['originalLang'], 'ur');
      expect(map['translatedText'], 'Very nice');
      expect(map['workerId'], 'worker1');
    });
  });
}