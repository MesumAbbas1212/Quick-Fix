import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quickfix/models/app_language.dart';
import 'package:quickfix/models/job_model.dart';
import 'package:quickfix/models/user_model.dart';
import 'package:quickfix/models/worker_profile.dart';
import 'package:quickfix/services/job_service.dart';
import 'package:quickfix/services/language_service.dart';
import 'package:quickfix/services/location_service.dart';
import 'package:quickfix/services/profile_service.dart';
import 'package:quickfix/views/onboarding/worker_onboarding_screen.dart';
import 'package:quickfix/views/worker/worker_shell.dart';

class MockProfileService extends Mock implements ProfileService {}

class MockLanguageService extends Mock implements LanguageService {}

class MockLocationService extends Mock implements LocationService {}

class MockJobService extends Mock implements JobService {}

final UserModel _workerUser = UserModel(
  uid: 'w1',
  email: 'worker@example.com',
  fullName: 'Ahmed Worker',
  phone: '+92 300 1234567',
  role: UserRole.worker,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

void main() {
  late MockProfileService profileService;
  late MockLanguageService languageService;
  late MockLocationService locationService;
  late MockJobService jobService;

  final _languages = [
    const AppLanguage(code: 'en', nativeName: 'English'),
    const AppLanguage(code: 'ur', nativeName: 'اردو'),
    const AppLanguage(code: 'sd', nativeName: 'سنڌي'),
  ];

  setUp(() {
    profileService = MockProfileService();
    languageService = MockLanguageService();
    locationService = MockLocationService();
    jobService = MockJobService();
    when(() => profileService.getWorkerProfile('w1'))
        .thenAnswer((_) async => null);
    when(() => profileService.saveWorkerProfile(any()))
        .thenAnswer((_) async {});
    when(() => languageService.getAvailableLanguages())
        .thenAnswer((_) async => _languages);
    when(() => jobService.watchOpenJobs())
        .thenAnswer((_) => Stream<List<JobModel>>.value([]));
    when(() => profileService.watchWorkerProfile('w1'))
        .thenAnswer((_) => Stream<WorkerProfile?>.value(null));
  });

  Future<void> pumpOnboarding(
    WidgetTester tester, {
    bool returnToShell = false,
  }) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: WorkerOnboardingScreen(
          user: _workerUser,
          profileService: profileService,
          languageService: languageService,
          locationService: locationService,
          jobService: returnToShell ? jobService : null,
          returnToShell: returnToShell,
        ),
      ),
    );
    // Flush the existing-profile load and the language fetch.
    await tester.pumpAndSettle();
  }

  String _fieldText(WidgetTester tester, String key) {
    final field =
        tester.widget<TextField>(find.byKey(Key(key)));
    return field.controller!.text;
  }

  testWidgets('step one requires at least one profession', (tester) async {
    await pumpOnboarding(tester);

    expect(find.text('Set up your profile'), findsOneWidget);
    expect(find.byKey(const Key('onboarding-back')), findsNothing);
    expect(find.byKey(const Key('profession-cleaning')), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('onboarding-next-button')));
    await tester.tap(find.byKey(const Key('onboarding-next-button')));
    await tester.pumpAndSettle();

    expect(find.text('Choose at least one profession.'), findsOneWidget);
    expect(find.byKey(const Key('min-budget-field')), findsNothing);
  });

  testWidgets('selecting professions advances to budget step', (tester) async {
    await pumpOnboarding(tester);

    await tester.tap(find.byKey(const Key('profession-cleaning')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('onboarding-next-button')));
    await tester.tap(find.byKey(const Key('onboarding-next-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('min-budget-field')), findsOneWidget);
    expect(find.byKey(const Key('max-budget-field')), findsOneWidget);
    expect(find.byKey(const Key('service-radius-slider')), findsOneWidget);
    expect(find.byKey(const Key('onboarding-back')), findsOneWidget);
  });

  testWidgets('budget step validates min and max', (tester) async {
    await pumpOnboarding(tester);
    await tester.tap(find.byKey(const Key('profession-cleaning')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('onboarding-next-button')));
    await tester.tap(find.byKey(const Key('onboarding-next-button')));
    await tester.pumpAndSettle();

    // Empty budgets → invalid.
    await tester.tap(find.byKey(const Key('onboarding-next-button')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Enter valid amounts'), findsOneWidget);

    // min > max → invalid.
    await tester.enterText(find.byKey(const Key('min-budget-field')), '5000');
    await tester.enterText(find.byKey(const Key('max-budget-field')), '1000');
    await tester.tap(find.byKey(const Key('onboarding-next-button')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Enter valid amounts'), findsOneWidget);

    // Valid → advances to about step.
    await tester.enterText(find.byKey(const Key('min-budget-field')), '1000');
    await tester.enterText(find.byKey(const Key('max-budget-field')), '5000');
    await tester.tap(find.byKey(const Key('onboarding-next-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('about-field')), findsOneWidget);
    expect(find.byKey(const Key('add-avatar-button')), findsOneWidget);
    expect(find.text('Save profile'), findsOneWidget);
  });

  testWidgets('back button returns to the professions step', (tester) async {
    await pumpOnboarding(tester);
    await tester.tap(find.byKey(const Key('profession-cleaning')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('onboarding-next-button')));
    await tester.tap(find.byKey(const Key('onboarding-next-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('min-budget-field')), findsOneWidget);

    await tester.tap(find.byKey(const Key('onboarding-back')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('profession-cleaning')), findsOneWidget);
    expect(find.byKey(const Key('min-budget-field')), findsNothing);
  });

  testWidgets('save submits the profile and pops true', (tester) async {
    await pumpOnboarding(tester);
    await tester.tap(find.byKey(const Key('profession-cleaning')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('onboarding-next-button')));
    await tester.tap(find.byKey(const Key('onboarding-next-button')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('min-budget-field')), '1500');
    await tester.enterText(find.byKey(const Key('max-budget-field')), '4500');
    await tester.tap(find.byKey(const Key('onboarding-next-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('about-field')),
      'Experienced electrician.',
    );
    await tester.tap(find.byKey(const Key('language-ur')));
    await tester.pump();

    await tester.ensureVisible(find.byKey(const Key('onboarding-next-button')));
    await tester.tap(find.byKey(const Key('onboarding-next-button')));
    await tester.pumpAndSettle();

    final profiles = verify(
      () => profileService.saveWorkerProfile(captureAny()),
    ).captured.cast<WorkerProfile>();
    expect(profiles, hasLength(1));
    final saved = profiles.single;
    expect(saved.uid, 'w1');
    expect(saved.fullName, 'Ahmed Worker');
    expect(saved.professions, [JobCategory.cleaning]);
    expect(saved.minBudget, 1500);
    expect(saved.maxBudget, 4500);
    expect(saved.languages, ['اردو']);
    expect(saved.about, 'Experienced electrician.');
    expect(saved.createdAt, DateTime(2026, 1, 1));

    expect(find.byType(WorkerOnboardingScreen), findsNothing);
  });

  testWidgets('returnToShell replaces the wizard with the worker shell',
      (tester) async {
    await pumpOnboarding(tester, returnToShell: true);
    await tester.tap(find.byKey(const Key('profession-cleaning')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('onboarding-next-button')));
    await tester.tap(find.byKey(const Key('onboarding-next-button')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('min-budget-field')), '1000');
    await tester.enterText(find.byKey(const Key('max-budget-field')), '3000');
    await tester.tap(find.byKey(const Key('onboarding-next-button')));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('onboarding-next-button')));
    await tester.tap(find.byKey(const Key('onboarding-next-button')));
    await tester.pumpAndSettle();

    expect(find.byType(WorkerOnboardingScreen), findsNothing);
    expect(find.byType(WorkerShell), findsOneWidget);
  });

  testWidgets('existing profile is prefilled idempotently', (tester) async {
    when(() => profileService.getWorkerProfile('w1')).thenAnswer(
      (_) async => WorkerProfile(
        uid: 'w1',
        fullName: 'Ahmed Worker',
        email: 'worker@example.com',
        phone: '+92 300 1234567',
        professions: [JobCategory.applianceRepair],
        languages: ['اردو'],
        minBudget: 3000,
        maxBudget: 6000,
        rating: 4.5,
        completedJobs: 12,
        reviews: 12,
        serviceRadiusKm: 20,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 2, 1),
      ),
    );

    await pumpOnboarding(tester);

    // Step two should remember the budgets when the user returns to it.
    await tester.tap(find.byKey(const Key('onboarding-next-button')));
    await tester.pumpAndSettle();
    expect(_fieldText(tester, 'min-budget-field'), '3000');
    expect(_fieldText(tester, 'max-budget-field'), '6000');

    await tester.tap(find.byKey(const Key('onboarding-next-button')));
    await tester.pumpAndSettle();

    // Save must preserve rating/completedJobs/reviews/createdAt.
    await tester.ensureVisible(find.byKey(const Key('onboarding-next-button')));
    await tester.tap(find.byKey(const Key('onboarding-next-button')));
    await tester.pumpAndSettle();

    final saved = verify(
      () => profileService.saveWorkerProfile(captureAny()),
    ).captured.single as WorkerProfile;
    expect(saved.rating, 4.5);
    expect(saved.completedJobs, 12);
    expect(saved.reviews, 12);
    expect(saved.professions, [JobCategory.applianceRepair]);
    expect(saved.createdAt, DateTime(2026, 1, 1));
    expect(saved.serviceRadiusKm, 20);
  });
}
