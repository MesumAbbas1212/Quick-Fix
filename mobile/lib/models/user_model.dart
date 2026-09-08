import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole {
  user,
  worker,
  admin,
}

class UserModel {
  final String uid;
  final String email;
  final String fullName;
  final String phone;
  final UserRole role;
  final String? avatarUrl;
  final double rating;
  final int completedJobs;

  /// Language code (e.g. 'en', 'ur') the user chose for the app to be
  /// shown in; chosen at sign-up and changeable from the profile.
  final String preferredLanguage;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserModel({
    required this.uid,
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