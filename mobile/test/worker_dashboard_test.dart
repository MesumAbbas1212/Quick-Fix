import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quickfix/models/job_model.dart';
import 'package:quickfix/models/user_model.dart';
import 'package:quickfix/services/job_service.dart';
import 'package:quickfix/views/jobs/job_request_screen.dart';
import 'package:quickfix/views/jobs/worker_dashboard_screen.dart';

class MockJobService extends Mock implements JobService {}

UserModel _worker() {
  return UserModel(
    uid: 'w1',
    email: 'worker@quickfix.test',
    fullName: 'Imran Worker',
    phone: '03001234567',
    role: UserRole.worker,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );
}

JobModel _job({String id = 'j1', String title = 'AC Repair'}) {
  return JobModel(
    id: id,
    userId: 'u1',
    title: title,
    description: 'Split AC not cooling',
    category: JobCategory.applianceRepair,
    address: 'Model Town, Lahore',
    location: const GeoPoint(31.5204, 74.3587),
    budgetMin: 2000,
    budgetMax: 3500,
    preferredDate: DateTime.now().add(const Duration(days: 1)),
    status: JobStatus.open,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );
}

void main() {
  late MockJobService jobService;

  setUp(() {
    jobService = MockJobService();
  });

  Future<void> pumpDashboard(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: WorkerDashboardScreen(
        user: _worker(),
        jobService: jobService,
      ),
    ));
    await tester.pump();
  }

  testWidgets('suggested jobs stream from JobService', (tester) async {
    when(() => jobService.watchOpenJobs())
        .thenAnswer((_) => Stream.value([_job()]));

    await pumpDashboard(tester);

    expect(find.text('AC Repair'), findsOneWidget);
  });

  testWidgets('accepting a job assigns it to the worker', (tester) async {
    when(() => jobService.watchOpenJobs())
        .thenAnswer((_) => Stream.value([_job()]));
    when(() => jobService.assignJob('j1', 'w1')).thenAnswer((_) async {});

    await pumpDashboard(tester);

    await tester.tap(find.text('AC Repair'));
    await tester.pumpAndSettle();
    expect(find.byType(JobRequestScreen), findsOneWidget);

    await tester.tap(find.text('Accept Job'));
    await tester.pumpAndSettle();

    verify(() => jobService.assignJob('j1', 'w1')).called(1);
    expect(find.byType(JobRequestScreen), findsNothing);
  });
}