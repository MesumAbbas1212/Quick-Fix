import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quickfix/models/worker_profile.dart';
import 'package:quickfix/models/job_model.dart';
import 'package:quickfix/models/worker_rank.dart';
import 'package:quickfix/services/job_service.dart';
import 'package:quickfix/services/location_service.dart';
class WorkerComparisonService {
  final JobService? _injectedJobs;
  WorkerComparisonService({JobService? jobService}) : _injectedJobs = jobService;
  late final JobService _jobs = _injectedJobs ?? JobService();
  static bool validSelection(List<WorkerProfile> workers) => workers.length >= 2 && workers.length <= 3 && workers.every((worker) => worker.uid.isNotEmpty) && workers.map((worker) => worker.uid).toSet().length == workers.length;
  Future<int> annualCount(String uid, {DateTime? now}) async {
    final jobs = await _jobs.getCompletedJobsForWorker(uid).timeout(const Duration(seconds: 8));
    return WorkerRank.countCompletedInYear(jobs.where((job) => job.workerId == uid && job.status == JobStatus.completed).map((job) => job.completedAt ?? job.updatedAt), now: now ?? DateTime.now());
  }
  double? distanceKm(WorkerProfile worker, GeoPoint? origin) => LocationService.distanceKm(origin, worker.location);
}
