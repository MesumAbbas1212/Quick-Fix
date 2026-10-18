import 'package:cloud_firestore/cloud_firestore.dart';

/// Writes user reports (`reports` collection) and guards against duplicate
/// open reports from the same reporter against the same target.
class ReportService {
  final FirebaseFirestore _firestore;

  ReportService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _reportsCollection =>
      _firestore.collection('reports');

  /// Creates an open report. [reportedId] is the uid of the user/worker
  /// being reported; [jobId] is optional context.
  Future<void> submitReport({
    required String reporterId,
    required String reportedId,
    required String reason,
    String? jobId,
    String? details,
  }) async {
    final report = <String, dynamic>{
      'reporterId': reporterId,
      'reportedId': reportedId,
      'reason': reason,
      'status': 'open',
      'createdAt': Timestamp.fromDate(DateTime.now()),
    };
    if (jobId != null) report['jobId'] = jobId;
    if (details != null && details.trim().isNotEmpty) {
      report['details'] = details.trim();
    }
    await _reportsCollection.add(report);
  }

  /// True when [reporterId] already has an open report against
  /// [reportedId] — used to block duplicate reports.
  Future<bool> hasOpenReport(String reporterId, String reportedId) async {
    final snap = await _reportsCollection
        .where('reporterId', isEqualTo: reporterId)
        .where('reportedId', isEqualTo: reportedId)
        .where('status', isEqualTo: 'open')
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }
}
