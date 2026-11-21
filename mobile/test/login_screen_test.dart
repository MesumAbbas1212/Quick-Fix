import 'helpers/visible.dart' as test_viewport;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:quickfix/models/user_model.dart';
import 'package:quickfix/models/app_release_config.dart';
import 'package:quickfix/services/app_release_service.dart';
import 'package:quickfix/views/settings/delete_account_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quickfix/core/theme/app_theme.dart';
import 'package:quickfix/services/auth_service.dart';
import 'package:quickfix/views/auth/login_screen.dart';
import 'package:quickfix/views/auth/signup_screen.dart';
import 'package:quickfix/views/auth/profile_missing_screen.dart';

class MockAuthService extends Mock implements AuthService {}
class MockCredential extends Mock implements UserCredential {}
class MockUser extends Mock implements User {}
class MockRelease extends Mock implements AppReleaseService {}

Finder _selectedCard(Color expectedColor) {
  return find.byWidgetPredicate((widget) {
    if (widget is! AnimatedContainer) return false;
    final decoration = widget.decoration;
    if (decoration is! BoxDecoration) return false;
    final shadows = decoration.boxShadow ?? const [];
    return decoration.color == expectedColor && shadows.length == 2;
  });
}

void main() {
  testWidgets('login shows Find Services and Get Jobs role cards',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Login as User'), findsOneWidget);
    expect(find.text('Find Services'), findsOneWidget);
    expect(find.text('Login as Worker'), findsOneWidget);
    expect(find.text('Get Jobs'), findsOneWidget);
  });

  testWidgets('tapping Get Jobs selects the worker role card',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
    await tester.pumpAndSettle();

    expect(_selectedCard(const Color(0xFF009AE2)), findsOneWidget);

    await tester.tap(find.text('Get Jobs'));
    await tester.pumpAndSettle();

    expect(_selectedCard(AppTheme.accentYellow), findsOneWidget);
    expect(_selectedCard(const Color(0xFF009AE2)), findsNothing);
  });

  testWidgets('Sign Up opens the signup screen with the selected role',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Get Jobs'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sign Up'));
    await tester.pumpAndSettle();

    expect(find.byType(SignUpScreen), findsOneWidget);
    expect(_selectedCard(AppTheme.accentYellow), findsOneWidget);
  });

  testWidgets('login layout scrolls when keyboard opens on small screens',
      (tester) async {
    // A short viewport simulates the keyboard covering most of the screen.
    tester.view.physicalSize = const Size(360, 400);
    tester.view.devicePixelRatio = 1.0;
    tester.view.viewInsets = FakeViewPadding(bottom: 250);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
    await tester.pumpAndSettle();

    // Focusing the email field raises the keyboard; the login button must
    // stay reachable by scrolling (no overflow / no exception).
    await tester.enterText(find.byType(TextFormField).at(0), 'a@b.co');
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Login'), findsOneWidget);

    await test_viewport.reveal(tester, find.text('Login'));
    await tester.pumpAndSettle();
    expect(find.text('Sign Up'), findsOneWidget);
  });

  testWidgets('login fits on a small screen without keyboard', (tester) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // The login button lives at the bottom of the column; it must be
    // reachable by scrolling without any overflow errors.
    await test_viewport.reveal(tester, find.text('Login'));
    await tester.pumpAndSettle();
    expect(find.text('Login'), findsOneWidget);
  });

  testWidgets('forgot password sends a reset email', (tester) async {
    final auth = MockAuthService();
    when(() => auth.sendPasswordReset(email: 'a@b.co'))
        .thenAnswer((_) async {});

    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(home: LoginScreen(authService: auth)));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'a@b.co');

    await tester.tap(find.text('Forgot Password?'));
    await tester.pumpAndSettle();

    verify(() => auth.sendPasswordReset(email: 'a@b.co')).called(1);
    expect(find.text('Reset Link Sent'), findsOneWidget);
  });
  testWidgets('sign-in honors the injected service and routes pending deletion to recovery', (tester) async {
    final auth = MockAuthService(); final credential = MockCredential(); final current = MockUser(); final release = MockRelease();
    when(() => credential.user).thenReturn(current); when(() => current.uid).thenReturn('u');
    when(() => auth.signInWithEmailAndPassword(email: 'c@example.com', password: 'password')).thenAnswer((_) async => credential);
    when(() => auth.getUserProfile('u', serverOnly: true)).thenAnswer((_) async => UserModel(uid: 'u', email: 'c@example.com', fullName: 'Recovery', phone: '', role: UserRole.user,
      deletionPending: true, createdAt: DateTime(2026), updatedAt: DateTime(2026)));
    when(() => release.checkForUpdate()).thenAnswer((_) async => const AppReleaseDecision(currentBuild: 1));
    tester.view.physicalSize = const Size(1000, 1200); tester.view.devicePixelRatio = 1; addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: LoginScreen(authService: auth, releaseService: release)));
    await tester.enterText(find.byType(TextFormField).first, 'c@example.com'); await tester.enterText(find.byType(TextFormField).last, 'password');
    await tester.tap(find.text('Login')); await tester.pumpAndSettle(); expect(find.byType(DeleteAccountScreen), findsOneWidget);
    verify(() => auth.signInWithEmailAndPassword(email: 'c@example.com', password: 'password')).called(1);
  });

  testWidgets('missing Firestore profile routes to explicit recovery', (tester) async {
    final auth = MockAuthService(); final credential = MockCredential(); final current = MockUser();
    when(() => credential.user).thenReturn(current); when(() => current.uid).thenReturn('missing-uid');
    when(() => auth.signInWithEmailAndPassword(email: 'admin@example.com', password: 'password')).thenAnswer((_) async => credential);
    when(() => auth.getUserProfile('missing-uid', serverOnly: true)).thenAnswer((_) async => null);
    tester.view.physicalSize = const Size(1000, 1200); tester.view.devicePixelRatio = 1; addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: LoginScreen(authService: auth)));
    await tester.enterText(find.byType(TextFormField).first, 'admin@example.com'); await tester.enterText(find.byType(TextFormField).last, 'password');
    await tester.tap(find.text('Login')); await tester.pumpAndSettle();
    expect(find.byType(ProfileMissingScreen), findsOneWidget); expect(find.text('UID: missing-uid'), findsOneWidget);
  });

  testWidgets('blocked account is signed out before any shell mounts', (tester) async {
    final auth = MockAuthService(); final credential = MockCredential(); final current = MockUser();
    when(() => credential.user).thenReturn(current); when(() => current.uid).thenReturn('blocked-uid');
    when(() => auth.signInWithEmailAndPassword(email: 'blocked@example.com', password: 'password')).thenAnswer((_) async => credential);
    when(() => auth.getUserProfile('blocked-uid', serverOnly: true)).thenAnswer((_) async => UserModel(uid: 'blocked-uid', email: 'blocked@example.com', fullName: 'Blocked', phone: '', role: UserRole.user, blocked: true, createdAt: DateTime(2026), updatedAt: DateTime(2026)));
    when(() => auth.signOut()).thenAnswer((_) async {});
    tester.view.physicalSize = const Size(1000, 1200); tester.view.devicePixelRatio = 1; addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: LoginScreen(authService: auth)));
    await tester.enterText(find.byType(TextFormField).first, 'blocked@example.com'); await tester.enterText(find.byType(TextFormField).last, 'password');
    await tester.tap(find.text('Login')); await tester.pumpAndSettle();
    expect(find.text('This account has been suspended. Contact support.'), findsOneWidget); verify(() => auth.signOut()).called(1);
  });

  testWidgets('auth error code maps to the specific credential message', (tester) async {
    final auth = MockAuthService();
    when(() => auth.signInWithEmailAndPassword(email: 'nobody@example.com', password: 'badpass')).thenThrow(const AuthServiceException('user-not-found', 'No account matches that email and password.'));
    tester.view.physicalSize = const Size(1000, 1200); tester.view.devicePixelRatio = 1; addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: LoginScreen(authService: auth)));
    await tester.enterText(find.byType(TextFormField).first, 'nobody@example.com'); await tester.enterText(find.byType(TextFormField).last, 'badpass');
    await tester.tap(find.text('Login')); await tester.pumpAndSettle();
    expect(find.text('No account matches that email and password.'), findsOneWidget);
  });

}
