import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:quickfix/models/admin_account_row.dart';
import 'package:quickfix/models/admin_account_detail.dart';
import 'package:quickfix/models/admin_counts.dart';
import 'package:quickfix/models/admin_report_row.dart';

class AdminService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  AdminService({FirebaseFirestore? firestore, FirebaseAuth? auth}) : _firestore = firestore ?? FirebaseFirestore.instance, _auth = auth ?? FirebaseAuth.instance;

  Future<int> _count(String collection, {String? field, Object? equals}) async {
    Query<Map<String, dynamic>> query = _firestore.collection(collection);
    if (field != null) query = query.where(field, isEqualTo: equals);
    final result = await query.count().get();
    return result.count ?? 0;
  }

  Future<AdminCounts> counts() async {
    final values = await Future.wait([_count('users'), _count('workers'), _count('jobs'), openReportsCount()]);
    return AdminCounts(users: values[0], workers: values[1], jobs: values[2], openReports: values[3]);
  }

  Future<int> openReportsCount() => _count('reports', field: 'status', equals: 'open');

  Stream<List<AdminReportRow>> watchReports({int limit = 50}) => _firestore.collection('reports')
      .orderBy('createdAt', descending: true).limit(limit).snapshots().asyncMap((snapshot) async {
        return Future.wait(snapshot.docs.map((doc) async {
          final data = doc.data();
          final reporter = (data['reporterId'] ?? '').toString();
          final reported = (data['reportedId'] ?? '').toString();
          final names = await Future.wait([_displayName(reporter), _displayName(reported)]);
          return AdminReportRow.fromMap(doc.id, data, reporterName: names[0], reportedName: names[1]);
        }));
      });

  Future<AdminReportDetail?> reportDetail(String reportId) async {
    final snapshot = await _firestore.collection('reports').doc(reportId).get();
    if (!snapshot.exists) return null;
    final data = snapshot.data()!;
    final reporterId = (data['reporterId'] ?? '').toString();
    final reportedId = (data['reportedId'] ?? '').toString();
    final reporterFuture = _profile(reporterId);
    final reportedFuture = _personWithWorker(reportedId);
    final reporterReportsFuture = _firestore.collection('reports').where('reporterId', isEqualTo: reportedId).limit(20).get();
    final targetReportsFuture = _firestore.collection('reports').where('reportedId', isEqualTo: reportedId).limit(20).get();
    final results = await Future.wait([reporterFuture, reportedFuture, reporterReportsFuture, targetReportsFuture]);
    final reporter = results[0] as Map<String, dynamic>;
    final reported = results[1] as Map<String, dynamic>;
    final priorCount = ((results[2] as QuerySnapshot<Map<String, dynamic>>).size + (results[3] as QuerySnapshot<Map<String, dynamic>>).size - 1).clamp(0, 100000).toInt();
    Map<String, dynamic>? job;
    final jobId = data['jobId']?.toString();
    if (jobId != null && jobId.isNotEmpty) {
      final jobDoc = await _firestore.collection('jobs').doc(jobId).get();
      if (jobDoc.exists) job = {'id': jobDoc.id, ...?jobDoc.data()};
    }
    final reviewsSnapshot = await _firestore.collection('reviews').where('workerId', isEqualTo: reportedId).limit(5).get();
    final reviews = reviewsSnapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList(growable: false);
    final row = AdminReportRow.fromMap(snapshot.id, data, reporterName: (reporter['fullName'] ?? '').toString(), reportedName: (reported['fullName'] ?? '').toString());
    return AdminReportDetail(report: row, reporter: reporter, reported: reported, job: job, recentReviews: reviews, priorReportCount: priorCount);
  }

  Future<Map<String, dynamic>> _profile(String uid) async {
    if (uid.isEmpty) return const {};
    final user = await _firestore.collection('users').doc(uid).get();
    if (user.exists) return user.data()!;
    final worker = await _firestore.collection('workers').doc(uid).get();
    return worker.exists ? worker.data()! : const {};
  }

  Future<Map<String, dynamic>> _personWithWorker(String uid) async {
    if (uid.isEmpty) return const {};
    final results = await Future.wait([_firestore.collection('users').doc(uid).get(), _firestore.collection('workers').doc(uid).get()]);
    final user = results[0] as DocumentSnapshot<Map<String, dynamic>>;
    final worker = results[1] as DocumentSnapshot<Map<String, dynamic>>;
    return {...?user.data(), ...?worker.data()};
  }

  Future<String> _displayName(String uid) async => (await _profile(uid))['fullName']?.toString() ?? '';

  Future<void> resolveReport({required String reportId, required String status, required String note, required String resolvedBy}) async {
    if (!const {'resolved', 'dismissed'}.contains(status)) throw ArgumentError.value(status, 'status');
    final operation = _firestore.runTransaction<void>((transaction) async {
      final reportRef = _firestore.collection('reports').doc(reportId);
      final report = await transaction.get(reportRef);
      if (!report.exists) throw StateError('Report no longer exists.');
      final data = report.data()!;
      if (data['status'] != 'open') throw StateError('This report has already been decided. Refresh before retrying.');
      final disputeId = data['disputeId']?.toString();
      DocumentSnapshot<Map<String, dynamic>>? dispute;
      DocumentReference<Map<String, dynamic>>? disputeRef;
      if (disputeId != null && disputeId.isNotEmpty) {
        disputeRef = _firestore.collection('disputes').doc(disputeId);
        dispute = await transaction.get(disputeRef);
        if (dispute.exists) {
          final disputeData = dispute.data()!;
          if (disputeData['raisedBy'] != data['reporterId'] || disputeData['againstId'] != data['reportedId'] || disputeData['jobId'] != data['jobId']) {
            throw StateError('Linked case does not match this report; operator review is required.');
          }
        }
      }
      final now = FieldValue.serverTimestamp();
      transaction.update(reportRef, {'status': status, 'resolutionNote': note.trim(), 'resolvedAt': now, 'resolvedBy': resolvedBy, 'updatedAt': now});
      if (disputeRef != null && dispute?.exists == true) transaction.update(disputeRef, {'status': status, 'resolutionNote': note.trim(), 'reviewedAt': now, 'reviewedBy': resolvedBy});
    });
    final timeout = Completer<void>();
    final timer = Timer(const Duration(seconds: 12), () => timeout.completeError(TimeoutException('Resolution was not confirmed. Refresh before retrying.')));
    try {
      await Future.any([operation, timeout.future]);
    } finally { timer.cancel(); }
  }

  Stream<List<AdminAccountRow>> watchUsers({int limit = 50}) => _firestore.collection('users').orderBy('createdAt', descending: true).limit(limit).snapshots().map((snapshot) => snapshot.docs
      .where((doc) => doc.data()['role'] == 'user')
      .map((doc) => AdminAccountRow.fromMaps(doc.id, doc.data())).toList(growable: false));

  Stream<List<AdminAccountRow>> watchWorkers({int limit = 50}) => _firestore.collection('workers').orderBy('createdAt', descending: true).limit(limit).snapshots().asyncMap((snapshot) async {
    return Future.wait(snapshot.docs.map((doc) async {
      final user = await _firestore.collection('users').doc(doc.id).get();
      final cutoff = Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 365)));
      final completed = await _firestore.collection('jobs').where('workerId', isEqualTo: doc.id).where('status', isEqualTo: 'completed').where('completedAt', isGreaterThanOrEqualTo: cutoff).count().get();
      return AdminAccountRow.fromMaps(doc.id, user.data() ?? const {}, worker: doc.data(), completedInYear: completed.count ?? 0);
    }));
  });

  Stream<List<AdminAccountRow>> watchPendingVerifications({int limit = 5}) => _firestore.collection('workers')
      .where('verification.status', isEqualTo: 'pending').orderBy('createdAt', descending: true).limit(limit).snapshots().asyncMap((snapshot) async => Future.wait(snapshot.docs.map((doc) async {
        final user = await _firestore.collection('users').doc(doc.id).get();
        return AdminAccountRow.fromMaps(doc.id, user.data() ?? const {}, worker: doc.data());
      })));

  Future<AdminAccountDetail?> accountDetail(String uid, {bool worker = false}) async {
    final userFuture = _firestore.collection('users').doc(uid).get();
    final workerFuture = _firestore.collection('workers').doc(uid).get();
    final results = await Future.wait([userFuture, workerFuture]);
    final userSnapshot = results[0] as DocumentSnapshot<Map<String, dynamic>>;
    final workerSnapshot = results[1] as DocumentSnapshot<Map<String, dynamic>>;
    if (!userSnapshot.exists && !workerSnapshot.exists) return null;
    final userData = userSnapshot.data() ?? const <String, dynamic>{};
    final workerData = workerSnapshot.data();
    final jobsQuery = _firestore.collection('jobs').where(worker ? 'workerId' : 'userId', isEqualTo: uid).orderBy('createdAt', descending: true).limit(10).get();
    final reviewsQuery = _firestore.collection('reviews').where(worker ? 'workerId' : 'reviewerId', isEqualTo: uid).orderBy('createdAt', descending: true).limit(5).get();
    final verificationQuery = worker ? _firestore.collection('workerVerifications').doc(uid).get() : Future.value(null);
    final detailResults = await Future.wait([jobsQuery, reviewsQuery, verificationQuery]);
    final jobs = (detailResults[0] as QuerySnapshot<Map<String, dynamic>>).docs.map((doc) => {'id': doc.id, ...doc.data()}).toList(growable: false);
    final reviews = (detailResults[1] as QuerySnapshot<Map<String, dynamic>>).docs.map((doc) => {'id': doc.id, ...doc.data()}).toList(growable: false);
    final verificationSnapshot = detailResults[2] as DocumentSnapshot<Map<String, dynamic>>?;
    return AdminAccountDetail(account: AdminAccountRow.fromMaps(uid, userData, worker: workerData), userData: userData, workerData: workerData,
      jobs: jobs, reviews: reviews, verification: verificationSnapshot?.data());
  }

  Future<void> setUserBlocked(String uid, bool blocked) => _firestore.collection('users').doc(uid).update({'blocked': blocked, 'updatedAt': FieldValue.serverTimestamp()});
  Future<void> setWorkerApproved(String uid, bool approved) => _firestore.collection('workers').doc(uid).update({'approved': approved, 'updatedAt': FieldValue.serverTimestamp()});
  Future<void> setWorkerBlocked(String uid, bool blocked) => _firestore.collection('workers').doc(uid).update({'blocked': blocked, 'updatedAt': FieldValue.serverTimestamp()});

  Future<void> reviewVerification(String uid, String decision, {String? note}) async {
    if (!const {'verified', 'rejected'}.contains(decision)) throw ArgumentError.value(decision, 'decision');
    if (decision == 'rejected' && (note == null || note.trim().isEmpty)) throw ArgumentError('A rejection reason is required.');
    final verificationRef = _firestore.collection('workerVerifications').doc(uid);
    final workerRef = _firestore.collection('workers').doc(uid);
    await _firestore.runTransaction<void>((transaction) async {
      final proof = await transaction.get(verificationRef);
      final worker = await transaction.get(workerRef);
      if (!proof.exists || !worker.exists) throw StateError('This worker has no submitted verification.');
      final data = proof.data()!;
      if (data['status'] != 'pending' && data['status'] != 'verified') throw StateError('Only a pending request or an existing verification can be reviewed. Refresh the list.');
      if (decision == 'verified' && (data['consent'] != true || data['cnicFrontPath'] == null || data['cnicBackPath'] == null || data['selfiePath'] == null || data['submittedAt'] == null)) {
        throw StateError('The request is incomplete; do not mark it verified.');
      }
      final now = FieldValue.serverTimestamp();
      final reviewer = _auth.currentUser?.uid;
      if (reviewer == null) throw StateError('Sign in again before reviewing.');
      transaction.update(verificationRef, {'status': decision, 'note': note?.trim() ?? '', 'reviewedAt': now, 'reviewedBy': reviewer, 'reviewMethod': 'manual-external'});
      transaction.update(workerRef, {'verification': {'status': decision, 'submittedAt': data['submittedAt'], 'reviewedAt': now}, 'updatedAt': now});
    });
  }

  Future<void> cancelJob(String jobId, String reason) async {
    if (reason.trim().isEmpty) throw ArgumentError('A cancellation reason is required.');
    await _firestore.collection('jobs').doc(jobId).update({'status': 'cancelled', 'cancelReason': reason.trim(), 'cancelledAt': FieldValue.serverTimestamp(), 'updatedAt': FieldValue.serverTimestamp()});
  }
}
