import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quickfix/shared/models/job_model.dart';

class WorkerProfile {
  final String uid;
  final String fullName;
  final String email;
  final String? phone;
  final String? about;
  final List<JobCategory> professions;
  final List<String> languages;
  final GeoPoint? location;
  final double minBudget;
  final double maxBudget;
  final double rating;
  final int completedJobs;
  final int reviews;
  final bool isAvailable;
  final String? avatarUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  WorkerProfile({
    required this.uid,
    required this.fullName,
    required this.email,
    this.phone,
    this.about,
    this.professions = const [],
    this.languages = const [],
    this.location,
    this.minBudget = 0,
    this.maxBudget = 0,
    this.rating = 0,
    this.completedJobs = 0,
    this.reviews = 0,
    this.isAvailable = true,
    this.avatarUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  factory WorkerProfile.fromMap(Map<String, dynamic> map, String uid) {
    return WorkerProfile(
      uid: uid,
      fullName: map['fullName'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'],
      about: map['about'],
      professions: (map['professions'] as List? ?? [])
          .map((e) => JobCategory.values.firstWhere(
                (c) => c.name == e,
                orElse: () => JobCategory.other,
              ))
          .toList(),
      languages: List<String>.from(map['languages'] ?? []),
      location: map['location'] as GeoPoint?,
      minBudget: (map['minBudget'] ?? 0).toDouble(),
      maxBudget: (map['maxBudget'] ?? 0).toDouble(),
      rating: (map['rating'] ?? 0).toDouble(),
      completedJobs: map['completedJobs'] ?? 0,
      reviews: map['reviews'] ?? 0,
      isAvailable: map['isAvailable'] ?? true,
      avatarUrl: map['avatarUrl'],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'fullName': fullName,
      'email': email,
      'phone': phone,
      'about': about,
      'professions': professions.map((p) => p.name).toList(),
      'languages': languages,
      'location': location,
      'minBudget': minBudget,
      'maxBudget': maxBudget,
      'rating': rating,
      'completedJobs': completedJobs,
      'reviews': reviews,
      'isAvailable': isAvailable,
      'avatarUrl': avatarUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  WorkerProfile copyWith({
    String? uid,
    String? fullName,
    String? email,
    String? phone,
    String? about,
    List<JobCategory>? professions,
    List<String>? languages,
    GeoPoint? location,
    double? minBudget,
    double? maxBudget,
    double? rating,
    int? completedJobs,
    int? reviews,
    bool? isAvailable,
    String? avatarUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return WorkerProfile(
      uid: uid ?? this.uid,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      about: about ?? this.about,
      professions: professions ?? this.professions,
      languages: languages ?? this.languages,
      location: location ?? this.location,
      minBudget: minBudget ?? this.minBudget,
      maxBudget: maxBudget ?? this.maxBudget,
      rating: rating ?? this.rating,
      completedJobs: completedJobs ?? this.completedJobs,
      reviews: reviews ?? this.reviews,
      isAvailable: isAvailable ?? this.isAvailable,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}