import 'package:cloud_firestore/cloud_firestore.dart';

enum JobRequestStatus {
  pending,
  accepted,
  declined,
}

class JobRequest {
  final String id;
  final String jobId;
  final String workerId;
  final String userId;
  final JobRequestStatus status;
  final String? message;
  final DateTime createdAt;
  final DateTime? respondedAt;

  JobRequest({
    required this.id,
    required this.jobId,
    required this.workerId,
    required this.userId,
    this.status = JobRequestStatus.pending,
    this.message,
    required this.createdAt,
    this.respondedAt,
  });

  factory JobRequest.fromMap(Map<String, dynamic> map, String id) {
    return JobRequest(
      id: id,
      jobId: map['jobId'] ?? '',
      workerId: map['workerId'] ?? '',
      userId: map['userId'] ?? '',
      status: JobRequestStatus.values.firstWhere(
        (s) => s.name == map['status'],
        orElse: () => JobRequestStatus.pending,
      ),
      message: map['message'],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      respondedAt: (map['respondedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'jobId': jobId,
      'workerId': workerId,
      'userId': userId,
      'status': status.name,
      'message': message,
      'createdAt': Timestamp.fromDate(createdAt),
      'respondedAt': respondedAt != null ? Timestamp.fromDate(respondedAt!) : null,
    };
  }

  JobRequest copyWith({
    String? id,
    String? jobId,
    String? workerId,
    String? userId,
    JobRequestStatus? status,
    String? message,
    DateTime? createdAt,
    DateTime? respondedAt,
  }) {
    return JobRequest(
      id: id ?? this.id,
      jobId: jobId ?? this.jobId,
      workerId: workerId ?? this.workerId,
      userId: userId ?? this.userId,
      status: status ?? this.status,
      message: message ?? this.message,
      createdAt: createdAt ?? this.createdAt,
      respondedAt: respondedAt ?? this.respondedAt,
    );
  }
}