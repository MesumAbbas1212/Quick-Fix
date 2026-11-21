import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quickfix/models/admin_account_row.dart';
import 'package:quickfix/models/user_model.dart';
import 'package:quickfix/services/admin_service.dart';
import 'package:quickfix/views/admin/admin_account_detail_screen.dart';
import 'package:quickfix/views/admin/admin_accounts_screen.dart';

class _Admin extends Mock implements AdminService {}
final _user = UserModel(uid: 'admin', email: 'a@example.com', fullName: 'Admin', phone: '', role: UserRole.admin, createdAt: DateTime(2026), updatedAt: DateTime(2026));
AdminAccountRow _row() => const AdminAccountRow(uid: 'u1', name: 'Client One', email: 'client@example.com', role: 'user');
void _users(_Admin service, Stream<List<AdminAccountRow>> stream) => when(() => service.watchUsers(limit: 50)).thenAnswer((_) => stream);
void main() {
  testWidgets('accounts loading', (tester) async {
    final service = _Admin(); final controller = StreamController<List<AdminAccountRow>>(); addTearDown(controller.close); _users(service, controller.stream);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: AdminAccountsScreen(user: _user, adminService: service)))); expect(find.byType(CircularProgressIndicator), findsWidgets);
  });
  testWidgets('accounts error has retry', (tester) async {
    final service = _Admin(); _users(service, Stream.error(StateError('offline')));
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: AdminAccountsScreen(user: _user, adminService: service)))); await tester.pumpAndSettle(); expect(find.text('Something went wrong'), findsOneWidget);
  });
  testWidgets('accounts empty state', (tester) async {
    final service = _Admin(); _users(service, Stream.value(const <AdminAccountRow>[]));
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: AdminAccountsScreen(user: _user, adminService: service)))); await tester.pumpAndSettle(); expect(find.text('No users found'), findsOneWidget);
  });
  testWidgets('search and populated account tap through to detail', (tester) async {
    final service = _Admin(); _users(service, Stream.value([_row()])); when(() => service.accountDetail('u1', worker: false)).thenAnswer((_) async => null);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: AdminAccountsScreen(user: _user, adminService: service)))); await tester.pumpAndSettle();
    expect(find.text('Client One'), findsOneWidget); await tester.enterText(find.byKey(const Key('admin-account-search')), 'nomatch'); await tester.pumpAndSettle(); expect(find.text('No search matches'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('admin-account-search')), 'client@'); await tester.pumpAndSettle(); await tester.tap(find.byKey(const Key('admin-account-u1'))); await tester.pumpAndSettle();
    expect(find.byType(AdminAccountDetailScreen), findsOneWidget); verify(() => service.accountDetail('u1', worker: false)).called(1);
  });
}
