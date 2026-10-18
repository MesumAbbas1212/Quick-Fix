import 'package:quickfix/services/auth_service.dart';
import 'package:quickfix/models/app_release_config.dart';
import 'package:quickfix/services/app_release_service.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quickfix/controllers/auth_controller.dart';
import 'package:quickfix/models/account_deletion_policy.dart';
import 'package:quickfix/models/user_model.dart';
import 'package:quickfix/services/account_deletion_service.dart';
import 'package:quickfix/views/auth/app_shell.dart';
import 'package:quickfix/views/auth/login_screen.dart';
import 'package:quickfix/views/settings/delete_account_screen.dart';
import 'package:quickfix/views/settings/settings_screen.dart';
class MockDeletion extends Mock implements AccountDeletionService {}
class MockRelease extends Mock implements AppReleaseService {}
class MockAuth extends Mock implements AuthService {}
UserModel _user({bool pending = false}) => UserModel(uid: 'u', email: 'c@example.com', fullName: 'Client', phone: '', role: UserRole.user,
  deletionPending: pending, createdAt: DateTime(2026), updatedAt: DateTime(2026));
void main() {
  late MockDeletion service;
  setUp(() { service = MockDeletion(); when(() => service.deleteAccount(uid: 'u', password: 'password')).thenAnswer((_) async {}); });
  Future<void> pump(WidgetTester tester, {bool pending = false, AuthController? controller}) async {
    await tester.pumpWidget(MaterialApp(home: DeleteAccountScreen(user: _user(pending: pending), accountDeletionService: service, authController: controller)));
  }
  Future<void> prepare(WidgetTester tester, {String text = 'DELETE'}) async {
    await tester.ensureVisible(find.byKey(const Key('delete-account-typed'))); await tester.enterText(find.byKey(const Key('delete-account-typed')), text);
    await tester.ensureVisible(find.byKey(const Key('delete-account-password'))); await tester.enterText(find.byKey(const Key('delete-account-password')), 'password');
    tester.testTextInput.hide(); await tester.pump(); await tester.ensureVisible(find.byKey(const Key('delete-account-submit')));
  }
  Future<void> confirm(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('delete-account-submit'))); await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('delete-account-confirm'))); await tester.pump();
  }
  testWidgets('exact typed confirmation and password gate the destructive action', (tester) async {
    await pump(tester); await prepare(tester, text: 'delete');
    expect(tester.widget<ElevatedButton>(find.byKey(const Key('delete-account-submit'))).onPressed, isNull);
    verifyNever(() => service.deleteAccount(uid: any(named: 'uid'), password: any(named: 'password')));
  });
  testWidgets('confirmation dialog can cancel without calling the service', (tester) async {
    await pump(tester); await prepare(tester); await tester.tap(find.byKey(const Key('delete-account-submit'))); await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('delete-account-cancel'))); await tester.pumpAndSettle();
    expect(find.byType(DeleteAccountScreen), findsOneWidget); verifyNever(() => service.deleteAccount(uid: any(named: 'uid'), password: any(named: 'password')));
  });
  testWidgets('success clears session and returns to sign-in with old routes removed', (tester) async {
    final controller = AuthController()..setSession(userId: 'u', role: 'user');
    await pump(tester, controller: controller); await prepare(tester); await confirm(tester); await tester.pumpAndSettle();
    verify(() => service.deleteAccount(uid: 'u', password: 'password')).called(1);
    expect(find.byType(LoginScreen), findsOneWidget); expect(find.byType(DeleteAccountScreen), findsNothing); expect(controller.isAuthenticated, isFalse); controller.dispose();
  });
  testWidgets('partial failure stays visible, clears password, and retries after re-entry', (tester) async {
    when(() => service.deleteAccount(uid: 'u', password: 'password')).thenThrow(const AccountDeletionException('Partial cleanup. Retry to resume.'));
    await pump(tester); await prepare(tester); await confirm(tester); await tester.pumpAndSettle();
    expect(find.text('Partial cleanup. Retry to resume.'), findsOneWidget);
    expect(tester.widget<TextField>(find.byKey(const Key('delete-account-password'))).controller!.text, isEmpty);
    when(() => service.deleteAccount(uid: 'u', password: 'password')).thenAnswer((_) async {});
    await prepare(tester); await confirm(tester); await tester.pumpAndSettle(); expect(find.byType(LoginScreen), findsOneWidget);
  });
  testWidgets('busy state suppresses duplicate submission', (tester) async {
    final pending = Completer<void>(); when(() => service.deleteAccount(uid: 'u', password: 'password')).thenAnswer((_) => pending.future);
    await pump(tester); await prepare(tester); await confirm(tester); await tester.pumpAndSettle();
    expect(tester.widget<ElevatedButton>(find.byKey(const Key('delete-account-submit'))).onPressed, isNull);
    await tester.tap(find.byKey(const Key('delete-account-submit')), warnIfMissed: false); verify(() => service.deleteAccount(uid: 'u', password: 'password')).called(1);
    pending.complete(); await tester.pumpAndSettle();
  });
  testWidgets('pending recovery account goes to deletion instead of a role shell', (tester) async {
    final release = MockRelease(); when(() => release.checkForUpdate()).thenAnswer((_) async => const AppReleaseDecision(currentBuild: 1));
    await tester.pumpWidget(MaterialApp(home: AppShell(user: _user(pending: true), releaseService: release, accountDeletionService: service)));
    await tester.pumpAndSettle(); expect(find.byType(DeleteAccountScreen), findsOneWidget); expect(find.textContaining('Unfinished deletion detected'), findsOneWidget);
  });
  testWidgets('Settings danger zone opens the real deletion page', (tester) async {
    await tester.pumpWidget(MaterialApp(home: SettingsScreen(user: _user(), accountDeletionService: service)));
    await tester.ensureVisible(find.byKey(const Key('settings-delete-account'))); await tester.tap(find.byKey(const Key('settings-delete-account'))); await tester.pumpAndSettle();
    expect(find.byType(DeleteAccountScreen), findsOneWidget);
  });
  testWidgets('narrow large-text layout scrolls without overflow', (tester) async {
    tester.view.physicalSize = const Size(320, 600); tester.view.devicePixelRatio = 1; addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)), child: child!),
      home: DeleteAccountScreen(user: _user(), accountDeletionService: service)));
    await tester.drag(find.byType(ListView), const Offset(0, -400)); await tester.pumpAndSettle(); expect(tester.takeException(), isNull);
  });
  testWidgets('recovery can sign out and sign in again after a checking-only block', (tester) async {
    final auth = MockAuth(); when(() => auth.signOut()).thenAnswer((_) async {});
    await tester.pumpWidget(MaterialApp(home: DeleteAccountScreen(user: _user(pending: true), accountDeletionService: service, authService: auth)));
    await tester.ensureVisible(find.byKey(const Key('delete-account-leave-recovery'))); await tester.tap(find.byKey(const Key('delete-account-leave-recovery'))); await tester.pumpAndSettle();
    verify(() => auth.signOut()).called(1); expect(find.byType(LoginScreen), findsOneWidget); verifyNever(() => service.deleteAccount(uid: any(named: 'uid'), password: any(named: 'password')));
  });

}
