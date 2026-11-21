import 'package:cloud_firestore/cloud_firestore.dart';

class AdminReportRow {
  final String id;
  final String reason;
  final String details;
  final String status;
  final String reporterId;
  final String reporterName;
  final String reportedId;
  final String reportedName;
  final String? jobId;
  final DateTime? createdAt;
  final String? disputeId;
  final String resolutionNote;
  final String resolvedBy;
  const AdminReportRow({required this.id, required this.reason, required this.details, required this.status, required this.reporterId, required this.reporterName, required this.reportedId, required this.reportedName, this.jobId, this.createdAt, this.disputeId, this.resolutionNote = '', this.resolvedBy = ''});
  factory AdminReportRow.fromMap(String id, Map<String, dynamic> map, {String reporterName = '', String reportedName = ''}) => AdminReportRow(
    id: id, reason: (map['reason'] ?? '').toString(), details: (map['details'] ?? '').toString(), status: (map['status'] ?? 'open').toString(),
    reporterId: (map['reporterId'] ?? '').toString(), reporterName: reporterName,
    reportedId: (map['reportedId'] ?? '').toString(), reportedName: reportedName,
    jobId: map['jobId']?.toString(), disputeId: map['disputeId']?.toString(), resolutionNote: (map['resolutionNote'] ?? '').toString(), resolvedBy: (map['resolvedBy'] ?? '').toString(),
    createdAt: map['createdAt'] is Timestamp ? (map['createdAt'] as Timestamp).toDate() : map['createdAt'] is DateTime ? map['createdAt'] as DateTime : null,
  );
}

class AdminReportDetail {
  final AdminReportRow report;
  final Map<String, dynamic> reporter;
  final Map<String, dynamic> reported;
  final Map<String, dynamic>? job;
  final List<Map<String, dynamic>> recentReviews;
  final int priorReportCount;
  const AdminReportDetail({required this.report, required this.reporter, required this.reported, this.job, this.recentReviews = const [], this.priorReportCount = 0});
}
