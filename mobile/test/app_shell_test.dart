import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quickfix/models/job_model.dart';
import 'package:quickfix/services/job_service.dart';
import 'package:quickfix/views/auth/app_shell.dart';
import 'package:quickfix/views/client/client_shell.dart';
import 'package:quickfix/views/jobs/worker_dashboard_screen.dart';
import 'package:quickfix/models/user_model.dart';

class MockJobService extends Mock implements JobService {}

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
        home: AppShell(user: user, jobService: jobService),
      ),
    );
    await tester.pump();
  }

  testWidgets('AppShell routes worker role to WorkerDashboardScreen',
      (tester) async {
    await pumpShell(tester, _user(UserRole.worker));

    expect(find.byType(WorkerDashboardScreen), findsOneWidget);
    expect(find.byType(ClientShell), findsNothing);
  });

  testWidgets('AppShell routes user role to ClientShell', (tester) async {
    await pumpShell(tester, _user(UserRole.user));

    expect(find.byType(ClientShell), findsOneWidget);
    expect(find.byType(WorkerDashboardScreen), findsNothing);
  });
}
