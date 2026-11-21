import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quickfix/models/admin_account_row.dart';
import 'package:quickfix/models/admin_counts.dart';
import 'package:quickfix/models/admin_report_row.dart';
import 'package:quickfix/models/user_model.dart';
import 'package:quickfix/services/admin_service.dart';
import 'package:quickfix/views/admin/admin_dashboard_screen.dart';

class _Admin extends Mock implements AdminService {}
UserModel _user() => UserModel(uid: 'a', email: 'a@example.com', fullName: 'Admin', phone: '', role: UserRole.admin, createdAt: DateTime(2026), updatedAt: DateTime(2026));
AdminReportRow _report() => AdminReportRow(id: 'r1', reason: 'Unsafe conduct', details: '', status: 'open', reporterId: 'u', reporterName: 'Client', reportedId: 'w', reportedName: 'Worker');
void _streams(_Admin service, {Stream<List<AdminReportRow>>? reports, Stream<List<AdminAccountRow>>? workers}) {
  when(() => service.watchReports(limit: any(named: 'limit'))).thenAnswer((_) => reports ?? Stream.value(const <AdminReportRow>[]));
  when(() => service.watchPendingVerifications(limit: any(named: 'limit'))).thenAnswer((_) => workers ?? Stream.value(const <AdminAccountRow>[]));
}
void main() {
  testWidgets('dashboard loading shows skeleton before counts resolve', (tester) async {
    final service = _Admin(); final pending = Completer<AdminCounts>();
    when(() => service.counts()).thenAnswer((_) => pending.future); _streams(service);
    await tester.pumpWidget(MaterialApp(home: AdminDashboardScreen(user: _user(), adminService: service)));
    expect(find.byType(CircularProgressIndicator), findsWidgets);
  });
  testWidgets('dashboard error exposes retry and calls counts again', (tester) async {
    final service = _Admin(); var calls = 0;
    when(() => service.counts()).thenAnswer((_) { calls++; return Future.error(StateError('offline')); }); _streams(service);
    await tester.pumpWidget(MaterialApp(home: AdminDashboardScreen(user: _user(), adminService: service)));
    await tester.pumpAndSettle(); expect(find.text('Something went wrong'), findsOneWidget);
    await tester.tap(find.byKey(const Key('error-retry-button'))); await tester.pumpAndSettle(); expect(calls, 2);
  });
  testWidgets('dashboard empty state is explicit', (tester) async {
    final service = _Admin(); when(() => service.counts()).thenAnswer((_) async => const AdminCounts()); _streams(service);
    await tester.pumpWidget(MaterialApp(home: AdminDashboardScreen(user: _user(), adminService: service)));
    await tester.pumpAndSettle(); expect(find.text('No open reports currently.'), findsOneWidget);
  });
  testWidgets('dashboard renders counts and reports and opens report queue action', (tester) async {
    final service = _Admin(); when(() => service.counts()).thenAnswer((_) async => const AdminCounts(users: 12, workers: 4, jobs: 20, openReports: 1)); _streams(service, reports: Stream.value([_report()]));
    var opened = false;
    await tester.pumpWidget(MaterialApp(home: AdminDashboardScreen(user: _user(), adminService: service, onOpenReports: () => opened = true)));
    await tester.pumpAndSettle(); expect(find.text('12'), findsOneWidget); expect(find.text('Unsafe conduct'), findsOneWidget);
    await tester.tap(find.text('View reports')); expect(opened, isTrue);
  });
}
