import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quickfix/models/job_model.dart';
import 'package:quickfix/models/review_model.dart';
import 'package:quickfix/services/job_service.dart';
import 'package:quickfix/services/review_service.dart';
import 'package:quickfix/views/auth/app_shell.dart';
import 'package:quickfix/views/client/client_shell.dart';
import 'package:quickfix/views/worker/worker_shell.dart';
import 'package:quickfix/models/user_model.dart';

class MockJobService extends Mock implements JobService {}

class MockReviewService extends Mock implements ReviewService {
  @override
  Stream<List<Review>> watchReviewsForWorker(String workerId) =>
      Stream.value(const <Review>[]);
}

UserModel _user(UserRole role) {
  return UserModel(
    uid: 'u1',
    email: 'test@quickfix.com',
    fullName: 'Test User',
    phone: '03001234567',
    role: role,
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

  Future<void> pumpShell(WidgetTester tester, UserModel user) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: AppShell(
          user: user,
          jobService: jobService,
          reviewService: MockReviewService(),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('AppShell routes worker role to WorkerShell', (tester) async {
    await pumpShell(tester, _user(UserRole.worker));

    expect(find.byType(WorkerShell), findsOneWidget);
    expect(find.byType(ClientShell), findsNothing);
  });

  testWidgets('worker shell exposes Jobs/My Jobs/Messages/Profile tabs',
      (tester) async {
    await pumpShell(tester, _user(UserRole.worker));

    expect(find.text('Jobs'), findsWidgets);
    expect(find.text('My Jobs'), findsOneWidget);
    expect(find.text('Messages'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('Find Jobs'), findsNothing);
  });

  testWidgets('AppShell routes user role to ClientShell', (tester) async {
    await pumpShell(tester, _user(UserRole.user));

    expect(find.byType(ClientShell), findsOneWidget);
    expect(find.byType(WorkerShell), findsNothing);
  });

  testWidgets('client shell exposes Home/Workers/Messages/Profile tabs',
      (tester) async {
    await pumpShell(tester, _user(UserRole.user));

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Workers'), findsOneWidget);
    expect(find.text('Messages'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('Find Jobs'), findsNothing);
  });
}
