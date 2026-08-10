import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quickfix/models/job_request.dart';

class JobRequestService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _requestsCollection =>
      _firestore.collection('jobRequests');

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
    return docRef.id;
  }

  // Respond to a job request (accept/decline)
  Future<void> respondToRequest({
    required String requestId,
    required JobRequestStatus status,
  }) async {
    await _requestsCollection.doc(requestId).update({
      'status': status.name,
      'respondedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  // Get requests for a user (as job owner)
  Stream<List<JobRequest>> watchUserRequests(String userId) {
    return _requestsCollection
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => JobRequest.fromMap(doc.data(), doc.id))
            .toList());
  }

  // Get requests sent by a worker
  Stream<List<JobRequest>> watchWorkerRequests(String workerId) {
    return _requestsCollection
        .where('workerId', isEqualTo: workerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
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

    if (snap.docs.isEmpty) return null;
    return JobRequest.fromMap(snap.docs.first.data(), snap.docs.first.id);
  }

  // Count pending requests for a user
  Stream<int> watchPendingCount(String userId) {
    return _requestsCollection
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: JobRequestStatus.pending.name)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }
}