import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quickfix/models/job_model.dart';

class JobService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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

  // Assign job to worker
  Future<void> assignJob(String jobId, String workerId) async {
    await _jobsCollection.doc(jobId).update({
      'workerId': workerId,
      'status': JobStatus.assigned.name,
      'assignedAt': Timestamp.fromDate(DateTime.now()),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  // Update job status
  Future<void> updateJobStatus(String jobId, JobStatus status) async {
    final updates = <String, dynamic>{
      'status': status.name,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    };

    if (status == JobStatus.inProgress) {
      updates['assignedAt'] = Timestamp.fromDate(DateTime.now());
    } else if (status == JobStatus.completed) {
      updates['completedAt'] = Timestamp.fromDate(DateTime.now());
    }

    await _jobsCollection.doc(jobId).update(updates);
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
}