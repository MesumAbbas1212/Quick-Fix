import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quickfix/controllers/auth_controller.dart';
import 'package:quickfix/models/review_model.dart';
import 'package:quickfix/models/user_model.dart';
import 'package:quickfix/services/auth_service.dart';
import 'package:quickfix/services/review_service.dart';
import 'package:quickfix/views/auth/login_screen.dart';
import 'package:quickfix/views/profile/profile_screen.dart';

class MockAuthService extends Mock implements AuthService {}

class MockReviewService extends Mock implements ReviewService {
  @override
  Stream<List<Review>> watchReviewsForWorker(String workerId) =>
      Stream.value(const <Review>[]);
}

UserModel _user(UserRole role) {
  return UserModel(
    uid: 'u1',
    email: 'test@quickfix.com',
    fullName: 'Test User',
    phone: '03001234567',
    role: role,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );
}

void main() {
  late MockAuthService auth;
  late AuthController controller;

  setUp(() {
    auth = MockAuthService();
    controller = AuthController();
    when(() => auth.signOut()).thenAnswer((_) async {});
  });

  Future<void> pumpProfile(WidgetTester tester, UserRole role) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: ProfileScreen(
        user: _user(role),
        authService: auth,
        authController: controller,
        reviewService: MockReviewService(),
      ),
    ));
  }

  testWidgets('shows confirm dialog on Log Out tap', (tester) async {
    await pumpProfile(tester, UserRole.user);

    await tester.tap(find.text('Log Out'));
    await tester.pumpAndSettle();

    expect(find.text('Are you sure you want to log out?'), findsOneWidget);
  });

  testWidgets('cancel keeps session intact', (tester) async {
    await pumpProfile(tester, UserRole.user);

    await tester.tap(find.text('Log Out'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    verifyNever(() => auth.signOut());
    expect(controller.isAuthenticated, isFalse);
    expect(find.byType(LoginScreen), findsNothing);
    expect(find.text('Log Out'), findsOneWidget);
  });

  testWidgets('confirming logs out, clears session and navigates to login',
      (tester) async {
    controller.setSession(userId: 'u1', role: 'user');
    await pumpProfile(tester, UserRole.user);

    await tester.tap(find.text('Log Out'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yes, Log Out'));
    await tester.pumpAndSettle();

    verify(() => auth.signOut()).called(1);
    expect(controller.isAuthenticated, isFalse);
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('worker profile still shows logout flow', (tester) async {
    controller.setSession(userId: 'u1', role: 'worker');
    await pumpProfile(tester, UserRole.worker);

    await tester.ensureVisible(find.text('Log Out'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log Out'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yes, Log Out'));
    await tester.pumpAndSettle();

    verify(() => auth.signOut()).called(1);
    expect(find.byType(LoginScreen), findsOneWidget);
  });
}
