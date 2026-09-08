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
    Map<String, String>? translations,
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
      translations: translations ?? const {},
      createdAt: DateTime.now(),
    );

    final batch = _firestore.batch();

    final reviewRef = _reviewsCollection.doc();
    batch.set(reviewRef, review.toMap());

    // Keep the worker's rating/review-count consistent — but only when the
    // worker document exists, so the review itself never fails to save.
    final workerRef = _workersCollection.doc(workerId);
    final workerSnap = await workerRef.get();
    if (workerSnap.exists) {
      final workerData = workerSnap.data();
      final currentRating = (workerData?['rating'] as num?)?.toDouble() ?? 0;
      final currentReviews = (workerData?['reviews'] as num?)?.toInt() ?? 0;
      final newRating =
          ((currentRating * currentReviews) + rating) / (currentReviews + 1);

      batch.update(workerRef, {
        'rating': newRating,
        'reviews': FieldValue.increment(1),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    }

    await batch.commit();
    return reviewRef.id;
  }

  // Cache a translated version of a review under [lang] (e.g. 'en'),
  // called after the review has already been saved.
  Future<void> setTranslation(String reviewId, String lang, String text) async {
    final ref = _reviewsCollection.doc(reviewId);
    final snap = await ref.get();
    if (!snap.exists) return;
    final existing =
        snap.exists && snap.data()!['translations'] is Map
            ? Map<String, String>.from(snap.data()!['translations'] as Map)
            : <String, String>{};
    existing[lang] = text;
    await ref.update({
      'translations': existing,
      'translatedText': lang == 'en' ? text : snap.data()?['translatedText'],
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  // List reviews for a worker
  Stream<List<Review>> watchReviewsForWorker(String workerId) {
    return _reviewsCollection
        .where('workerId', isEqualTo: workerId)
        .snapshots()
        .map((snapshot) {
          final reviews = snapshot.docs
              .map((doc) => Review.fromMap(doc.data(), doc.id))
              .toList();
          reviews.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return reviews;
        });
  }

  // One-shot fetch
  Future<List<Review>> getReviewsForWorker(String workerId) async {
    final snap = await _reviewsCollection
        .where('workerId', isEqualTo: workerId)
        .get();
    final reviews = snap.docs
        .map((doc) => Review.fromMap(doc.data(), doc.id))
        .toList();
    reviews.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return reviews;
  }
}