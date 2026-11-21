import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quickfix/models/admin_account_detail.dart';
import 'package:quickfix/models/admin_account_row.dart';
import 'package:quickfix/models/user_model.dart';
import 'package:quickfix/services/admin_service.dart';
import 'package:quickfix/views/admin/admin_account_detail_screen.dart';

class _Admin extends Mock implements AdminService {}
final _user = UserModel(uid: 'admin', email: 'a@example.com', fullName: 'Admin', phone: '', role: UserRole.admin, createdAt: DateTime(2026), updatedAt: DateTime(2026));
AdminAccountDetail _detail() => const AdminAccountDetail(account: AdminAccountRow(uid: 'u1', name: 'Client One', email: 'client@example.com', role: 'user'), userData: {'phone': '123'});
void main() {
  testWidgets('account detail loading', (tester) async {
    final service = _Admin(); final future = Completer<AdminAccountDetail?>(); when(() => service.accountDetail('u1', worker: false)).thenAnswer((_) => future.future);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: AdminAccountDetailScreen(uid: 'u1', user: _user, adminService: service)))); expect(find.byType(CircularProgressIndicator), findsWidgets);
  });
  testWidgets('account detail error has retry', (tester) async {
    final service = _Admin(); when(() => service.accountDetail('u1', worker: false)).thenAnswer((_) => Future.error(StateError('offline')));
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: AdminAccountDetailScreen(uid: 'u1', user: _user, adminService: service)))); await tester.pumpAndSettle(); expect(find.text('Something went wrong'), findsOneWidget);
  });
  testWidgets('missing account has an explicit empty state', (tester) async {
    final service = _Admin(); when(() => service.accountDetail('u1', worker: false)).thenAnswer((_) async => null);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: AdminAccountDetailScreen(uid: 'u1', user: _user, adminService: service)))); await tester.pumpAndSettle(); expect(find.text('Account not found'), findsOneWidget);
  });
  testWidgets('populated account shows identity and moderation controls', (tester) async {
    final service = _Admin(); when(() => service.accountDetail('u1', worker: false)).thenAnswer((_) async => _detail());
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: AdminAccountDetailScreen(uid: 'u1', user: _user, adminService: service)))); await tester.pumpAndSettle();
    expect(find.text('Client One'), findsOneWidget); await tester.tap(find.text('Moderation')); await tester.pumpAndSettle(); expect(find.text('Block account'), findsOneWidget);
  });
  testWidgets('block confirmation cancel writes nothing; confirming blocks exact account', (tester) async {
    final service = _Admin(); when(() => service.accountDetail('u1', worker: false)).thenAnswer((_) async => _detail()); when(() => service.setUserBlocked('u1', true)).thenAnswer((_) async {});
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: AdminAccountDetailScreen(uid: 'u1', user: _user, adminService: service)))); await tester.pumpAndSettle(); await tester.tap(find.text('Moderation')); await tester.pumpAndSettle();
    await tester.tap(find.text('Block account')); await tester.pumpAndSettle(); expect(find.textContaining('suspends this account'), findsOneWidget); await tester.tap(find.text('Cancel')); await tester.pumpAndSettle(); verifyNever(() => service.setUserBlocked('u1', true));
    await tester.tap(find.text('Block account')); await tester.pumpAndSettle(); await tester.tap(find.byKey(const Key('admin-account-confirm-action'))); await tester.pumpAndSettle();
    verify(() => service.setUserBlocked('u1', true)).called(1);
  });
}
