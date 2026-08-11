import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quickfix/models/review_model.dart';

class ReviewService {
  final FirebaseFirestore _firestore;

  ReviewService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _reviewsCollection =>
      _firestore.collection('reviews');

  CollectionReference<Map<String, dynamic>> get _workersCollection =>
      _firestore.collection('workers');

  // Submit a review; also updates the worker's rating in a batch.
  Future<String> submitReview({
    required String jobId,
    required String reviewerId,
    required String workerId,
    required double rating,
    required String originalText,
    String originalLang = 'en',
    String? translatedText,
  }) async {
    final review = Review(
      id: '',
      jobId: jobId,
      reviewerId: reviewerId,
      workerId: workerId,
      rating: rating,
      originalText: originalText,
      originalLang: originalLang,
      translatedText: translatedText,
      createdAt: DateTime.now(),
    );

    final batch = _firestore.batch();

    final reviewRef = _reviewsCollection.doc();
    batch.set(reviewRef, review.toMap());

    final workerRef = _workersCollection.doc(workerId);
    final workerSnap = await workerRef.get();
    final workerData = workerSnap.exists ? workerSnap.data() : null;
    final currentRating = (workerData?['rating'] as num?)?.toDouble() ?? 0;
    final currentReviews = (workerData?['reviews'] as num?)?.toInt() ?? 0;
    final newRating =
        ((currentRating * currentReviews) + rating) / (currentReviews + 1);

    batch.update(workerRef, {
      'rating': newRating,
      'reviews': FieldValue.increment(1),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });

    await batch.commit();
    return reviewRef.id;
  }

  // List reviews for a worker
  Stream<List<Review>> watchReviewsForWorker(String workerId) {
    return _reviewsCollection
        .where('workerId', isEqualTo: workerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Review.fromMap(doc.data(), doc.id))
            .toList());
  }

  // One-shot fetch
  Future<List<Review>> getReviewsForWorker(String workerId) async {
    final snap = await _reviewsCollection
        .where('workerId', isEqualTo: workerId)
        .orderBy('createdAt', descending: true)
        .get();
    return snap.docs
        .map((doc) => Review.fromMap(doc.data(), doc.id))
        .toList();
  }
}