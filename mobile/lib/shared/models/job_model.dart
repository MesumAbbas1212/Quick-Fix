import 'package:cloud_firestore/cloud_firestore.dart';

enum JobStatus {
  open,
  assigned,
  inProgress,
  completed,
  cancelled,
}

enum JobCategory {
  cleaning,
  plumbing,
  electrical,
  carpentry,
  painting,
  gardening,
  moving,
  applianceRepair,
  tutoring,
  beauty,
  other,
}

class JobModel {
  final String id;
  final String userId;
  final String? workerId;
  final String title;
  final String description;
  final JobCategory category;
  final String address;
  final GeoPoint location;
  final double budgetMin;
  final double budgetMax;
  final DateTime preferredDate;
  final DateTime? preferredTime;
  final List<String> images;
  final JobStatus status;
  final double? rating;
  final String? review;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? assignedAt;
  final DateTime? completedAt;

  JobModel({
    required this.id,
    required this.userId,
    this.workerId,
    required this.title,
    required this.description,
    required this.category,
    required this.address,
    required this.location,
    required this.budgetMin,
    required this.budgetMax,
    required this.preferredDate,
    this.preferredTime,
    this.images = const [],
    this.status = JobStatus.open,
    this.rating,
    this.review,
    required this.createdAt,
    required this.updatedAt,
    this.assignedAt,
    this.completedAt,
  });

  factory JobModel.fromMap(Map<String, dynamic> map, String id) {
    return JobModel(
      id: id,
      userId: map['userId'] ?? '',
      workerId: map['workerId'],
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      category: JobCategory.values.firstWhere(
        (e) => e.name == map['category'],
        orElse: () => JobCategory.other,
      ),
      address: map['address'] ?? '',
      location: map['location'] as GeoPoint? ?? const GeoPoint(0, 0),
      budgetMin: (map['budgetMin'] ?? 0).toDouble(),
      budgetMax: (map['budgetMax'] ?? 0).toDouble(),
      preferredDate: (map['preferredDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      preferredTime: (map['preferredTime'] as Timestamp?)?.toDate(),
      images: List<String>.from(map['images'] ?? []),
      status: JobStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => JobStatus.open,
      ),
      rating: (map['rating'] as num?)?.toDouble(),
      review: map['review'],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      assignedAt: (map['assignedAt'] as Timestamp?)?.toDate(),
      completedAt: (map['completedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'workerId': workerId,
      'title': title,
      'description': description,
      'category': category.name,
      'address': address,
      'location': location,
      'budgetMin': budgetMin,
      'budgetMax': budgetMax,
      'preferredDate': Timestamp.fromDate(preferredDate),
      'preferredTime': preferredTime != null ? Timestamp.fromDate(preferredTime!) : null,
      'images': images,
      'status': status.name,
      'rating': rating,
      'review': review,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'assignedAt': assignedAt != null ? Timestamp.fromDate(assignedAt!) : null,
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
    };
  }

  JobModel copyWith({
    String? id,
    String? userId,
    String? workerId,
    String? title,
    String? description,
    JobCategory? category,
    String? address,
    GeoPoint? location,
    double? budgetMin,
    double? budgetMax,
    DateTime? preferredDate,
    DateTime? preferredTime,
    List<String>? images,
    JobStatus? status,
    double? rating,
    String? review,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? assignedAt,
    DateTime? completedAt,
  }) {
    return JobModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      workerId: workerId ?? this.workerId,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      address: address ?? this.address,
      location: location ?? this.location,
      budgetMin: budgetMin ?? this.budgetMin,
      budgetMax: budgetMax ?? this.budgetMax,
      preferredDate: preferredDate ?? this.preferredDate,
      preferredTime: preferredTime ?? this.preferredTime,
      images: images ?? this.images,
      status: status ?? this.status,
      rating: rating ?? this.rating,
      review: review ?? this.review,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      assignedAt: assignedAt ?? this.assignedAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}