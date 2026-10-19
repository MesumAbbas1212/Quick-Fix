import 'package:quickfix/services/network_status_service.dart';
import 'package:quickfix/services/notification_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quickfix/models/job_request.dart';
import 'package:quickfix/services/job_service.dart';

class JobRequestService {
  final FirebaseFirestore _firestore;
  final NetworkStatusService _network;

  JobRequestService({FirebaseFirestore? firestore, NetworkStatusService? networkStatusService})
      : _firestore = firestore ?? FirebaseFirestore.instance, _network = networkStatusService ?? NetworkStatusService.instance;

  Future<JobRequest?> getRequest(String id) async {
    final snapshot = await _firestore.collection('jobRequests').doc(id).get().timeout(const Duration(seconds: 8));
    return snapshot.exists ? JobRequest.fromMap(snapshot.data()!, snapshot.id) : null;
  }

  CollectionReference<Map<String, dynamic>> get _requestsCollection =>
      _firestore.collection('jobRequests');

  Stream<JobRequest?> watchRequest(String id) => _requestsCollection.doc(id).snapshots().trackNetwork(status: _network)
    .map((snapshot) => snapshot.exists ? JobRequest.fromMap(snapshot.data()!, snapshot.id) : null);
  Future<void> withdrawRequest({required String requestId, required String workerId}) async {
    final ref = _requestsCollection.doc(requestId);
    await _firestore.runTransaction<void>((transaction) async {
      final data = (await transaction.get(ref)).data();
      if (data == null || data['workerId'] != workerId) { throw StateError('Only the applicant can withdraw.'); }
      if (data['status'] == 'withdrawn') { return; }
      if (data['status'] != 'pending') { throw StateError('An already-decided application cannot be withdrawn.'); }
      final job = (await transaction.get(_firestore.collection('jobs').doc(data['jobId'] as String))).data();
      if (job != null && job['workerId'] == workerId && job['status'] != 'open') { throw StateError('This is an active booking, not a pending request.'); }
      transaction.update(ref, {'status': 'withdrawn', 'respondedAt': FieldValue.serverTimestamp()});
      NotificationService(firestore: _firestore).addToTransaction(transaction, userId: data['userId'] as String, type: 'request', refId: requestId,
        title: 'Application withdrawn', body: 'An applicant withdrew before selection. Other applications remain available.');
    }).timeout(const Duration(seconds: 12));
  }

  // Send a job request from worker to user
  Future<String> sendJobRequest({
    required String jobId,
    required String workerId,
    required String userId,
    String? message,
  }) async {
    final request = JobRequest(
      id: '',
      jobId: jobId,
      workerId: workerId,
      userId: userId,
      status: JobRequestStatus.pending,
      message: message,
      createdAt: DateTime.now(),
    );

    final docRef = await _requestsCollection.add(request.toMap());
    NotificationService(firestore: _firestore).sendBestEffort(userId: userId, type: 'request', refId: docRef.id,
      title: 'New job application', body: 'A worker applied. Open the job to review applicants.');
    return docRef.id;
  }

  // Respond to a job request (accept/decline)
  Future<void> respondToRequest({
    required String requestId,
    required JobRequestStatus status,
    Transaction? transaction,
  }) async {
    final updates = <String, dynamic>{
      'status': status.name,
      'respondedAt': Timestamp.fromDate(DateTime.now()),
    };
    final ref = _requestsCollection.doc(requestId);
    if (transaction != null) {
      transaction.update(ref, updates);
    } else {
      await ref.update(updates);
    }
  }

  /// Selects exactly one applicant and assigns the job in the same commit.
  ///
  /// All requests in the decision snapshot are re-read in the transaction;
  /// a stale/withdrawn application or a job assigned by another device cannot
  /// be accepted. No candidate is declined if assignment fails. Queries
  /// cannot run inside a Firestore mobile transaction, so the reference list
  /// is fetched first, then all document reads precede every write.
  Future<void> acceptApplicant({
    required String jobId,
    required String requestId,
    required String ownerId,
    JobService? jobService,
  }) async {
    final requests =
        await _requestsCollection.where('jobId', isEqualTo: jobId).get();
    final selectedRef = _requestsCollection.doc(requestId);
    final jobRef = _firestore.collection('jobs').doc(jobId);
    final jobs = jobService ?? JobService(firestore: _firestore);
    final otherRefs = requests.docs
        .where((doc) => doc.id != requestId)
        .map((doc) => doc.reference)
        .toList();

    String? selectedWorker;
    await _firestore.runTransaction<void>((transaction) async {
      final job = (await transaction.get(jobRef)).data();
      final selected = (await transaction.get(selectedRef)).data();
      if (job == null || job['userId'] != ownerId) {
        throw StateError('Only the job owner can choose an applicant.');
      }
      if (selected == null ||
          selected['jobId'] != jobId ||
          selected['userId'] != ownerId ||
          selected['workerId'] is! String ||
          (selected['workerId'] as String).isEmpty) {
        throw StateError('The application is no longer available.');
      }
      final workerId = selected['workerId'] as String; selectedWorker = workerId;
      // An acknowledged retry is harmless; never overwrite a different worker.
      if (job['workerId'] == workerId &&
          job['status'] == 'assigned' &&
          selected['status'] == JobRequestStatus.accepted.name) {
        return;
      }
      if (job['status'] != 'open' ||
          selected['status'] != JobRequestStatus.pending.name) {
        throw StateError('The job or application has already changed.');
      }
      final declineIds = <String>[];
      for (final ref in otherRefs) {
        final other = (await transaction.get(ref)).data();
        if (other != null &&
            other['jobId'] == jobId &&
            other['userId'] == ownerId &&
            other['status'] == JobRequestStatus.pending.name) {
          declineIds.add(ref.id);
        }
      }
      await jobs.assignJob(jobId, workerId, transaction: transaction);
      await respondToRequest(
        requestId: requestId,
        status: JobRequestStatus.accepted,
        transaction: transaction,
      );
      for (final id in declineIds) {
        await respondToRequest(
          requestId: id,
          status: JobRequestStatus.declined,
          transaction: transaction,
        );
      }
    });
    if (selectedWorker != null) { NotificationService(firestore: _firestore).sendBestEffort(userId: selectedWorker!, type: 'job', refId: jobId,
      title: 'Job assigned to you', body: 'The client selected your application. Open tracking for the schedule.'); }
  }

  // Get requests for a user (as job owner)
  Stream<List<JobRequest>> watchUserRequests(String userId) {
    return _requestsCollection
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots().trackNetwork(status: _network)
        .map((snapshot) => snapshot.docs
            .map((doc) => JobRequest.fromMap(doc.data(), doc.id))
            .toList());
  }

  // Get requests sent by a worker
  Stream<List<JobRequest>> watchWorkerRequests(String workerId) {
    return _requestsCollection
        .where('workerId', isEqualTo: workerId)
        .orderBy('createdAt', descending: true)
        .snapshots().trackNetwork(status: _network)
        .map((snapshot) => snapshot.docs
            .map((doc) => JobRequest.fromMap(doc.data(), doc.id))
            .toList());
  }

  // Check if a worker has already requested a job
  Future<JobRequest?> getExistingRequest({
    required String jobId,
    required String workerId,
  }) async {
    final snap = await _requestsCollection
        .where('jobId', isEqualTo: jobId)
        .where('workerId', isEqualTo: workerId)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) { return null; }
    return JobRequest.fromMap(snap.docs.first.data(), snap.docs.first.id);
  }

  // Count pending requests for a user
  Stream<int> watchPendingCount(String userId) {
    return _requestsCollection
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: JobRequestStatus.pending.name)
        .snapshots().trackNetwork(status: _network)
        .map((snapshot) => snapshot.docs.length);
  }

  // Count pending applicants for one job (the "View N applicants" chip).
  Stream<int> watchPendingCountForJob(String jobId) {
    return _requestsCollection
        .where('jobId', isEqualTo: jobId)
        .where('status', isEqualTo: JobRequestStatus.pending.name)
        .snapshots().trackNetwork(status: _network)
        .map((snapshot) => snapshot.docs.length);
  }
}
