import 'helpers/visible.dart' as test_viewport;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quickfix/controllers/auth_controller.dart';
import 'package:quickfix/models/job_model.dart';
import 'package:quickfix/models/review_model.dart';
import 'package:quickfix/models/user_model.dart';
import 'package:quickfix/services/auth_service.dart';
import 'package:quickfix/services/job_service.dart';
import 'package:quickfix/services/payment_service.dart';
import 'package:quickfix/models/payment_model.dart';
import 'package:quickfix/views/worker/earnings_screen.dart';
import 'package:quickfix/services/profile_service.dart';
import 'package:quickfix/services/review_service.dart';
import 'package:quickfix/views/jobs/my_jobs_screen.dart';
import 'package:quickfix/views/profile/profile_screen.dart';
import 'package:quickfix/views/worker/rank_progress_screen.dart';

class MockAuthService extends Mock implements AuthService {}

class MockProfileService extends Mock implements ProfileService {}

class MockJobService extends Mock implements JobService {}
class MockPaymentService extends Mock implements PaymentService {}

class MockReviewService extends Mock implements ReviewService {
  @override
  Stream<List<Review>> watchReviewsForWorker(String workerId) =>
      Stream.value(const <Review>[]);

  @override
  Stream<List<Review>> watchReviewsByUser(String userId) =>
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
    when(() => jobService.watchUserJobs('u1'))
        .thenAnswer((_) => Stream.value(const <JobModel>[]));
  });

  Future<void> pumpProfile(
    WidgetTester tester,
    UserModel user, {
    AuthController? controller,
    PaymentService? paymentService,
  }) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: ProfileScreen(
        user: user,
        authService: auth,
        authController: controller,
        paymentService: paymentService,
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

    await test_viewport.reveal(tester, find.text('My Job History'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('My Job History'));
    await tester.pumpAndSettle();

    expect(find.byType(MyJobsScreen), findsOneWidget);
  });

  testWidgets('worker rank badge opens RankProgressScreen with the jobs service',
      (tester) async {
    when(() => jobService.watchCompletedJobsForWorker('u1'))
        .thenAnswer((_) => Stream.value(const <JobModel>[]));
    await pumpProfile(tester, _user(UserRole.worker));
    await tester.tap(find.byKey(const Key('rank-progress-entry')));
    await tester.pumpAndSettle();
    final progress = tester.widget<RankProgressScreen>(find.byType(RankProgressScreen));
    expect(progress.workerUid, 'u1');
    expect(progress.jobService, same(jobService));
    expect(find.text('0 jobs completed in the last 12 months'), findsOneWidget);
  });

  testWidgets('worker Earnings menu opens the real earnings page', (tester) async {
    final payments = MockPaymentService();
    when(() => payments.watchPaymentsByWorker('u1')).thenAnswer((_) => Stream.value(<Payment>[]));
    when(() => jobService.watchCompletedJobsForWorker('u1')).thenAnswer((_) => Stream.value(<JobModel>[]));
    await pumpProfile(tester, _user(UserRole.worker), paymentService: payments);
    await test_viewport.reveal(tester, find.text('Earnings'));
    await tester.tap(find.text('Earnings'));
    await tester.pumpAndSettle();
    final page = tester.widget<EarningsScreen>(find.byType(EarningsScreen));
    expect(page.workerId, 'u1');
    expect(page.paymentService, same(payments));
    verify(() => payments.watchPaymentsByWorker('u1')).called(1);
  });

}
