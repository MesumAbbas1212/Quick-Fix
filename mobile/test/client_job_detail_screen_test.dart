import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quickfix/models/job_model.dart';
import 'package:quickfix/services/local_image_store.dart';
import 'package:quickfix/services/job_request_service.dart';
import 'package:quickfix/services/job_service.dart';
import 'package:quickfix/services/profile_service.dart';
import 'package:quickfix/models/job_request.dart';
import 'package:quickfix/views/jobs/job_applicants_screen.dart';
import 'package:quickfix/views/client/client_job_detail_screen.dart';
import 'package:quickfix/views/reviews/review_screen.dart';

class MockImageStore extends Mock implements LocalImageStore {}
class MockJobRequestService extends Mock implements JobRequestService {}
class MockJobService extends Mock implements JobService {}
class MockProfileService extends Mock implements ProfileService {}

final Uint8List _validPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);

JobModel _job({
  String id = 'j1',
  JobStatus status = JobStatus.open,
  String? workerId = 'w1',
}) {
  return JobModel(
    id: id,
    userId: 'u1',
    workerId: workerId,
    title: 'AC Repair',
    description: 'Split AC not cooling in bedroom.',
    category: JobCategory.applianceRepair,
    address: 'Model Town, Lahore',
    location: const GeoPoint(31.5, 74.3),
    budgetMin: 2000,
    budgetMax: 3500,
    preferredDate: DateTime.now().add(const Duration(days: 1)),
    status: status,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );
}

void main() {
  late MockImageStore imageStore;

  setUp(() {
    imageStore = MockImageStore();
    when(() => imageStore.readImage(any())).thenAnswer((_) async => null);
  });

  Future<void> pumpDetail(WidgetTester tester, JobModel job) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: ClientJobDetailScreen(
        job: job,
        currentUserId: 'u1',
        imageStore: imageStore,
      ),
    ));
    await tester.pump();
  }

  testWidgets('shows title, description, category and budget', (tester) async {
    await pumpDetail(tester, _job());

    expect(find.text('AC Repair'), findsOneWidget);
    expect(find.text('Split AC not cooling in bedroom.'), findsOneWidget);
    expect(
      find.textContaining('Appliance'),
      findsOneWidget,
    );
    expect(find.textContaining('PKR'), findsWidgets);
  });

  testWidgets('shows status chip for open job', (tester) async {
    await pumpDetail(tester, _job(status: JobStatus.open));

    expect(find.text('Open'), findsOneWidget);
  });

  testWidgets('hides Rate Worker button when job not completed', (tester) async {
    await pumpDetail(tester, _job(status: JobStatus.inProgress));

    expect(find.text('Rate Worker'), findsNothing);
  });

  testWidgets('shows Rate Worker button for completed job', (tester) async {
    await pumpDetail(tester, _job(status: JobStatus.completed));

    expect(find.text('Rate Worker'), findsOneWidget);
  });

  testWidgets('Rate Worker pushes ReviewScreen with worker id', (tester) async {
    await pumpDetail(tester, _job(status: JobStatus.completed));

    await tester.tap(find.text('Rate Worker'));
    await tester.pumpAndSettle();

    expect(find.byType(ReviewScreen), findsOneWidget);
  });

  testWidgets('renders job images from local storage', (tester) async {
    when(() => imageStore.readImage('C:\\jobs\\photo.jpg'))
        .thenAnswer((_) async => _validPng);

    final job = _job();
    final withImages = JobModel(
      id: job.id,
      userId: job.userId,
      workerId: job.workerId,
      title: job.title,
      description: job.description,
      category: job.category,
      address: job.address,
      location: job.location,
      budgetMin: job.budgetMin,
      budgetMax: job.budgetMax,
      preferredDate: job.preferredDate,
      status: job.status,
      images: ['C:\\jobs\\photo.jpg'],
      createdAt: job.createdAt,
      updatedAt: job.updatedAt,
    );

    await pumpDetail(tester, withImages);
    await tester.pumpAndSettle();

    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('applicant entry forwards services and refreshes assignment on return',
      (tester) async {
    final requests = MockJobRequestService();
    final jobs = MockJobService();
    final profiles = MockProfileService();
    when(() => requests.watchPendingCountForJob('j1'))
        .thenAnswer((_) => Stream.value(2));
    when(() => requests.watchUserRequests('u1'))
        .thenAnswer((_) => Stream.value(const <JobRequest>[]));
    when(() => jobs.watchJob('j1'))
        .thenAnswer((_) => Stream<JobModel?>.value(_job(workerId: null)));
    when(() => jobs.getJob('j1'))
        .thenAnswer((_) async => _job(status: JobStatus.assigned));
    tester.view.physicalSize = const Size(400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: ClientJobDetailScreen(
        job: _job(workerId: null), currentUserId: 'u1', imageStore: imageStore,
        jobRequestService: requests, jobService: jobs, profileService: profiles,
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('View 2 applicants'), findsOneWidget);
    await tester.tap(find.byKey(const Key('view-applicants-button')));
    await tester.pumpAndSettle();
    final applicants = tester.widget<JobApplicantsScreen>(find.byType(JobApplicantsScreen));
    expect(applicants.jobId, 'j1');
    expect(applicants.myId, 'u1');
    expect(applicants.jobRequestService, same(requests));
    expect(applicants.jobService, same(jobs));
    expect(applicants.profileService, same(profiles));
    await tester.pageBack();
    await tester.pumpAndSettle();
    verify(() => jobs.getJob('j1')).called(1);
    expect(find.text('Assigned'), findsOneWidget);
    expect(find.text('View confirmed worker'), findsOneWidget);
  });

}
