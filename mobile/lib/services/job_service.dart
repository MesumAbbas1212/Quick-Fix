import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quickfix/models/job_model.dart';

class JobService {
  final FirebaseFirestore _firestore;

  JobService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _jobsCollection =>
      _firestore.collection('jobs');

  // Create a new job
  Future<String> createJob({
    required String userId,
    required String title,
    required String description,
    required JobCategory category,
    required String address,
    required GeoPoint location,
    required double budgetMin,
    required double budgetMax,
    required DateTime preferredDate,
    DateTime? preferredTime,
    List<String> images = const [],
  }) async {
    final jobData = JobModel(
      id: '', // Will be set after creation
      userId: userId,
      title: title,
      description: description,
      category: category,
      address: address,
      location: location,
      budgetMin: budgetMin,
      budgetMax: budgetMax,
      preferredDate: preferredDate,
      preferredTime: preferredTime,
      images: images,
      status: JobStatus.open,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final docRef = await _jobsCollection.add(jobData.toMap());
    return docRef.id;
  }

  // Get job by ID
  Future<JobModel?> getJob(String jobId) async {
    final doc = await _jobsCollection.doc(jobId).get();
    if (!doc.exists) return null;
    return JobModel.fromMap(doc.data()!, doc.id);
  }

  // Live stream of a single job (payment screen, job tracking).
  Stream<JobModel?> watchJob(String jobId) {
    return _jobsCollection
        .doc(jobId)
        .snapshots()
        .map((doc) => doc.exists ? JobModel.fromMap(doc.data()!, doc.id) : null);
  }

  // Update job
  Future<void> updateJob(String jobId, Map<String, dynamic> updates) async {
    updates['updatedAt'] = Timestamp.fromDate(DateTime.now());
    await _jobsCollection.doc(jobId).update(updates);
  }

  // Delete job
  Future<void> deleteJob(String jobId) async {
    await _jobsCollection.doc(jobId).delete();
  }

  // Get jobs for a user (as customer)
  Future<List<JobModel>> getUserJobs(String userId) async {
    final query = await _jobsCollection
        .where('userId', isEqualTo: userId)
        .get();

    final jobs = query.docs
        .map((doc) => JobModel.fromMap(doc.data(), doc.id))
        .toList();
    jobs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return jobs;
  }

  // Get jobs for a worker
  Future<List<JobModel>> getWorkerJobs(String workerId) async {
    final query = await _jobsCollection
        .where('workerId', isEqualTo: workerId)
        .get();

    final jobs = query.docs
        .map((doc) => JobModel.fromMap(doc.data(), doc.id))
        .toList();
    jobs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return jobs;
  }

  // Get open jobs (optionally filtered by category)
  Future<List<JobModel>> getOpenJobs({
    JobCategory? category,
    int limit = 20,
  }) async {
    Query<Map<String, dynamic>> query = _jobsCollection
        .where('status', isEqualTo: JobStatus.open.name);

    if (category != null) {
      query = query.where('category', isEqualTo: category.name);
    }

    final snapshot = await query.limit(limit * 3).get();

    final jobs = snapshot.docs
        .map((doc) => JobModel.fromMap(doc.data(), doc.id))
        .toList();
    jobs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return jobs.take(limit).toList();
  }

  // Assign job to worker. The optional transaction lets applicant selection
  // update the job and all request statuses atomically; existing callers keep
  // the same two-argument API.
  Future<void> assignJob(
    String jobId,
    String workerId, {
    Transaction? transaction,
  }) async {
    final now = Timestamp.fromDate(DateTime.now());
    final updates = <String, dynamic>{
      'workerId': workerId,
      'status': JobStatus.assigned.name,
      'assignedAt': now,
      'updatedAt': now,
    };
    final ref = _jobsCollection.doc(jobId);
    if (transaction != null) {
      transaction.update(ref, updates);
    } else {
      await ref.update(updates);
    }
  }

  // Update job status
  Future<void> updateJobStatus(String jobId, JobStatus status) async {
    final updates = <String, dynamic>{
      'status': status.name,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    };

    // Starting must not overwrite the original acceptance timestamp.
    if (status == JobStatus.completed) {
      updates['completedAt'] = Timestamp.fromDate(DateTime.now());
    }

    await _jobsCollection.doc(jobId).update(updates);
  }

  /// Tracking progression is checked again against the latest server document.
  /// No additional status/fields: travel is not a persisted job state.
  Future<void> advanceJobStatus({
    required String jobId,
    required String workerId,
    required JobStatus status,
  }) async {
    if (status != JobStatus.inProgress && status != JobStatus.completed) {
      throw ArgumentError('Only start and completion are worker transitions.');
    }
    final reference = _jobsCollection.doc(jobId);
    await _firestore.runTransaction<void>((transaction) async {
      final snapshot = await transaction.get(reference);
      final data = snapshot.data();
      if (!snapshot.exists || data == null) throw StateError('Job no longer exists.');
      if (data['workerId'] != workerId) throw StateError('Only the assigned worker can update this job.');
      final current = data['status'];
      if (current == status.name) return; // Safe retry after an acknowledged write.
      final expected = status == JobStatus.inProgress ? JobStatus.assigned : JobStatus.inProgress;
      if (current != expected.name) throw StateError('Job status changed. Please refresh tracking.');
      final timestamp = Timestamp.fromDate(DateTime.now());
      transaction.update(reference, {
        'status': status.name, 'updatedAt': timestamp,
        if (status == JobStatus.completed) 'completedAt': timestamp,
      });
    });
  }

  /// The tracking shortcut only cancels an assigned, not-yet-started job.
  /// B10 owns the fuller reason/rescheduling/notification workflow.
  Future<void> cancelAssignedJob(String jobId, String ownerId) async {
    final reference = _jobsCollection.doc(jobId);
    await _firestore.runTransaction<void>((transaction) async {
      final snapshot = await transaction.get(reference);
      final data = snapshot.data();
      if (!snapshot.exists || data == null) throw StateError('Job no longer exists.');
      if (data['userId'] != ownerId) throw StateError('Only the client can cancel this job.');
      if (data['status'] == JobStatus.cancelled.name) return;
      if (data['status'] != JobStatus.assigned.name) {
        throw StateError('Only an assigned job can be cancelled here.');
      }
      transaction.update(reference, {
        'status': JobStatus.cancelled.name,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    });
  }

  // Rate job
  Future<void> rateJob(String jobId, double rating, String review) async {
    await _jobsCollection.doc(jobId).update({
      'rating': rating,
      'review': review,
      'status': JobStatus.completed.name,
      'completedAt': Timestamp.fromDate(DateTime.now()),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  // Search jobs by text (title/description)
  Future<List<JobModel>> searchJobs(String query, {
    JobCategory? category,
    int limit = 20,
  }) async {
    // Firestore doesn't support full-text search natively
    // This is a basic implementation - in production use Algolia or similar
    Query<Map<String, dynamic>> jobsQuery = _jobsCollection
        .where('status', isEqualTo: JobStatus.open.name);

    if (category != null) {
      jobsQuery = jobsQuery.where('category', isEqualTo: category.name);
    }

    final snapshot = await jobsQuery.limit(limit * 3).get();

    final jobs = snapshot.docs
        .map((doc) => JobModel.fromMap(doc.data(), doc.id))
        .where((job) =>
            job.title.toLowerCase().contains(query.toLowerCase()) ||
            job.description.toLowerCase().contains(query.toLowerCase()))
        .toList();
    jobs.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return jobs.take(limit).toList();
  }

  // Stream of open jobs (real-time)
  Stream<List<JobModel>> watchOpenJobs({
    JobCategory? category,
    int limit = 20,
  }) {
    Query<Map<String, dynamic>> query = _jobsCollection
        .where('status', isEqualTo: JobStatus.open.name);

    if (category != null) {
      query = query.where('category', isEqualTo: category.name);
    }

    return query
        .limit(limit * 3)
        .snapshots()
        .map((snapshot) {
          final jobs = snapshot.docs
              .map((doc) => JobModel.fromMap(doc.data(), doc.id))
              .toList();
          jobs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return jobs.take(limit).toList();
        });
  }

  // Stream of user's jobs
  Stream<List<JobModel>> watchUserJobs(String userId) {
    return _jobsCollection
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
          final jobs = snapshot.docs
              .map((doc) => JobModel.fromMap(doc.data(), doc.id))
              .toList();
          jobs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return jobs;
        });
  }

  // Stream of worker's jobs
  Stream<List<JobModel>> watchWorkerJobs(String workerId) {
    return _jobsCollection
        .where('workerId', isEqualTo: workerId)
        .snapshots()
        .map((snapshot) {
          final jobs = snapshot.docs
              .map((doc) => JobModel.fromMap(doc.data(), doc.id))
              .toList();
          jobs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return jobs;
        });
  }

  // All completed jobs for a worker, newest first (one-shot).
  Future<List<JobModel>> getCompletedJobsForWorker(String workerId) async {
    final query =
        await _jobsCollection.where('workerId', isEqualTo: workerId).get();
    final jobs = query.docs
        .map((doc) => JobModel.fromMap(doc.data(), doc.id))
        .where((job) => job.status == JobStatus.completed)
        .toList();
    jobs.sort((a, b) => _completionTime(b).compareTo(_completionTime(a)));
    return jobs;
  }

  // Live stream of a worker's completed jobs, newest first. Used for the
  // "Work History" section of a worker's public profile.
  Stream<List<JobModel>> watchCompletedJobsForWorker(String workerId) {
    return _jobsCollection
        .where('workerId', isEqualTo: workerId)
        .snapshots()
        .map((snapshot) {
          final jobs = snapshot.docs
              .map((doc) => JobModel.fromMap(doc.data(), doc.id))
              .where((job) => job.status == JobStatus.completed)
              .toList();
          jobs.sort((a, b) => _completionTime(b).compareTo(_completionTime(a)));
          return jobs;
        });
  }

  static DateTime _completionTime(JobModel job) =>
      job.completedAt ?? job.updatedAt;
}
