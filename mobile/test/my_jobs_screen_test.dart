import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quickfix/models/job_model.dart';
import 'package:quickfix/services/job_service.dart';
import 'package:quickfix/views/jobs/my_jobs_screen.dart';

class MockJobService extends Mock implements JobService {}

JobModel _job({
  required String id,
  required String title,
  required JobStatus status,
}) {
  return JobModel(
    id: id,
    userId: 'u1',
    workerId: 'w1',
    title: title,
    description: 'Test job',
    category: JobCategory.plumbing,
    address: 'Model Town, Lahore',
    location: const GeoPoint(31.5204, 74.3587),
    budgetMin: 1000,
    budgetMax: 2000,
    preferredDate: DateTime.now(),
    status: status,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );
}

void main() {
  late MockJobService jobService;

  setUp(() {
    jobService = MockJobService();
  });

  Future<void> pumpMyJobs(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: MyJobsScreen(workerId: 'w1', jobService: jobService),
    ));
    await tester.pump();
  }

  testWidgets('lists worker jobs from stream', (tester) async {
    when(() => jobService.watchWorkerJobs('w1')).thenAnswer(
      (_) => Stream.value([
        _job(id: 'a', title: 'AC Repair', status: JobStatus.assigned),
        _job(id: 'b', title: 'Fan Install', status: JobStatus.completed),
      ]),
    );

    await pumpMyJobs(tester);

    expect(find.text('AC Repair'), findsOneWidget);
    expect(find.text('Fan Install'), findsOneWidget);
  });

  testWidgets('status filters apply to streamed jobs', (tester) async {
    when(() => jobService.watchWorkerJobs('w1')).thenAnswer(
      (_) => Stream.value([
        _job(id: 'a', title: 'AC Repair', status: JobStatus.assigned),
        _job(id: 'b', title: 'Fan Install', status: JobStatus.completed),
      ]),
    );

    await pumpMyJobs(tester);
    await tester.tap(find.text('Completed'));
    await tester.pumpAndSettle();

    expect(find.text('AC Repair'), findsNothing);
    expect(find.text('Fan Install'), findsOneWidget);
  });

  testWidgets('shows empty state when no jobs', (tester) async {
    when(() => jobService.watchWorkerJobs('w1'))
        .thenAnswer((_) => Stream.value(const <JobModel>[]));

    await pumpMyJobs(tester);

    expect(find.text('No jobs found'), findsOneWidget);
  });
}