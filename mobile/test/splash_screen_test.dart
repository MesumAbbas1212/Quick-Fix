import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quickfix/models/user_model.dart';
import 'package:quickfix/services/auth_service.dart';
import 'package:quickfix/views/auth/app_shell.dart';
import 'package:quickfix/views/auth/login_screen.dart';
import 'package:quickfix/views/auth/splash_screen.dart';

class MockAuthService extends Mock implements AuthService {}

class FakeAuthUser extends Fake implements User {
  @override
  final String uid;

  FakeAuthUser(this.uid);
}

UserModel _user() {
  return UserModel(
    uid: 'u1',
    email: 'test@quickfix.com',
    fullName: 'Test User',
    phone: '03001234567',
    role: UserRole.user,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );
}

void main() {
  group('SplashScreen', () {
    testWidgets('routes an unsigned user to the login screen', (tester) async {
      final auth = MockAuthService();
      when(() => auth.authStateChanges)
          .thenAnswer((_) => Stream.value(null));

      await tester.pumpWidget(
        MaterialApp(home: SplashScreen(authService: auth)),
      );
      await tester.pump();

      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('routes a signed-in user with a profile to the app shell',
        (tester) async {
      final auth = MockAuthService();
      final user = _user();
      when(() => auth.authStateChanges)
          .thenAnswer((_) => Stream.value(FakeAuthUser('u1')));
      when(() => auth.getUserProfile('u1')).thenAnswer((_) async => user);
      // AppShell receives the same mock and streams the user from it.
      when(() => auth.watchUser('u1')).thenAnswer((_) => Stream.value(user));

      await tester.pumpWidget(
        MaterialApp(home: SplashScreen(authService: auth)),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(AppShell), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
    });

    testWidgets('falls back to login with a note when the profile is missing',
        (tester) async {
      final auth = MockAuthService();
      when(() => auth.authStateChanges)
          .thenAnswer((_) => Stream.value(FakeAuthUser('u1')));
      when(() => auth.getUserProfile('u1')).thenAnswer((_) async => null);

      await tester.pumpWidget(
        MaterialApp(home: SplashScreen(authService: auth)),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text("Couldn't load your profile. Please sign in again."),
          findsOneWidget);
    });

    testWidgets('times out to login when the auth state never emits',
        (tester) async {
      final auth = MockAuthService();
      when(() => auth.authStateChanges)
          .thenAnswer((_) => const Stream<User?>.empty());

      await tester.pumpWidget(
        MaterialApp(
          home: SplashScreen(
            authService: auth,
            resolveTimeout: const Duration(milliseconds: 50),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 80));

      expect(find.byType(LoginScreen), findsOneWidget);
    });
  });
}
