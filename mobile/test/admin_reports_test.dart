import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quickfix/models/admin_report_row.dart';
import 'package:quickfix/models/user_model.dart';
import 'package:quickfix/services/admin_service.dart';
import 'package:quickfix/views/admin/admin_widgets.dart';
import 'package:quickfix/views/admin/admin_report_detail_screen.dart';
import 'package:quickfix/views/admin/admin_reports_screen.dart';

class _Admin extends Mock implements AdminService {}
final _user = UserModel(uid: 'a', email: 'a@example.com', fullName: 'Admin', phone: '', role: UserRole.admin, createdAt: DateTime(2026), updatedAt: DateTime(2026));
AdminReportRow _row(String status) => AdminReportRow(id: 'r1', reason: 'Unsafe conduct', details: 'Details', status: status, reporterId: 'c', reporterName: 'Client', reportedId: 'w', reportedName: 'Worker', createdAt: DateTime(2026));
void main() {
  testWidgets('reports loading state shows skeletons', (tester) async {
    final service = _Admin(); final stream = StreamController<List<AdminReportRow>>();
    when(() => service.openReportsCount()).thenAnswer((_) async => 0); when(() => service.watchReports(limit: 50)).thenAnswer((_) => stream.stream);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: AdminReportsScreen(user: _user, adminService: service))));
    expect(find.byType(AdminLoading), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await stream.close();
  });
  testWidgets('reports error has retry', (tester) async {
    final service = _Admin(); when(() => service.openReportsCount()).thenAnswer((_) async => 0); when(() => service.watchReports(limit: 50)).thenAnswer((_) => Stream.error(StateError('offline')));
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: AdminReportsScreen(user: _user, adminService: service)))); await tester.pumpAndSettle();
    expect(find.text('Something went wrong'), findsOneWidget);
  });
  testWidgets('reports empty state is status-specific', (tester) async {
    final service = _Admin(); when(() => service.openReportsCount()).thenAnswer((_) async => 0); when(() => service.watchReports(limit: 50)).thenAnswer((_) => Stream.value(const <AdminReportRow>[]));
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: AdminReportsScreen(user: _user, adminService: service)))); await tester.pumpAndSettle();
    expect(find.text('No open reports'), findsOneWidget);
  });
  testWidgets('reports filter data and tap through to detail', (tester) async {
    final service = _Admin(); when(() => service.openReportsCount()).thenAnswer((_) async => 1); when(() => service.watchReports(limit: 50)).thenAnswer((_) => Stream.value([_row('open'), _row('resolved')]));
    when(() => service.reportDetail('r1')).thenAnswer((_) async => null);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: AdminReportsScreen(user: _user, adminService: service)))); await tester.pumpAndSettle();
    expect(find.text('Unsafe conduct'), findsOneWidget); await tester.tap(find.byKey(const Key('admin-report-row-r1'))); await tester.pumpAndSettle();
    expect(find.byType(AdminReportDetailScreen), findsOneWidget); verify(() => service.reportDetail('r1')).called(1);
  });
}
