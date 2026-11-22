import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quickfix/core/widgets/rank_badge.dart';
import 'package:quickfix/models/admin_account_row.dart';
import 'package:quickfix/models/user_model.dart';
import 'package:quickfix/services/admin_service.dart';
import 'package:quickfix/views/admin/admin_widgets.dart';
import 'package:quickfix/views/admin/admin_account_detail_screen.dart';
import 'package:quickfix/views/admin/admin_accounts_screen.dart';

class _Admin extends Mock implements AdminService {}
final _user = UserModel(uid: 'admin', email: 'a@example.com', fullName: 'Admin', phone: '', role: UserRole.admin, createdAt: DateTime(2026), updatedAt: DateTime(2026));
AdminAccountRow _row() => const AdminAccountRow(uid: 'u1', name: 'Client One', email: 'client@example.com', role: 'user');
AdminAccountRow _workerRow() => const AdminAccountRow(uid: 'w1', name: 'Worker One', email: 'worker@example.com', role: 'worker');
void _users(_Admin service, Stream<List<AdminAccountRow>> stream) => when(() => service.watchUsers(limit: 50)).thenAnswer((_) => stream);
void _workers(_Admin service, Stream<List<AdminAccountRow>> stream) => when(() => service.watchWorkers(limit: 50)).thenAnswer((_) => stream);
void main() {
  testWidgets('accounts loading', (tester) async {
    final service = _Admin(); final controller = StreamController<List<AdminAccountRow>>(); addTearDown(controller.close); _users(service, controller.stream);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: AdminAccountsScreen(user: _user, adminService: service)))); expect(find.byType(AdminLoading), findsOneWidget);
  });
  testWidgets('accounts error has retry', (tester) async {
    final service = _Admin(); _users(service, Stream.error(StateError('offline')));
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: AdminAccountsScreen(user: _user, adminService: service)))); await tester.pumpAndSettle(); expect(find.text('Something went wrong'), findsOneWidget);
  });
  testWidgets('accounts empty state', (tester) async {
    final service = _Admin(); _users(service, Stream.value(const <AdminAccountRow>[]));
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: AdminAccountsScreen(user: _user, adminService: service)))); await tester.pumpAndSettle(); expect(find.text('No users found'), findsOneWidget);
  });
  testWidgets('mixed account page shows only client rows in the Users segment', (tester) async {
    final service = _Admin();
    _users(service, Stream.value([_workerRow(), _row()]));
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: AdminAccountsScreen(user: _user, adminService: service))));
    await tester.pumpAndSettle();
    expect(find.text('Client One'), findsOneWidget);
    expect(find.text('Worker One'), findsNothing);
  });

  testWidgets('workers-only page leaves Users segment in its empty state', (tester) async {
    final service = _Admin();
    _workers(service, Stream.value([_workerRow()]));
    _users(service, Stream.value(const <AdminAccountRow>[]));
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: AdminAccountsScreen(user: _user, adminService: service, startWithWorkers: true))));
    await tester.pumpAndSettle();
    expect(find.text('Worker One'), findsOneWidget);
    await tester.tap(find.text('Users'));
    await tester.pumpAndSettle();
    expect(find.text('No users found'), findsOneWidget);
  });

  testWidgets('worker list keeps rows but omits rank badge when annual count is unavailable', (tester) async {
    final service = _Admin();
    _workers(service, Stream.value([const AdminAccountRow(uid: 'w2', name: 'Worker Two', email: 'two@example.com', role: 'worker', completedJobs: 240)]));
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: AdminAccountsScreen(user: _user, adminService: service, startWithWorkers: true))));
    await tester.pumpAndSettle();
    expect(find.text('Worker Two'), findsOneWidget);
    expect(find.byType(AdminError), findsNothing);
    expect(find.byType(RankBadge), findsNothing);
  });

  testWidgets('search and populated account tap through to detail', (tester) async {
    final service = _Admin(); _users(service, Stream.value([_row()])); when(() => service.accountDetail('u1', worker: false)).thenAnswer((_) async => null);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: AdminAccountsScreen(user: _user, adminService: service)))); await tester.pumpAndSettle();
    expect(find.text('Client One'), findsOneWidget); await tester.enterText(find.byKey(const Key('admin-account-search')), 'nomatch'); await tester.pumpAndSettle(); expect(find.text('No search matches'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('admin-account-search')), 'client@'); await tester.pumpAndSettle(); await tester.tap(find.byKey(const Key('admin-account-u1'))); await tester.pumpAndSettle();
    expect(find.byType(AdminAccountDetailScreen), findsOneWidget); verify(() => service.accountDetail('u1', worker: false)).called(1);
  });
}
