import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quickfix/models/admin_report_row.dart';
import 'package:quickfix/models/user_model.dart';
import 'package:quickfix/services/admin_service.dart';
import 'package:quickfix/views/admin/admin_report_detail_screen.dart';

class _Admin extends Mock implements AdminService {}
final _user = UserModel(uid: 'admin', email: 'a@example.com', fullName: 'Admin', phone: '', role: UserRole.admin, createdAt: DateTime(2026), updatedAt: DateTime(2026));
AdminReportDetail _detail({String status = 'open'}) => AdminReportDetail(report: AdminReportRow(id: 'r1', reason: 'Unsafe conduct', details: 'Reported behavior', status: status, reporterId: 'c', reporterName: 'Client', reportedId: 'w', reportedName: 'Worker'), reporter: const {'fullName': 'Client', 'role': 'user'}, reported: const {'fullName': 'Worker', 'role': 'worker'}, job: const {'title': 'Repair', 'status': 'completed'}, priorReportCount: 2);
void main() {
  testWidgets('report detail loading state', (tester) async {
    final service = _Admin(); final pending = Completer<AdminReportDetail?>(); when(() => service.reportDetail('r1')).thenAnswer((_) => pending.future);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: AdminReportDetailScreen(reportId: 'r1', user: _user, adminService: service))));
    expect(find.byType(CircularProgressIndicator), findsWidgets);
  });
  testWidgets('report detail error has retry', (tester) async {
    final service = _Admin(); when(() => service.reportDetail('r1')).thenAnswer((_) => Future.error(StateError('offline')));
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: AdminReportDetailScreen(reportId: 'r1', user: _user, adminService: service)))); await tester.pumpAndSettle();
    expect(find.text('Something went wrong'), findsOneWidget);
  });
  testWidgets('missing report has an explicit empty state', (tester) async {
    final service = _Admin(); when(() => service.reportDetail('r1')).thenAnswer((_) async => null);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: AdminReportDetailScreen(reportId: 'r1', user: _user, adminService: service)))); await tester.pumpAndSettle();
    expect(find.text('Report not found'), findsOneWidget);
  });
  testWidgets('decided report is read-only and data is rendered', (tester) async {
    final service = _Admin(); when(() => service.reportDetail('r1')).thenAnswer((_) async => _detail(status: 'resolved'));
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: AdminReportDetailScreen(reportId: 'r1', user: _user, adminService: service)))); await tester.pumpAndSettle();
    expect(find.text('Unsafe conduct'), findsOneWidget); expect(find.textContaining('already resolved'), findsOneWidget); expect(find.byKey(const Key('admin-report-resolve')), findsNothing);
  });
  testWidgets('canceling confirmation does not resolve report; confirmation calls exact transaction API', (tester) async {
    final service = _Admin(); when(() => service.reportDetail('r1')).thenAnswer((_) async => _detail());
    when(() => service.resolveReport(reportId: 'r1', status: 'resolved', note: 'Reviewed evidence', resolvedBy: 'admin')).thenAnswer((_) async {});
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) => Scaffold(body: TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AdminReportDetailScreen(reportId: 'r1', user: _user, adminService: service))), child: const Text('Open'))))));
    await tester.tap(find.text('Open')); await tester.pumpAndSettle(); await tester.enterText(find.byKey(const Key('admin-report-resolution-note')), 'Reviewed evidence');
    await tester.tap(find.byKey(const Key('admin-report-resolve'))); await tester.pumpAndSettle(); expect(find.text('Resolve this report?'), findsOneWidget);
    await tester.tap(find.text('Cancel')); await tester.pumpAndSettle(); verifyNever(() => service.resolveReport(reportId: 'r1', status: 'resolved', note: 'Reviewed evidence', resolvedBy: 'admin'));
    await tester.tap(find.byKey(const Key('admin-report-resolve'))); await tester.pumpAndSettle(); await tester.tap(find.byKey(const Key('admin-report-confirm'))); await tester.pumpAndSettle();
    verify(() => service.resolveReport(reportId: 'r1', status: 'resolved', note: 'Reviewed evidence', resolvedBy: 'admin')).called(1);
  });
}
