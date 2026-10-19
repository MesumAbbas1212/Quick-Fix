import 'helpers/visible.dart' as test_viewport;
import 'package:quickfix/services/job_request_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quickfix/core/theme/app_theme.dart';
import 'package:quickfix/models/job_model.dart';
import 'package:quickfix/models/user_model.dart';
import 'package:quickfix/services/job_service.dart';
import 'package:quickfix/views/jobs/job_request_screen.dart';

class MockJobService extends Mock implements JobService {}
class MockRequestService extends Mock implements JobRequestService {}

JobModel _buildJob() {
  return JobModel(
    id: 'job-1',
    userId: 'user-1',
    title: 'Fix leaking kitchen faucet',
    description: 'Dripping tap under the sink needs a new washer.',
    category: JobCategory.plumbing,
    address: 'Model Town, Lahore',
    location: const GeoPoint(31.5204, 74.3587),
    budgetMin: 1500,
    budgetMax: 2800,
    preferredDate: DateTime(2026, 8, 15),
    preferredTime: DateTime(2026, 8, 15, 10, 0),
    images: const [],
    status: JobStatus.open,
    rating: null,
    createdAt: DateTime(2026, 8, 10),
    updatedAt: DateTime(2026, 8, 10),
  );
}

void main() {
  testWidgets('accept button is green and decline is red', (tester) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: JobRequestScreen(job: _buildJob()),
    ));

    final accept = tester.widget<ElevatedButton>(find.widgetWithText(
        ElevatedButton, 'Apply for job'));
    final decline =
        tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Decline'));

    expect(accept.style!.backgroundColor!.resolve({}), AppTheme.successGreen);
    expect(decline.style!.backgroundColor!.resolve({}), AppTheme.dangerRed);
  });

  testWidgets('client info shows posting date and preferred date',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: JobRequestScreen(job: _buildJob()),
    ));

    await test_viewport.reveal(tester, find.text('Posted:'));
    await tester.pumpAndSettle();

    expect(find.text('Posted:'), findsOneWidget);
    expect(find.text('August 10, 2026'), findsOneWidget);
    expect(find.text('Preferred Date:'), findsOneWidget);
    expect(find.text('August 15, 2026'), findsOneWidget);
  });

  testWidgets('star row reflects the client rating', (tester) async {
    final client = UserModel(
      uid: 'user-1',
      email: 'sara@quickfix.test',
      fullName: 'Sara Ahmed',
      phone: '03211234567',
      role: UserRole.user,
      rating: 3.4,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: JobRequestScreen(job: _buildJob(), client: client),
    ));

    await test_viewport.reveal(tester, find.text('Rating:'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.star), findsNWidgets(3));
    expect(find.byIcon(Icons.star_border), findsNWidgets(2));
  });

  testWidgets('accept pops exactly once (no black screen)', (tester) async {
    final jobService = MockJobService();
    final requests = MockRequestService();
    when(() => requests.getExistingRequest(jobId: 'job-1', workerId: 'w1')).thenAnswer((_) async => null);
    when(() => requests.sendJobRequest(jobId: 'job-1', workerId: 'w1', userId: 'user-1')).thenAnswer((_) async => 'request');

    final rootKey = GlobalKey();
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      key: rootKey,
      home: JobRequestScreen(
        job: _buildJob(),
        workerId: 'w1',
        jobService: jobService,
        requestService: requests,
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Apply for job'));
    await tester.pumpAndSettle();

    verify(() => requests.sendJobRequest(jobId: 'job-1', workerId: 'w1', userId: 'user-1')).called(1);
    verifyNever(() => jobService.assignJob('job-1', 'w1'));
    // The JobRequestScreen is gone but the home route is still mounted.
    expect(find.byType(JobRequestScreen), findsNothing);
    expect(find.byKey(rootKey), findsOneWidget);
  });

  testWidgets('accept without injected service shows error, stays on screen',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: JobRequestScreen(job: _buildJob(), workerId: 'w1'),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Apply for job'));
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.byType(JobRequestScreen), findsOneWidget);
  });

  testWidgets('accept is disabled while submitting', (tester) async {
    final jobService = MockJobService();
    final requests = MockRequestService();
    when(() => requests.getExistingRequest(jobId: 'job-1', workerId: 'w1')).thenAnswer((_) async => null);
    var acceptCalls = 0;
    when(() => requests.sendJobRequest(jobId: 'job-1', workerId: 'w1', userId: 'user-1')).thenAnswer((_) async {
      acceptCalls++;
      await Future<void>.delayed(const Duration(milliseconds: 100));
      return 'request';
    });

    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: JobRequestScreen(
        job: _buildJob(),
        workerId: 'w1',
        jobService: jobService,
        requestService: requests,
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Apply for job'));
    await tester.pump(const Duration(milliseconds: 10));
    await tester.tap(find.text('Apply for job'), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(acceptCalls, 1);
  });

  testWidgets('client info resolves real client from AuthService', (tester) async {
    final client = UserModel(
      uid: 'user-1',
      email: 'sara@quickfix.test',
      fullName: 'Sara Ahmed',
      phone: '03211234567',
      role: UserRole.user,
      rating: 3.4,
      completedJobs: 2,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: JobRequestScreen(job: _buildJob(), client: client),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Sara Ahmed'), findsOneWidget);
    expect(find.text('Ahmed Ali'), findsNothing);
  });

  testWidgets('distance row hidden when job has no real distance data',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: JobRequestScreen(job: _buildJob()),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('away'), findsNothing);
  });
}
