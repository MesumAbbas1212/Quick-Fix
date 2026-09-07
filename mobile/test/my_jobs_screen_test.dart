import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quickfix/core/widgets/job_image_thumb.dart';
import 'package:quickfix/models/job_model.dart';
import 'package:quickfix/services/job_service.dart';
import 'package:quickfix/services/local_image_store.dart';
import 'package:quickfix/views/jobs/my_jobs_screen.dart';

class MockJobService extends Mock implements JobService {}

class MockImageStore extends Mock implements LocalImageStore {}

/// 1x1 transparent PNG, valid image data for widget preview tests.
final Uint8List _tinyPng = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
  0x89,
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x44, 0x41, 0x54,
  0x78, 0x9C, 0x62, 0x00, 0x01, 0x00, 0x00, 0x05,
  0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4,
  0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44,
  0xAE, 0x42, 0x60, 0x82,
]);

JobModel _job({
  required String id,
  required String title,
  required JobStatus status,
  List<String> images = const [],
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
    images: images,
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

  testWidgets('assigned job can be started by the worker', (tester) async {
    when(() => jobService.watchWorkerJobs('w1')).thenAnswer((_) =>
        Stream.value([
          _job(id: 'a', title: 'AC Repair', status: JobStatus.assigned),
        ]));
    when(() => jobService.updateJobStatus('a', JobStatus.inProgress))
        .thenAnswer((_) async {});

    await pumpMyJobs(tester);

    expect(find.text('Start Job'), findsOneWidget);
    await tester.tap(find.text('Start Job'));
    await tester.pump();

    verify(
      () => jobService.updateJobStatus('a', JobStatus.inProgress),
    ).called(1);
  });

  testWidgets('in-progress job can be completed by the worker',
      (tester) async {
    when(() => jobService.watchWorkerJobs('w1')).thenAnswer((_) =>
        Stream.value([
          _job(id: 'b', title: 'Fan Install', status: JobStatus.inProgress),
        ]));
    when(() => jobService.updateJobStatus('b', JobStatus.completed))
        .thenAnswer((_) async {});

    await pumpMyJobs(tester);

    expect(find.text('Complete Job'), findsOneWidget);
    await tester.tap(find.text('Complete Job'));
    await tester.pump();

    verify(
      () => jobService.updateJobStatus('b', JobStatus.completed),
    ).called(1);
  });

  testWidgets('filter chips scroll horizontally on narrow screens',
      (tester) async {
    // 320 logical px is the smallest common Android viewport.
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    when(() => jobService.watchWorkerJobs('w1')).thenAnswer(
      (_) => Stream.value([
        _job(id: 'a', title: 'AC Repair', status: JobStatus.assigned),
      ]),
    );

    await tester.pumpWidget(MaterialApp(
      home: MyJobsScreen(workerId: 'w1', jobService: jobService),
    ));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Completed'), findsOneWidget);
  });

  testWidgets('job card shows the uploaded photo thumbnail', (tester) async {
    final imageStore = MockImageStore();
    when(() => imageStore.readImage('/data/job_images/pic.jpg'))
        .thenAnswer((_) async => _tinyPng);
    when(() => jobService.watchWorkerJobs('w1')).thenAnswer(
      (_) => Stream.value([
        _job(
          id: 'a',
          title: 'AC Repair',
          status: JobStatus.assigned,
          images: const ['/data/job_images/pic.jpg'],
        ),
      ]),
    );

    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: MyJobsScreen(
        workerId: 'w1',
        jobService: jobService,
        imageStore: imageStore,
      ),
    ));
    await tester.pump();
    await tester.pump();

    expect(find.byType(JobImageThumb), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
  });
}