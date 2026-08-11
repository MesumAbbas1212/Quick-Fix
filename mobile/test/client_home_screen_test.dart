import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quickfix/models/job_model.dart';
import 'package:quickfix/models/user_model.dart';
import 'package:quickfix/services/job_service.dart';
import 'package:quickfix/views/client/client_home_screen.dart';
import 'package:quickfix/views/jobs/post_job_screen.dart';

class MockJobService extends Mock implements JobService {}

UserModel _user() {
  return UserModel(
    uid: 'u1',
    email: 'client@quickfix.com',
    fullName: 'Ahmed Ali',
    phone: '03001234567',
    role: UserRole.user,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );
}

JobModel _job({
  String id = 'j1',
  JobStatus status = JobStatus.open,
}) {
  return JobModel(
    id: id,
    userId: 'u1',
    title: 'AC Repair',
    description: 'Split AC not cooling',
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
  late MockJobService jobService;

  setUp(() {
    jobService = MockJobService();
    when(() => jobService.watchUserJobs('u1'))
        .thenAnswer((_) => Stream.value(<JobModel>[]));
  });

  Future<void> pumpHome(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: ClientHomeScreen(user: _user(), jobService: jobService),
    ));
    await tester.pump();
  }

  testWidgets('greets the client by first name', (tester) async {
    await pumpHome(tester);

    expect(find.textContaining('Ahmed'), findsWidgets);
    expect(find.text('Hi, Ahmed!'), findsOneWidget);
  });

  testWidgets('shows Post a Job hero and pushes PostJobScreen', (tester) async {
    await pumpHome(tester);

    expect(find.text('Post a Job'), findsWidgets);
    await tester.tap(find.byKey(const Key('post-job-cta')));
    await tester.pumpAndSettle();

    expect(find.byType(PostJobScreen), findsOneWidget);
  });

  testWidgets('lists my posted jobs from the service stream', (tester) async {
    when(() => jobService.watchUserJobs('u1'))
        .thenAnswer((_) => Stream.value([_job()]));

    await pumpHome(tester);

    expect(find.text('AC Repair'), findsOneWidget);
    expect(find.text('Open'), findsOneWidget);
    expect(find.textContaining('PKR'), findsOneWidget);
  });

  testWidgets('shows status chip for in-progress job', (tester) async {
    when(() => jobService.watchUserJobs('u1'))
        .thenAnswer((_) => Stream.value([_job(id: 'j2', status: JobStatus.inProgress)]));

    await pumpHome(tester);

    expect(find.text('In Progress'), findsOneWidget);
  });

  testWidgets('shows empty state when no jobs posted', (tester) async {
    await pumpHome(tester);

    expect(find.text('No jobs posted yet'), findsOneWidget);
  });
}
