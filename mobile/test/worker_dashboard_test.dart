import 'package:quickfix/services/job_request_service.dart';
import 'package:quickfix/models/worker_verification.dart';
import 'package:quickfix/views/worker/verification_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quickfix/models/job_model.dart';
import 'package:quickfix/models/user_model.dart';
import 'package:quickfix/models/worker_profile.dart';
import 'package:quickfix/services/auth_service.dart';
import 'package:quickfix/services/job_service.dart';
import 'package:quickfix/services/profile_service.dart';
import 'package:quickfix/views/jobs/job_request_screen.dart';
import 'package:quickfix/views/jobs/worker_dashboard_screen.dart';

class MockJobService extends Mock implements JobService {}
class MockRequestService extends Mock implements JobRequestService {}

class MockProfileService extends Mock implements ProfileService {}

class MockAuthService extends Mock implements AuthService {}

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

WorkerProfile _profile({bool isAvailable = true}) {
  return WorkerProfile(
    uid: 'w1',
    fullName: 'Imran Worker',
    email: 'worker@quickfix.test',
    isAvailable: isAvailable,
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
  late MockRequestService requestService;
  late MockProfileService profileService;

  setUp(() {
    jobService = MockJobService(); requestService = MockRequestService();
    when(() => requestService.getExistingRequest(jobId: any(named: 'jobId'), workerId: any(named: 'workerId'))).thenAnswer((_) async => null);
    when(() => requestService.sendJobRequest(jobId: any(named: 'jobId'), workerId: any(named: 'workerId'), userId: any(named: 'userId'))).thenAnswer((_) async => 'request');
    profileService = MockProfileService();
    when(() => jobService.watchOpenJobs())
        .thenAnswer((_) => Stream.value(const <JobModel>[]));
  });

  Future<void> pumpDashboard(
    WidgetTester tester, {
    WorkerProfile? profile,
  }) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: WorkerDashboardScreen(
        user: _worker(),
        workerProfile: profile,
        jobService: jobService,
        requestService: requestService,
        profileService: profileService,
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

  testWidgets('applying sends a request without self-assigning the worker', (tester) async {
    when(() => jobService.watchOpenJobs())
        .thenAnswer((_) => Stream.value([_job()]));
    when(() => requestService.sendJobRequest(jobId: 'j1', workerId: 'w1', userId: 'u1')).thenAnswer((_) async => 'request');

    await pumpDashboard(tester);

    await tester.tap(find.text('AC Repair'));
    await tester.pumpAndSettle();
    expect(find.byType(JobRequestScreen), findsOneWidget);

    await tester.tap(find.text('Apply for job'));
    await tester.pumpAndSettle();

    verify(() => requestService.sendJobRequest(jobId: 'j1', workerId: 'w1', userId: 'u1')).called(1);
    verifyNever(() => jobService.assignJob('j1', 'w1'));
    expect(find.byType(JobRequestScreen), findsNothing);
  });

  testWidgets('accepting a job does not pop the dashboard (single pop)',
      (tester) async {
    // Regression: onAccept used to pop a second time, removing the app
    // shell and leaving a black screen.
    when(() => jobService.watchOpenJobs())
        .thenAnswer((_) => Stream.value([_job()]));
    when(() => requestService.sendJobRequest(jobId: 'j1', workerId: 'w1', userId: 'u1')).thenAnswer((_) async => 'request');

    final rootKey = GlobalKey();
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      key: rootKey,
      home: WorkerDashboardScreen(
        user: _worker(),
        jobService: jobService,
        requestService: requestService,
        profileService: profileService,
      ),
    ));
    await tester.pump();

    await tester.tap(find.text('AC Repair'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Apply for job'));
    await tester.pumpAndSettle();

    expect(find.byType(WorkerDashboardScreen), findsOneWidget);
    expect(find.byType(MaterialApp), findsOneWidget);
  });

  testWidgets('job request shows the real client profile when available',
      (tester) async {
    final auth = MockAuthService();
    when(() => jobService.watchOpenJobs())
        .thenAnswer((_) => Stream.value([_job()]));
    when(() => auth.getUserProfile('u1')).thenAnswer((_) async => UserModel(
          uid: 'u1',
          email: 'client@quickfix.test',
          fullName: 'Sara Client',
          phone: '03211234567',
          role: UserRole.user,
          rating: 3.2,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ));

    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: WorkerDashboardScreen(
        user: _worker(),
        jobService: jobService,
        requestService: requestService,
        profileService: profileService,
        authService: auth,
      ),
    ));
    await tester.pump();

    await tester.tap(find.text('AC Repair'));
    await tester.pumpAndSettle();

    expect(find.text('Sara Client'), findsOneWidget);
  });

  testWidgets('availability pill reflects worker profile', (tester) async {
    await pumpDashboard(tester, profile: _profile(isAvailable: false));

    expect(find.text('Busy'), findsOneWidget);
  });

  testWidgets('toggling availability persists to profile', (tester) async {
    when(() => profileService.setAvailability('w1', any()))
        .thenAnswer((_) async {});

    await pumpDashboard(tester);
    expect(find.text('Available'), findsOneWidget);

    await tester.tap(find.text('Available'));
    await tester.pump();

    verify(() => profileService.setAvailability('w1', false)).called(1);
    expect(find.text('Busy'), findsOneWidget);
  });
  testWidgets('unverified dashboard opens verification and verified workers do not see the nudge', (tester) async {
    await pumpDashboard(tester, profile: _profile());
    expect(find.byKey(const Key('dashboard-verification')), findsOneWidget);
    await tester.tap(find.byKey(const Key('dashboard-verification'))); await tester.pumpAndSettle();
    expect(find.byType(VerificationScreen), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await pumpDashboard(tester, profile: _profile().copyWith(verification: const VerificationSummary(status: VerificationStatus.verified)));
    expect(find.byKey(const Key('dashboard-verification')), findsNothing);
  });

}