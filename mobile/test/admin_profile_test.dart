import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quickfix/models/user_model.dart';
import 'package:quickfix/services/auth_service.dart';
import 'package:quickfix/views/admin/admin_profile_screen.dart';
import 'package:quickfix/views/auth/login_screen.dart';

class _Auth extends Mock implements AuthService {}
final _user = UserModel(uid: 'admin', email: 'admin@example.com', fullName: 'Admin Person', phone: '', role: UserRole.admin, createdAt: DateTime(2026), updatedAt: DateTime(2026));
void main() {
  testWidgets('profile shows administrator identity, client-view escape hatch and build info', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: AdminProfileScreen(user: _user, authService: _Auth())))); await tester.pumpAndSettle();
    expect(find.text('Admin Person'), findsOneWidget); expect(find.text('ADMIN'), findsOneWidget); expect(find.byKey(const Key('admin-open-client-view')), findsOneWidget); expect(find.textContaining('App version:'), findsOneWidget);
  });
  testWidgets('sign-out confirmation can be canceled without writing, confirm signs out', (tester) async {
    final auth = _Auth(); when(() => auth.signOut()).thenAnswer((_) async {});
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: AdminProfileScreen(user: _user, authService: auth)))); await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('admin-sign-out'))); await tester.pumpAndSettle(); expect(find.text('Sign out of QuickFix?'), findsOneWidget); await tester.tap(find.text('Cancel')); await tester.pumpAndSettle(); verifyNever(() => auth.signOut());
    await tester.tap(find.byKey(const Key('admin-sign-out'))); await tester.pumpAndSettle(); await tester.tap(find.byKey(const Key('admin-sign-out-confirm'))); await tester.pumpAndSettle();
    verify(() => auth.signOut()).called(1); expect(find.byType(LoginScreen), findsOneWidget);
  });
}
