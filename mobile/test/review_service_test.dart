// ignore_for_file: subtype_of_sealed_class
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quickfix/services/review_service.dart';

class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}
class MockCollectionReference extends Mock implements CollectionReference<Map<String, dynamic>> {}
class MockDocumentReference extends Mock implements DocumentReference<Map<String, dynamic>> {}
class MockDocumentSnapshot extends Mock implements DocumentSnapshot<Map<String, dynamic>> {}
class MockWriteBatch extends Mock implements WriteBatch {}

void main() {
  late MockFirebaseFirestore mockFirestore;
  late MockCollectionReference mockReviewsCollection;
  late MockCollectionReference mockWorkersCollection;
  late MockDocumentReference mockReviewDoc;
  late MockDocumentReference mockWorkerDoc;
  late MockDocumentSnapshot mockWorkerSnapshot;
  late MockWriteBatch mockBatch;

  late ReviewService service;

  setUp(() {
    mockFirestore = MockFirebaseFirestore();
    mockReviewsCollection = MockCollectionReference();
    mockWorkersCollection = MockCollectionReference();
    mockReviewDoc = MockDocumentReference();
    mockWorkerDoc = MockDocumentReference();
    mockWorkerSnapshot = MockDocumentSnapshot();
    mockBatch = MockWriteBatch();

    when(() => mockFirestore.collection('reviews')).thenReturn(mockReviewsCollection);
    when(() => mockFirestore.collection('workers')).thenReturn(mockWorkersCollection);
    when(() => mockReviewsCollection.doc()).thenReturn(mockReviewDoc);
    when(() => mockReviewDoc.id).thenReturn('review-abc');
    when(() => mockWorkersCollection.doc(any())).thenReturn(mockWorkerDoc);
    when(() => mockWorkerDoc.get()).thenAnswer((_) async => mockWorkerSnapshot);
    when(() => mockFirestore.batch()).thenReturn(mockBatch);
    when(() => mockBatch.commit()).thenAnswer((_) async {});

    service = ReviewService(firestore: mockFirestore);
  });

  void mockWorkerRating(double rating, int reviews) {
    when(() => mockWorkerSnapshot.exists).thenReturn(true);
    when(() => mockWorkerSnapshot.data()).thenReturn({
      'rating': rating,
      'reviews': reviews,
    });
  }

  group('ReviewService.submitReview', () {
    test('writes review document with all fields', () async {
      mockWorkerRating(0, 0);

      final id = await service.submitReview(
        jobId: 'job-1',
        reviewerId: 'user-1',
        workerId: 'worker-1',
        rating: 4.0,
        originalText: 'بہت اچھا کام',
        originalLang: 'ur',
        translatedText: 'Very good work',
      );

      expect(id, 'review-abc');
      final captured = verify(() => mockBatch.set<Map<String, dynamic>>(
        mockReviewDoc,
        captureAny(),
        any(),
      )).captured.single as Map<String, dynamic>;
      expect(captured['jobId'], 'job-1');
      expect(captured['reviewerId'], 'user-1');
      expect(captured['workerId'], 'worker-1');
      expect(captured['rating'], 4.0);
      expect(captured['originalText'], 'بہت اچھا کام');
      expect(captured['originalLang'], 'ur');
      expect(captured['translatedText'], 'Very good work');
      expect(captured['createdAt'], isA<Timestamp>());
    });

    test('first review sets rating to submitted value and increments review count', () async {
      mockWorkerRating(0, 0);

      await service.submitReview(
        jobId: 'job-1',
        reviewerId: 'user-1',
        workerId: 'worker-1',
        rating: 4.0,
        originalText: 'Great work',
      );

      final captured = verify(() => mockBatch.update(mockWorkerDoc, captureAny()))
          .captured.single as Map<String, dynamic>;
      expect(captured['rating'], 4.0);
      expect(captured['reviews'], isA<FieldValue>());
    });

    test('second review recomputes average rating (4.0 then 5.0 -> 4.5)', () async {
      mockWorkerRating(4.0, 1);

      await service.submitReview(
        jobId: 'job-2',
        reviewerId: 'user-2',
        workerId: 'worker-1',
        rating: 5.0,
        originalText: 'Amazing',
      );

      final captured = verify(() => mockBatch.update(mockWorkerDoc, captureAny()))
          .captured.single as Map<String, dynamic>;
      expect(captured['rating'], 4.5);
    });

    test('worker with no existing profile document still works (defaults to zero)', () async {
      when(() => mockWorkerSnapshot.exists).thenReturn(false);

      final id = await service.submitReview(
        jobId: 'job-3',
        reviewerId: 'user-3',
        workerId: 'worker-9',
        rating: 5.0,
        originalText: 'Nice',
      );

      expect(id, 'review-abc');
      final captured = verify(() => mockBatch.update(mockWorkerDoc, captureAny()))
          .captured.single as Map<String, dynamic>;
      expect(captured['rating'], 5.0);
    });

    test('commits the batch once', () async {
      mockWorkerRating(3.0, 2);

      await service.submitReview(
        jobId: 'job-4',
        reviewerId: 'user-4',
        workerId: 'worker-1',
        rating: 3.0,
        originalText: 'Okay',
      );

      verify(() => mockBatch.commit()).called(1);
    });
  });
}
