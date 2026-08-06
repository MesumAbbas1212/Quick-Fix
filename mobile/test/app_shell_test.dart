import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quickfix/features/auth/presentation/app_shell.dart';
import 'package:quickfix/features/jobs/presentation/find_jobs_screen.dart';
import 'package:quickfix/features/jobs/presentation/worker_dashboard_screen.dart';
import 'package:quickfix/shared/models/user_model.dart';

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
  Future<void> pumpShell(WidgetTester tester, UserModel user) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(home: AppShell(user: user)),
    );
  }

  testWidgets('AppShell routes worker role to WorkerDashboardScreen',
      (tester) async {
    await pumpShell(tester, _user(UserRole.worker));

    expect(find.byType(WorkerDashboardScreen), findsOneWidget);
    expect(find.byType(FindJobsScreen), findsNothing);
  });

  testWidgets('AppShell routes user role to FindJobsScreen', (tester) async {
    await pumpShell(tester, _user(UserRole.user));

    expect(find.byType(FindJobsScreen), findsOneWidget);
    expect(find.byType(WorkerDashboardScreen), findsNothing);
  });
}
