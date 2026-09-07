import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quickfix/controllers/auth_controller.dart';
import 'package:quickfix/models/job_model.dart';
import 'package:quickfix/models/review_model.dart';
import 'package:quickfix/models/user_model.dart';
import 'package:quickfix/services/auth_service.dart';
import 'package:quickfix/services/job_service.dart';
import 'package:quickfix/services/profile_service.dart';
import 'package:quickfix/services/review_service.dart';
import 'package:quickfix/views/jobs/my_jobs_screen.dart';
import 'package:quickfix/views/profile/profile_screen.dart';

class MockAuthService extends Mock implements AuthService {}

class MockProfileService extends Mock implements ProfileService {}

class MockJobService extends Mock implements JobService {}

class MockReviewService extends Mock implements ReviewService {
  @override
  Stream<List<Review>> watchReviewsForWorker(String workerId) =>
      Stream.value(const <Review>[]);
}

UserModel _user(UserRole role, {String? avatarUrl}) {
  return UserModel(
    uid: 'u1',
    email: 'test@quickfix.com',
    fullName: 'Test User',
    phone: '03001234567',
    role: role,
    avatarUrl: avatarUrl,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );
}

void main() {
  late MockAuthService auth;
  late MockProfileService profileService;
  late MockJobService jobService;

  setUp(() {
    auth = MockAuthService();
    profileService = MockProfileService();
    jobService = MockJobService();
    when(() => auth.signOut()).thenAnswer((_) async {});
    when(() => profileService.watchWorkerProfile('u1'))
        .thenAnswer((_) => Stream.value(null));
    when(() => jobService.watchWorkerJobs('u1'))
        .thenAnswer((_) => Stream.value(const <JobModel>[]));
  });

  Future<void> pumpProfile(
    WidgetTester tester,
    UserModel user, {
    AuthController? controller,
  }) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: ProfileScreen(
        user: user,
        authService: auth,
        authController: controller,
        reviewService: MockReviewService(),
        profileService: profileService,
        jobService: jobService,
      ),
    ));
    await tester.pump();
  }

  testWidgets('reflects updated name from parent without re-login',
      (tester) async {
    // Regression: ProfileScreen used to ignore widget.user changes unless the
    // uid changed, so profile edits needed a logout to show up.
    await pumpProfile(tester, _user(UserRole.user));

    await tester.pumpWidget(MaterialApp(
      home: ProfileScreen(
        user: _user(UserRole.user).copyWith(fullName: 'Renamed Person'),
        authService: auth,
        reviewService: MockReviewService(),
        profileService: profileService,
      ),
    ));
    await tester.pump();

    expect(find.text('Renamed Person'), findsOneWidget);
    expect(find.text('Test User'), findsNothing);
  });

  testWidgets('reflects updated avatar from parent without re-login',
      (tester) async {
    await pumpProfile(tester, _user(UserRole.user));

    await tester.pumpWidget(MaterialApp(
      home: ProfileScreen(
        user: _user(UserRole.user)
            .copyWith(avatarUrl: '/data/avatars/new.png'),
        authService: auth,
        reviewService: MockReviewService(),
        profileService: profileService,
        jobService: jobService,
      ),
    ));
    await tester.pump();

    // The avatar URL is passed into the UserAvatar widget.
    final avatar = tester.widget<ProfileScreen>(find.byType(ProfileScreen));
    expect(avatar.user.avatarUrl, '/data/avatars/new.png');
  });

  testWidgets('worker menu shows My Job History opening MyJobsScreen',
      (tester) async {
    await pumpProfile(tester, _user(UserRole.worker));

    await tester.ensureVisible(find.text('My Job History'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('My Job History'));
    await tester.pumpAndSettle();

    expect(find.byType(MyJobsScreen), findsOneWidget);
  });
}
