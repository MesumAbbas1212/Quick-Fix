import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quickfix/shared/models/review_model.dart';

class ReviewService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _reviewsCollection =>
      _firestore.collection('reviews');

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

    final workerRef = _firestore.collection('workers').doc(workerId);
    batch.update(workerRef, {
      'rating.average': FieldValue.increment(rating),
      'rating.total': FieldValue.increment(1),
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