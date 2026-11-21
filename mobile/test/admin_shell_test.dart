import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quickfix/models/admin_counts.dart';
import 'package:quickfix/models/admin_report_row.dart';
import 'package:quickfix/models/admin_account_row.dart';
import 'package:quickfix/models/user_model.dart';
import 'package:quickfix/services/admin_service.dart';
import 'package:quickfix/services/auth_service.dart';
import 'package:quickfix/views/admin/admin_shell.dart';
import 'package:quickfix/views/auth/login_screen.dart';

class _Auth extends Mock implements AuthService {}
class _Admin extends Mock implements AdminService {}

UserModel _admin() => UserModel(uid: 'admin-1', email: 'admin@example.com', fullName: 'Admin', phone: '', role: UserRole.admin, createdAt: DateTime(2026), updatedAt: DateTime(2026));

void _stubData(_Admin service) {
  when(() => service.counts()).thenAnswer((_) async => const AdminCounts());
  when(() => service.watchReports(limit: any(named: 'limit'))).thenAnswer((_) => Stream.value(const <AdminReportRow>[]));
  when(() => service.watchWorkers(limit: any(named: 'limit'))).thenAnswer((_) => Stream.value(const <AdminAccountRow>[]));
  when(() => service.watchPendingVerifications(limit: any(named: 'limit'))).thenAnswer((_) => Stream.value(const <AdminAccountRow>[]));
  when(() => service.watchUsers(limit: any(named: 'limit'))).thenAnswer((_) => Stream.value(const <AdminAccountRow>[]));
}

void main() {
  testWidgets('admin role gets unmistakable admin mode and five navigation tabs', (tester) async {
    final auth = _Auth(); final service = _Admin(); _stubData(service);
    when(() => auth.watchUser('admin-1')).thenAnswer((_) => Stream.value(_admin()));
    await tester.pumpWidget(MaterialApp(home: AdminShell(user: _admin(), authService: auth, adminService: service)));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('admin-mode-chip')), findsOneWidget);
    expect(find.text('ADMIN'), findsOneWidget);
    expect(find.text('Overview'), findsOneWidget); expect(find.text('Reports'), findsOneWidget);
    expect(find.text('Accounts'), findsOneWidget); expect(find.text('Catalog'), findsOneWidget); expect(find.text('Profile'), findsOneWidget);
  });

  testWidgets('live demotion signs out instead of rendering an admin view', (tester) async {
    final auth = _Auth(); final service = _Admin(); _stubData(service); final roles = StreamController<UserModel?>(); addTearDown(roles.close);
    when(() => auth.watchUser('admin-1')).thenAnswer((_) => roles.stream);
    when(() => auth.signOut()).thenAnswer((_) async {});
    await tester.pumpWidget(MaterialApp(home: AdminShell(user: _admin(), authService: auth, adminService: service)));
    roles.add(_admin()); await tester.pumpAndSettle(); expect(find.byKey(const Key('admin-mode-chip')), findsOneWidget);
    roles.add(_admin().copyWith(role: UserRole.user)); await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget); verify(() => auth.signOut()).called(1);
  });

  testWidgets('resume performs a server-only role check before showing admin tabs', (tester) async {
    final auth = _Auth(); final service = _Admin(); _stubData(service);
    when(() => auth.watchUser('admin-1')).thenAnswer((_) => Stream.value(_admin()));
    when(() => auth.getUserProfile('admin-1', serverOnly: true)).thenAnswer((_) async => null);
    when(() => auth.signOut()).thenAnswer((_) async {});
    await tester.pumpWidget(MaterialApp(home: AdminShell(user: _admin(), authService: auth, adminService: service)));
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget); verify(() => auth.getUserProfile('admin-1', serverOnly: true)).called(1);
  });
}
