import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quickfix/core/utils/offline_cache.dart';
import 'package:quickfix/models/job_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

JobModel _job() {
  return JobModel(
    id: 'job1',
    userId: 'u1',
    workerId: 'w1',
    title: 'AC Repair',
    description: 'Split AC not cooling',
    category: JobCategory.applianceRepair,
    address: 'Model Town, Lahore',
    location: const GeoPoint(31.52, 74.35),
    budgetMin: 2000,
    budgetMax: 3500,
    preferredDate: DateTime(2024, 6, 10),
    status: JobStatus.open,
    createdAt: DateTime(2024, 6, 1),
    updatedAt: DateTime(2024, 6, 2),
    assignedAt: DateTime(2024, 6, 3),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('caches and restores jobs with GeoPoint locations', () async {
    final cache = OfflineCache();
    await cache.cacheJobs([_job()]);

    final jobs = await cache.readCachedJobs();

    expect(jobs, hasLength(1));
    final job = jobs.first;
    expect(job.id, 'job1');
    expect(job.title, 'AC Repair');
    expect(job.category, JobCategory.applianceRepair);
    expect(job.location.latitude, closeTo(31.52, 0.001));
    expect(job.location.longitude, closeTo(74.35, 0.001));
    expect(job.status, JobStatus.open);
    expect(job.budgetMax, 3500);
    expect(job.assignedAt, DateTime(2024, 6, 3));
  });

  test('returns empty list when nothing cached', () async {
    final cache = OfflineCache();
    expect(await cache.readCachedJobs(), isEmpty);
  });
}
