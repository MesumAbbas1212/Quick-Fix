import 'package:quickfix/models/app_notification.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole {
  user,
  worker,
  admin,
}

class UserModel {
  final String uid;
  final NotificationPrefs notificationPrefs;
  final List<String> savedWorkers;
  /// Derived from the private deletion marker, never written to public users.
  final bool deletionPending;
  final String email;
  final String fullName;
  final String phone;
  final UserRole role;
  final String? avatarUrl;
  final double rating;
  final int completedJobs;

  /// Language code (e.g. 'en', 'ur') the user chose for reviews to be
  /// shown in; chosen at sign-up and changeable from the profile.
  final String preferredLanguage;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserModel({
    required this.uid,
    this.notificationPrefs = const NotificationPrefs(),
    this.savedWorkers = const [],
    this.deletionPending = false,
    required this.email,
    required this.fullName,
    required this.phone,
    required this.role,
    this.avatarUrl,
    this.rating = 0.0,
    this.completedJobs = 0,
    this.preferredLanguage = 'en',
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserModel.fromMap(Map<String, dynamic> map, String uid) {
    return UserModel(
      uid: uid,
      notificationPrefs: NotificationPrefs.fromMap(map['notificationPrefs']),
      savedWorkers: (map['savedWorkers'] is List ? map['savedWorkers'] as List : const []).whereType<String>().toSet().toList(),
      email: map['email'] ?? '',
      fullName: map['fullName'] ?? '',
      phone: map['phone'] ?? '',
      role: UserRole.values.firstWhere(
        (e) => e.name == map['role'],
        orElse: () => UserRole.user,
      ),
      avatarUrl: map['avatarUrl'],
      rating: (map['rating'] ?? 0.0).toDouble(),
      completedJobs: map['completedJobs'] ?? 0,
      preferredLanguage: (map['preferredLanguage'] ?? 'en').toString(),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (savedWorkers.isNotEmpty) 'savedWorkers': savedWorkers,
      if (!notificationPrefs.jobUpdates || !notificationPrefs.messages || notificationPrefs.promotions) 'notificationPrefs': notificationPrefs.toMap(),
      'email': email,
      'fullName': fullName,
      'phone': phone,
      'role': role.name,
      'avatarUrl': avatarUrl,
      'rating': rating,
      'completedJobs': completedJobs,
      'preferredLanguage': preferredLanguage,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  UserModel copyWith({
    NotificationPrefs? notificationPrefs,
    List<String>? savedWorkers,
    bool? deletionPending,
    String? uid,
    String? email,
    String? fullName,
    String? phone,
    UserRole? role,
    String? avatarUrl,
    double? rating,
    int? completedJobs,
    String? preferredLanguage,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      notificationPrefs: notificationPrefs ?? this.notificationPrefs,
      savedWorkers: savedWorkers ?? this.savedWorkers,
      deletionPending: deletionPending ?? this.deletionPending,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      rating: rating ?? this.rating,
      completedJobs: completedJobs ?? this.completedJobs,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}