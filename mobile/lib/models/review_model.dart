import 'package:cloud_firestore/cloud_firestore.dart';

class Review {
  final String id;
  final String jobId;
  final String reviewerId;
  final String workerId;
  final double rating;
  final String originalText;
  final String originalLang;
  final String? translatedText;

  /// Cached translations keyed by target language code (e.g. 'en', 'ur').
  /// [translatedText] remains the legacy English translation.
  final Map<String, String> translations;
  final DateTime createdAt;

  Review({
    required this.id,
    required this.jobId,
    required this.reviewerId,
    required this.workerId,
    required this.rating,
    required this.originalText,
    this.originalLang = 'en',
    this.translatedText,
    this.translations = const {},
    required this.createdAt,
  });

  factory Review.fromMap(Map<String, dynamic> map, String id) {
    return Review(
      id: id,
      jobId: map['jobId'] ?? '',
      reviewerId: map['reviewerId'] ?? '',
      workerId: map['workerId'] ?? '',
      rating: (map['rating'] as num?)?.toDouble() ?? 0,
      originalText: map['originalText'] ?? '',
      originalLang: map['originalLang'] ?? 'en',
      translatedText: map['translatedText'],
      translations: _readTranslations(map['translations']),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  static Map<String, String> _readTranslations(Object? raw) {
    if (raw is Map) {
      return raw.map(
        (key, value) => MapEntry(key.toString(), value?.toString() ?? ''),
      );
    }
    return const {};
  }

  Map<String, dynamic> toMap() {
    return {
      'jobId': jobId,
      'reviewerId': reviewerId,
      'workerId': workerId,
      'rating': rating,
      'originalText': originalText,
      'originalLang': originalLang,
      'translatedText': translatedText,
      'translations': translations,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
