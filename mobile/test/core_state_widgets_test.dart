import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quickfix/controllers/auth_controller.dart';
import 'package:quickfix/core/theme/app_theme.dart';
import 'package:quickfix/core/widgets/app_card.dart';
import 'package:quickfix/core/widgets/empty_state.dart';
import 'package:quickfix/core/widgets/error_state.dart';
import 'package:quickfix/core/widgets/job_dispute_link.dart';
import 'package:quickfix/core/widgets/loading_list.dart';
import 'package:quickfix/core/widgets/offline_banner.dart';
import 'package:quickfix/core/widgets/quote_feature_entry.dart';
import 'package:quickfix/core/widgets/section_header.dart';
import 'package:quickfix/models/app_language.dart';
import 'package:quickfix/models/app_notification.dart';
import 'package:quickfix/models/app_release_config.dart';
import 'package:quickfix/models/chat_message.dart';
import 'package:quickfix/models/job_model.dart';
import 'package:quickfix/models/job_request.dart';
import 'package:quickfix/models/payment_model.dart';
import 'package:quickfix/models/performance_report.dart';
import 'package:quickfix/models/payout_request.dart';
import 'package:quickfix/models/review_model.dart';
import 'package:quickfix/models/saved_address.dart';
import 'package:quickfix/models/saved_worker.dart';
import 'package:quickfix/models/service_category.dart';
import 'package:quickfix/models/user_model.dart';
import 'package:quickfix/models/worker_content.dart';
import 'package:quickfix/models/worker_profile.dart';
import 'package:quickfix/services/account_deletion_service.dart';
import 'package:quickfix/services/app_release_service.dart';
import 'package:quickfix/services/auth_service.dart';
import 'package:quickfix/services/category_service.dart';
import 'package:quickfix/services/chat_service.dart';
import 'package:quickfix/services/client_activity_service.dart';
import 'package:quickfix/services/dispute_service.dart';
import 'package:quickfix/services/job_request_service.dart';
import 'package:quickfix/services/job_service.dart';
import 'package:quickfix/services/language_service.dart';
import 'package:quickfix/services/location_service.dart';
import 'package:quickfix/services/map_launcher.dart';
import 'package:quickfix/services/notification_service.dart';
import 'package:quickfix/services/performance_service.dart';
import 'package:quickfix/services/payment_service.dart';
import 'package:quickfix/services/payout_service.dart';
import 'package:quickfix/services/preferences_service.dart';
import 'package:quickfix/services/profile_service.dart';
import 'package:quickfix/services/quote_service.dart';
import 'package:quickfix/services/report_service.dart';
import 'package:quickfix/services/review_service.dart';
import 'package:quickfix/services/translation_service.dart';
import 'package:quickfix/services/verification_service.dart';
import 'package:quickfix/services/worker_comparison_service.dart';
import 'package:quickfix/services/worker_filter_service.dart';
import 'package:quickfix/views/admin/report_screen.dart';
import 'package:quickfix/views/auth/force_update_screen.dart';
import 'package:quickfix/views/auth/login_screen.dart';
import 'package:quickfix/views/auth/signup_screen.dart';
import 'package:quickfix/views/auth/splash_screen.dart';
import 'package:quickfix/views/chat/chat_screen.dart';
import 'package:quickfix/views/chat/conversations_screen.dart';
import 'package:quickfix/views/chat/new_chat_screen.dart';
import 'package:quickfix/views/client/address_book_screen.dart';
import 'package:quickfix/views/client/category_grid_screen.dart';
import 'package:quickfix/views/client/client_home_screen.dart';
import 'package:quickfix/views/client/client_job_detail_screen.dart';
import 'package:quickfix/views/client/location_picker_screen.dart';
import 'package:quickfix/views/client/saved_workers_screen.dart';
import 'package:quickfix/views/client/search_filter_screen.dart';
import 'package:quickfix/views/client/worker_comparison_screen.dart';
import 'package:quickfix/views/client/worker_detail_screen.dart';
import 'package:quickfix/views/client/worker_reviews_screen.dart';
import 'package:quickfix/views/client/workers_screen.dart';
import 'package:quickfix/views/client/work_history_screen.dart';
import 'package:quickfix/views/jobs/dispute_screen.dart';
import 'package:quickfix/views/jobs/job_applicants_screen.dart';
import 'package:quickfix/views/jobs/job_request_screen.dart';
import 'package:quickfix/views/jobs/job_tracking_screen.dart';
import 'package:quickfix/views/jobs/my_jobs_screen.dart';
import 'package:quickfix/views/jobs/navigate_to_job_screen.dart';
import 'package:quickfix/views/jobs/post_job_screen.dart';
import 'package:quickfix/views/jobs/quote_request_screen.dart';
import 'package:quickfix/views/jobs/reschedule_job_screen.dart';
import 'package:quickfix/views/jobs/withdraw_request_screen.dart';
import 'package:quickfix/views/notifications/notifications_screen.dart';
import 'package:quickfix/views/onboarding/onboarding_carousel.dart';
import 'package:quickfix/views/onboarding/worker_onboarding_screen.dart';
import 'package:quickfix/views/payments/payment_history_screen.dart';
import 'package:quickfix/views/payments/payment_screen.dart';
import 'package:quickfix/views/profile/edit_profile_screen.dart';
import 'package:quickfix/views/profile/profile_screen.dart';
import 'package:quickfix/views/reviews/my_reviews_screen.dart';
import 'package:quickfix/views/reviews/review_screen.dart';
import 'package:quickfix/views/settings/delete_account_screen.dart';
import 'package:quickfix/views/settings/help_centre_screen.dart';
import 'package:quickfix/views/settings/language_picker_screen.dart';
import 'package:quickfix/views/settings/legal_screen.dart';
import 'package:quickfix/views/settings/permission_explainer_screen.dart';
import 'package:quickfix/views/settings/settings_screen.dart';
import 'package:quickfix/views/worker/availability_settings_screen.dart';
import 'package:quickfix/views/worker/certifications_screen.dart';
import 'package:quickfix/views/worker/client_profile_screen.dart';
import 'package:quickfix/views/worker/earnings_screen.dart';
import 'package:quickfix/views/worker/job_alert_preferences_screen.dart';
import 'package:quickfix/views/worker/job_schedule_screen.dart';
import 'package:quickfix/views/worker/performance_screen.dart';
import 'package:quickfix/views/worker/portfolio_screen.dart';
import 'package:quickfix/views/worker/payout_screen.dart';
import 'package:quickfix/views/worker/rank_progress_screen.dart';
import 'package:quickfix/views/worker/verification_screen.dart';
import 'package:quickfix/views/worker/worker_dashboard_screen.dart';

import 'helpers/visible.dart' as test_viewport;

class MockPreferences extends Mock implements PreferencesService {}

class MockLocationService extends Mock implements LocationService {}

class MockRelease extends Mock implements AppReleaseService {}

class MockLanguages extends Mock implements LanguageService {}

class MockVerification extends Mock implements VerificationService {}

class MockImages extends Mock implements LocalImageStore {}

class MockPicker extends Mock implements ImagePicker {}

class MockAuth extends Mock implements AuthService {}

class MockAuthController extends Mock implements AuthController {}

class MockDeletion extends Mock implements AccountDeletionService {}

class MockProfiles extends Mock implements ProfileService {}

class MockNotifications extends Mock implements NotificationService {}

class MockJobs extends Mock implements JobService {}

class MockRequests extends Mock implements JobRequestService {}

class MockReviews extends Mock implements ReviewService {}

class MockTranslation extends Mock implements TranslationService {}

class MockChat extends Mock implements ChatService {}

class MockPayments extends Mock implements PaymentService {}

class MockPayouts extends Mock implements PayoutService {}

class MockPerformance extends Mock implements PerformanceService {}

class MockCases extends Mock implements DisputeService {}

class MockQuotes extends Mock implements QuoteService {}

class MockComparison extends Mock implements WorkerComparisonService {}

class MockActivity extends Mock implements ClientActivityService {}

class MockCategories extends Mock implements CategoryService {}

class MockLauncher extends Mock implements MapLauncher {}

class MockFilters extends Mock implements WorkerFilterService {}

class MockReport extends Mock implements ReportService {}

void _noopRetry() {}

UserModel user({UserRole role = UserRole.user}) => UserModel(
      uid: 'u',
      email: 'c@example.com',
      fullName: 'Client One',
      phone: '03001234567',
      role: role,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

WorkerProfile workerProfile({String uid = 'w1', String name = 'Imran Khan'}) =>
    WorkerProfile(
      uid: uid,
      fullName: name,
      email: '$uid@example.com',
      about: 'Experienced professional.',
      professions: const [JobCategory.plumbing, JobCategory.electrical],
      languages: const ['Urdu', 'English'],
      minBudget: 1500,
      maxBudget: 4000,
      rating: 4.5,
      completedJobs: 27,
      reviews: 120,
      isAvailable: true,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

JobModel job({JobStatus status = JobStatus.assigned}) => JobModel(
      id: 'j',
      userId: 'u',
      workerId: 'w',
      title: 'Leaky kitchen tap',
      description: 'Tap drips constantly.',
      category: JobCategory.plumbing,
      address: 'Model Town, Lahore',
      location: const GeoPoint(31.5204, 74.3587),
      budgetMin: 1000,
      budgetMax: 2500,
      status: status,
      preferredDate: DateTime(2026, 10, 19),
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

JobModel booking({DateTime? day}) => JobModel(
      id: 'j',
      userId: 'c',
      workerId: 'w',
      title: 'Booked work',
      description: '',
      category: JobCategory.plumbing,
      address: '',
      location: const GeoPoint(33, 72),
      budgetMin: 1,
      budgetMax: 2,
      status: JobStatus.assigned,
      preferredDate: day ?? DateTime(2026, 10, 19),
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

const AppReleaseConfig updateConfig = AppReleaseConfig(
  minBuild: 2,
  latestBuild: 3,
  message: 'A newer release is available.',
  storeUrl: 'https://play.google.com/store/apps/details?id=com.example.quickfix',
);

/// Pump [screen] at the narrowest supported handset width with an
/// optional text scale, then settle. Any uncaught layout error
/// (including a RenderFlex overflow) surfaces via takeException.
Future<void> pumpNarrow(WidgetTester tester, Widget screen,
    {double scale = 1.0}) async {
  tester.view.physicalSize = const Size(320, 640);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.lightTheme,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
    home: screen,
  ));
  await tester.pump();
  await tester.pumpAndSettle();
}

Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

bool _focusWithin(Element root) {
  final context = FocusManager.instance.primaryFocus?.context;
  if (context == null) return false;
  var element = context;
  while (element != null) {
    if (element == root) return true;
    element = element.parent is Element ? element.parent as Element : null;
  }
  return false;
}

/// Every rendered dialog action button must be at least 44x44.
void _assertDialogTouchTargets(WidgetTester tester) {
  final buttons = find.descendant(
      of: find.byType(AlertDialog), matching: find.byType(TextButton));
  final count = buttons.evaluate().length;
  expect(count, greaterThan(0));
  for (var i = 0; i < count; i++) {
    final size = tester.getSize(buttons.at(i));
    expect(size.width, greaterThanOrEqualTo(44));
    expect(size.height, greaterThanOrEqualTo(44));
  }
}

void main() {
  group('SectionHeader', () {
    testWidgets('renders the title', (tester) async {
      await tester.pumpWidget(wrap(const SectionHeader(title: 'Work History')));
      expect(find.text('Work History'), findsOneWidget);
    });

    testWidgets('renders a trailing action', (tester) async {
      await tester.pumpWidget(wrap(const SectionHeader(
        title: 'Reviews',
        trailing: Text('See all'),
      )));
      expect(find.text('Reviews'), findsOneWidget);
      expect(find.text('See all'), findsOneWidget);
    });

    testWidgets('draws a divider only when requested', (tester) async {
      await tester.pumpWidget(wrap(const SectionHeader(title: 'A')));
      expect(find.byType(Divider), findsNothing);

      await tester.pumpWidget(
        wrap(const SectionHeader(title: 'A', showDivider: true)),
      );
      expect(find.byType(Divider), findsOneWidget);
    });
  });

  group('EmptyState', () {
    testWidgets('renders icon, title, message and action', (tester) async {
      await tester.pumpWidget(wrap(const EmptyState(
        icon: Icons.work_outline,
        title: 'No jobs yet',
        message: 'Post your first job to get started.',
        action: Text('Post a job'),
      )));
      expect(find.byIcon(Icons.work_outline), findsOneWidget);
      expect(find.text('No jobs yet'), findsOneWidget);
      expect(
        find.text('Post your first job to get started.'),
        findsOneWidget,
      );
      expect(find.text('Post a job'), findsOneWidget);
    });

    testWidgets('omits the action when not provided', (tester) async {
      await tester.pumpWidget(wrap(const EmptyState(
        icon: Icons.star,
        title: 'Nothing here',
        message: 'Check back later.',
      )));
      expect(find.text('Nothing here'), findsOneWidget);
    });
  });

  group('ErrorState', () {
    testWidgets('renders a human message and fires retry', (tester) async {
      var retries = 0;
      await tester.pumpWidget(wrap(
        ErrorState(
          message: 'Could not load workers. Check your connection.',
          onRetry: () => retries++,
        ),
      ));

      expect(
        find.text('Could not load workers. Check your connection.'),
        findsOneWidget,
      );
      expect(find.text('Retry'), findsOneWidget);

      await tester.tap(find.byKey(const Key('error-retry-button')));
      expect(retries, 1);
    });

    testWidgets('renders without a retry button when no callback',
        (tester) async {
      await tester.pumpWidget(wrap(const ErrorState(
        message: 'Could not load data.',
      )));
      expect(find.byKey(const Key('error-retry-button')), findsNothing);
    });
  });

  group('LoadingList', () {
    testWidgets('renders the requested number of skeleton rows', (tester) async {
      await tester.pumpWidget(wrap(const LoadingList(rows: 3)));
      // Each row has a circular avatar placeholder.
      expect(find.byType(LoadingList), findsOneWidget);
    });

    testWidgets('defaults to four rows', (tester) async {
      await tester.pumpWidget(wrap(const LoadingList()));
      expect(find.byType(LoadingList), findsOneWidget);
    });

    testWidgets('never renders a spinner', (tester) async {
      await tester.pumpWidget(wrap(const LoadingList()));
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });
  testWidgets('AppCard ListTile paints above a real Material surface and can be tapped', (tester) async {
    var tapped = false;
    await tester.pumpWidget(wrap(AppCard(child: ListTile(title: const Text('Open card'), onTap: () { tapped = true; }))));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Open card'));
    expect(tapped, isTrue);
  });

  // ----------------------------------------------------------------
  // T2: narrow-viewport (320px) layout sweep over every screen added
  // by the build brief. Each entry is also pumped at 2.0 text scale.
  // ----------------------------------------------------------------
  group('narrow 320px layout sweep', () {
    final cases = <(String, Widget Function())>[
      ('ReportScreen', () {
        final service = MockReport();
        when(() => service.hasOpenReport(any(), any()))
            .thenAnswer((_) async => false);
        return ReportScreen(
          myId: 'me',
          reportedId: 'them',
          reportedName: 'the worker',
          reportService: service,
        );
      }),
      ('WorkerOnboardingScreen', () {
        final profiles = MockProfiles();
        final languages = MockLanguages();
        final jobs = MockJobs();
        final locations = MockLocationService();
        when(() => profiles.getWorkerProfile('u'))
            .thenAnswer((_) async => null);
        when(() => profiles.watchWorkerProfile('u'))
            .thenAnswer((_) => Stream.value(null));
        when(() => languages.getAvailableLanguages())
            .thenAnswer((_) async => const <AppLanguage>[]);
        when(() => jobs.watchOpenJobs())
            .thenAnswer((_) => Stream.value(const <JobModel>[]));
        when(() => locations.getPermissionStatus())
            .thenAnswer((_) async => LocationPermission.denied);
        return WorkerOnboardingScreen(
          user: user(role: UserRole.worker),
          profileService: profiles,
          languageService: languages,
          locationService: locations,
          jobService: jobs,
        );
      }),
      ('PaymentScreen', () {
        final jobs = MockJobs();
        final payments = MockPayments();
        final profiles = MockProfiles();
        when(() => jobs.watchJob('j'))
            .thenAnswer((_) => Stream.value(job()));
        when(() => payments.getPaidPaymentForJob('j'))
            .thenAnswer((_) async => null);
        when(() => profiles.watchWorkerProfile('w'))
            .thenAnswer((_) => Stream.value(null));
        return PaymentScreen(
          jobId: 'j',
          myId: 'me',
          jobService: jobs,
          paymentService: payments,
          profileService: profiles,
        );
      }),
      ('PaymentHistoryScreen', () {
        final payments = MockPayments();
        final jobs = MockJobs();
        final profiles = MockProfiles();
        final auth = MockAuth();
        when(() => payments.watchPaymentsByPayer('u'))
            .thenAnswer((_) => Stream.value(const <Payment>[]));
        when(() => payments.watchPaymentsByWorker('u'))
            .thenAnswer((_) => Stream.value(const <Payment>[]));
        when(() => jobs.getJob(any())).thenAnswer((_) async => null);
        when(() => profiles.getWorkerProfile(any()))
            .thenAnswer((_) async => null);
        when(() => auth.getUserProfile(any())).thenAnswer((_) async => null);
        return PaymentHistoryScreen(
          user: user(),
          paymentService: payments,
          jobService: jobs,
          profileService: profiles,
          authService: auth,
        );
      }),
      ('JobApplicantsScreen', () {
        final requests = MockRequests();
        final jobs = MockJobs();
        final profiles = MockProfiles();
        when(() => jobs.watchJob('j'))
            .thenAnswer((_) => Stream.value(job()));
        when(() => jobs.watchCompletedJobsForWorker(any()))
            .thenAnswer((_) => Stream.value(const <JobModel>[]));
        when(() => profiles.getWorkerProfile(any()))
            .thenAnswer((_) async => null);
        when(() => requests.watchUserRequests(any()))
            .thenAnswer((_) => Stream.value(const <JobRequest>[]));
        return JobApplicantsScreen(
          jobId: 'j',
          myId: 'me',
          jobRequestService: requests,
          jobService: jobs,
          profileService: profiles,
        );
      }),
      ('WorkerComparisonScreen', () {
        final comparison = MockComparison();
        when(() => comparison.annualCount(any()))
            .thenAnswer((_) async => 0);
        return WorkerComparisonScreen(
          myId: 'me',
          workers: [workerProfile(), workerProfile(uid: 'w2', name: 'Ali Raza')],
          comparisonService: comparison,
        );
      }),
      ('SearchFilterScreen', () {
        final categories = MockCategories();
        final languages = MockLanguages();
        final jobs = MockJobs();
        when(() => categories.getCategories())
            .thenAnswer((_) async => const <ServiceCategory>[]);
        when(() => languages.getAvailableLanguages())
            .thenAnswer((_) async => const <AppLanguage>[]);
        when(() => jobs.watchCompletedJobsForWorker(any()))
            .thenAnswer((_) => Stream.value(const <JobModel>[]));
        return SearchFilterScreen(
          pool: [workerProfile(), workerProfile(uid: 'w2', name: 'Ali Raza')],
          categoryService: categories,
          languageService: languages,
          jobService: jobs,
          filterService: WorkerFilterService(jobService: jobs),
        );
      }),
      ('CategoryGridScreen', () {
        final profiles = MockProfiles();
        final locations = MockLocationService();
        final jobs = MockJobs();
        when(() => locations.getPermissionStatus())
            .thenAnswer((_) async => LocationPermission.denied);
        when(() => profiles.searchWorkers(
              profession: any(named: 'profession'),
              fromLocation: any(named: 'fromLocation'),
              maxDistanceKm: any(named: 'maxDistanceKm'),
              limit: any(named: 'limit'),
            )).thenAnswer((_) async => const <WorkerProfile>[]);
        when(() => jobs.watchOpenJobs())
            .thenAnswer((_) => Stream.value(const <JobModel>[]));
        return CategoryGridScreen(
          user: user(),
          profileService: profiles,
          locationService: locations,
          jobService: jobs,
        );
      }),
      ('SavedWorkersScreen', () {
        final profiles = MockProfiles();
        final locations = MockLocationService();
        final filters = MockFilters();
        when(() => profiles.watchSavedWorkers('u'))
            .thenAnswer((_) => Stream.value(const <SavedWorker>[]));
        when(() => locations.getPermissionStatus())
            .thenAnswer((_) async => LocationPermission.denied);
        when(() => filters.loadAnnualCounts(any(), now: any(named: 'now')))
            .thenAnswer((_) async => <String, int>{});
        return SavedWorkersScreen(
          user: user(),
          profileService: profiles,
          locationService: locations,
          workerFilterService: filters,
        );
      }),
      ('JobTrackingScreen', () {
        final jobs = MockJobs();
        final profiles = MockProfiles();
        final auth = MockAuth();
        final chat = MockChat();
        final payments = MockPayments();
        final reviews = MockReviews();
        final launcher = MockLauncher();
        when(() => jobs.watchJob('j1'))
            .thenAnswer((_) => Stream.value(job()));
        when(() => auth.watchUser('w'))
            .thenAnswer((_) => Stream.value(null));
        when(() => chat.watchMessages(user1: any(named: 'user1'), user2: any(named: 'user2')))
            .thenAnswer((_) => Stream.value(const <ChatMessage>[]));
        when(() => chat.watchLatestSharedLocation(any(), any(),
                senderId: any(named: 'senderId'), since: any(named: 'since')))
            .thenAnswer((_) => Stream.value(null));
        when(() => profiles.watchWorkerProfile(any()))
            .thenAnswer((_) => Stream.value(null));
        when(() => payments.watchPaymentsByWorker(any()))
            .thenAnswer((_) => Stream.value(const <Payment>[]));
        when(() => reviews.watchReviewsForWorker(any()))
            .thenAnswer((_) => Stream.value(const <Review>[]));
        return JobTrackingScreen(
          jobId: 'j1',
          myId: 'w',
          jobService: jobs,
          profileService: profiles,
          authService: auth,
          chatService: chat,
          urlLauncher: launcher,
          paymentService: payments,
          reviewService: reviews,
        );
      }),
      ('AddressBookScreen', () {
        final profiles = MockProfiles();
        when(() => profiles.watchAddresses('u'))
            .thenAnswer((_) => Stream.value(const <SavedAddress>[]));
        return AddressBookScreen(userId: 'u', profileService: profiles);
      }),
      ('LocationPickerScreen', () {
        final locations = MockLocationService();
        when(() => locations.getPermissionStatus())
            .thenAnswer((_) async => LocationPermission.denied);
        return LocationPickerScreen(
            locationService: locations, urlLauncher: MockLauncher());
      }),
      ('QuoteRequestScreen (feature OFF)', () {
        final quotes = MockQuotes();
        when(() => quotes.isEnabled()).thenAnswer((_) async => false);
        return QuoteRequestScreen(user: user(), requestId: 'r', quoteService: quotes);
      }),
      ('RescheduleJobScreen', () {
        final jobs = MockJobs();
        when(() => jobs.watchJob('j'))
            .thenAnswer((_) => Stream.value(job()));
        return RescheduleJobScreen(jobId: 'j', userId: 'u', jobService: jobs);
      }),
      ('RescheduleJobScreen (cancel variant)', () {
        final jobs = MockJobs();
        when(() => jobs.watchJob('j'))
            .thenAnswer((_) => Stream.value(job()));
        return RescheduleJobScreen(
            jobId: 'j', userId: 'u', initialCancel: true, jobService: jobs);
      }),
      ('DisputeScreen', () {
        final cases = MockCases();
        final jobs = MockJobs();
        final payments = MockPayments();
        when(() => jobs.getJob('j'))
            .thenAnswer((_) async => job(status: JobStatus.completed));
        when(() => payments.getPaymentsForJob('j'))
            .thenAnswer((_) async => const <Payment>[]);
        when(() => cases.getForJob('j')).thenAnswer((_) async => null);
        return DisputeScreen(
          jobId: 'j',
          userId: 'u',
          disputeService: cases,
          jobService: jobs,
          paymentService: payments,
        );
      }),
      ('MyReviewsScreen', () {
        final reviews = MockReviews();
        final profiles = MockProfiles();
        when(() => reviews.watchReviewsByUser('u'))
            .thenAnswer((_) => Stream.value(const <Review>[]));
        when(() => profiles.getWorkerProfile(any()))
            .thenAnswer((_) async => null);
        return MyReviewsScreen(
            user: user(), reviewService: reviews, profileService: profiles);
      }),
      ('NotificationsScreen', () {
        final notifications = MockNotifications();
        when(() => notifications.watchItems('u'))
            .thenAnswer((_) => Stream.value(const <AppNotification>[]));
        return NotificationsScreen(
            user: user(), notificationService: notifications);
      }),
      ('HelpCentreScreen', () => const HelpCentreScreen()),
      ('SettingsScreen', () {
        final auth = MockAuth();
        final languages = MockLanguages();
        when(() => auth.watchUser('u'))
            .thenAnswer((_) => Stream.value(user()));
        when(() => languages.getAvailableLanguages())
            .thenAnswer((_) async => const <AppLanguage>[]);
        return SettingsScreen(
            user: user(), authService: auth, languageService: languages);
      }),
      ('EarningsScreen', () {
        final jobs = MockJobs();
        final payments = MockPayments();
        when(() => jobs.watchWorkerJobs('w1'))
            .thenAnswer((_) => Stream.value(const <JobModel>[]));
        when(() => jobs.watchCompletedJobsForWorker('w1'))
            .thenAnswer((_) => Stream.value(const <JobModel>[]));
        when(() => payments.watchPaymentsByWorker('w1'))
            .thenAnswer((_) => Stream.value(const <Payment>[]));
        return EarningsScreen(
          workerId: 'w1',
          jobService: jobs,
          paymentService: payments,
          clock: () => DateTime(2026, 10, 19),
        );
      }),
      ('PayoutScreen', () {
        final payouts = MockPayouts();
        when(() => payouts.load('w')).thenAnswer((_) async =>
            const PayoutSnapshot(receivedPaisa: 0, reservedPaisa: 0, revision: 0));
        return PayoutScreen(workerId: 'w', payoutService: payouts);
      }),
      ('AvailabilitySettingsScreen', () {
        final profiles = MockProfiles();
        when(() => profiles.getWorkerProfile('w'))
            .thenAnswer((_) async => null);
        return AvailabilitySettingsScreen(
            workerId: 'w', profileService: profiles);
      }),
      ('JobAlertPreferencesScreen', () {
        final profiles = MockProfiles();
        when(() => profiles.getWorkerProfile('w'))
            .thenAnswer((_) async => null);
        return JobAlertPreferencesScreen(
            workerId: 'w', profileService: profiles);
      }),
      ('PerformanceScreen', () {
        final performance = MockPerformance();
        when(() => performance.watch('w')).thenAnswer((_) => Stream.value(
            const PerformanceReport(completedJobs: 0, suggestion: 'More data')));
        return PerformanceScreen(
            workerId: 'w', performanceService: performance);
      }),
      ('RankProgressScreen', () {
        final jobs = MockJobs();
        when(() => jobs.watchCompletedJobsForWorker('w1'))
            .thenAnswer((_) => Stream.value(const <JobModel>[]));
        return RankProgressScreen(
          workerUid: 'w1',
          jobService: jobs,
          clock: () => DateTime(2026, 10, 19),
        );
      }),
      ('PortfolioScreen', () {
        final profiles = MockProfiles();
        when(() => profiles.watchPortfolio('w'))
            .thenAnswer((_) => Stream.value(const <PortfolioWork>[]));
        return PortfolioScreen(workerId: 'w', profileService: profiles);
      }),
      ('CertificationsScreen', () {
        final profiles = MockProfiles();
        when(() => profiles.watchCertificates('w'))
            .thenAnswer((_) => Stream.value(const <WorkerCertificate>[]));
        return CertificationsScreen(workerId: 'w', profileService: profiles);
      }),
      ('ClientProfileScreen', () {
        final activity = MockActivity();
        when(() => activity.watch('c')).thenAnswer((_) => Stream.value(null));
        return ClientProfileScreen(
            clientId: 'c', viewerId: 'w', activityService: activity);
      }),
      ('JobScheduleScreen', () {
        final jobs = MockJobs();
        final auth = MockAuth();
        when(() => jobs.watchScheduledJobs('w'))
            .thenAnswer((_) => Stream.value(const <JobModel>[]));
        when(() => auth.getUserProfile(any())).thenAnswer((_) async => null);
        return JobScheduleScreen(workerId: 'w', jobService: jobs, authService: auth);
      }),
      ('WithdrawRequestScreen', () {
        final requests = MockRequests();
        final jobs = MockJobs();
        when(() => requests.watchRequest('r'))
            .thenAnswer((_) => Stream.value(null));
        when(() => jobs.getJob('j')).thenAnswer((_) async => null);
        return WithdrawRequestScreen(
          requestId: 'r',
          workerId: 'w',
          requestService: requests,
          jobService: jobs,
        );
      }),
      ('NavigateToJobScreen', () {
        final jobs = MockJobs();
        final locations = MockLocationService();
        final chat = MockChat();
        when(() => jobs.getJob('j')).thenAnswer((_) async => job());
        when(() => locations.getPermissionStatus())
            .thenAnswer((_) async => LocationPermission.denied);
        when(() => chat.watchLatestSharedLocation(any(), any(),
                senderId: any(named: 'senderId'), since: any(named: 'since')))
            .thenAnswer((_) => Stream.value(null));
        return NavigateToJobScreen(
          jobId: 'j',
          workerId: 'w',
          jobService: jobs,
          locationService: locations,
          chatService: chat,
          urlLauncher: MockLauncher(),
        );
      }),
      ('SplashScreen', () {
        final auth = MockAuth();
        when(() => auth.authStateChanges)
            .thenAnswer((_) => Stream.value(null));
        when(() => auth.watchUser(any()))
            .thenAnswer((_) => Stream.value(null));
        when(() => auth.getUserProfile(any())).thenAnswer((_) async => null);
        return SplashScreen(authService: auth);
      }),
      ('OnboardingCarousel', () {
        final preferences = MockPreferences();
        when(() => preferences.markOnboardingSeen()).thenAnswer((_) async {});
        return OnboardingCarousel(preferencesService: preferences);
      }),
      ('PermissionExplainerScreen', () {
        final locations = MockLocationService();
        when(() => locations.getPermissionStatus())
            .thenAnswer((_) async => LocationPermission.denied);
        return PermissionExplainerScreen(
          purpose: 'to find nearby workers',
          locationService: locations,
        );
      }),
      ('OfflineBanner', () => const OfflineBanner(onRetry: _noopRetry)),
      ('ForceUpdateScreen', () {
        final release = MockRelease();
        when(() => release.openStore(any())).thenAnswer((_) async => true);
        return ForceUpdateScreen(
            config: updateConfig, currentBuild: 1, releaseService: release);
      }),
      ('LanguagePickerScreen', () {
        final languages = MockLanguages();
        final translations = MockTranslation();
        final auth = MockAuth();
        when(() => languages.getAvailableLanguages())
            .thenAnswer((_) async => const <AppLanguage>[]);
        when(() => translations.translate(any(), any()))
            .thenAnswer((_) async => '');
        when(() => auth.updateProfile(
                uid: any(named: 'uid'), preferredLanguage: any(named: 'preferredLanguage')))
            .thenAnswer((_) async {});
        return LanguagePickerScreen(
          initialCode: 'en',
          languageService: languages,
          translationService: translations,
          authService: auth,
        );
      }),
      ('VerificationScreen', () {
        final verification = MockVerification();
        when(() => verification.getVerification('u'))
            .thenAnswer((_) async => null);
        return VerificationScreen(
          user: user(role: UserRole.worker),
          verificationService: verification,
          imageStore: MockImages(),
          imagePicker: MockPicker(),
        );
      }),
      ('LegalScreen (terms)', () => const LegalScreen(initialTab: 0)),
      ('LegalScreen (privacy)', () => const LegalScreen(initialTab: 1)),
      ('DeleteAccountScreen', () {
        final deletion = MockDeletion();
        when(() => deletion.deleteAccount(
              uid: any(named: 'uid'),
              password: any(named: 'password'),
            )).thenAnswer((_) async {});
        return DeleteAccountScreen(
            user: user(), accountDeletionService: deletion);
      }),
      ('ChatScreen', () {
        final chat = MockChat();
        when(() => chat.watchMessages(user1: any(named: 'user1'), user2: any(named: 'user2')))
            .thenAnswer((_) => Stream.value(const <ChatMessage>[]));
        when(() => chat.markAsRead(
              conversationId: any(named: 'conversationId'),
              userId: any(named: 'userId'),
            )).thenAnswer((_) async {});
        when(() => chat.watchLatestSharedLocation(any(), any(),
                senderId: any(named: 'senderId'), since: any(named: 'since')))
            .thenAnswer((_) => Stream.value(null));
        return ChatScreen(
            peerName: 'Worker', peerId: 'peer-1', myId: 'me-1', chatService: chat);
      }),
      ('ConversationsScreen', () {
        final chat = MockChat();
        final auth = MockAuth();
        final profiles = MockProfiles();
        when(() => chat.watchConversations('u'))
            .thenAnswer((_) => Stream.value(const <ConversationPreview>[]));
        when(() => auth.getUserProfile(any())).thenAnswer((_) async => null);
        when(() => profiles.searchWorkers())
            .thenAnswer((_) async => const <WorkerProfile>[]);
        return ConversationsScreen(
          user: user(),
          chatService: chat,
          authService: auth,
          profileService: profiles,
        );
      }),
      ('NewChatScreen', () {
        final chat = MockChat();
        final profiles = MockProfiles();
        when(() => chat.watchMessages(user1: any(named: 'user1'), user2: any(named: 'user2')))
            .thenAnswer((_) => Stream.value(const <ChatMessage>[]));
        when(() => profiles.searchWorkers())
            .thenAnswer((_) async => const <WorkerProfile>[]);
        return NewChatScreen(
            user: user(), profileService: profiles, chatService: chat);
      }),
      ('WorkerDetailScreen', () {
        final reviews = MockReviews();
        final translations = MockTranslation();
        when(() => reviews.watchReviewsForWorker('w1'))
            .thenAnswer((_) => Stream.value(const <Review>[]));
        return WorkerDetailScreen(
          worker: workerProfile(),
          myId: 'me',
          reviewService: reviews,
          translationService: translations,
        );
      }),
      ('WorkHistoryScreen', () {
        final jobs = MockJobs();
        when(() => jobs.watchCompletedJobsForWorker('w'))
            .thenAnswer((_) => Stream.value(const <JobModel>[]));
        return WorkHistoryScreen(
            workerUid: 'w', workerName: 'Imran Khan', jobService: jobs);
      }),
      ('WorkerReviewsScreen', () {
        final reviews = MockReviews();
        final translations = MockTranslation();
        when(() => reviews.watchReviewsForWorker('w'))
            .thenAnswer((_) => Stream.value(const <Review>[]));
        when(() => translations.translate(any(), any()))
            .thenAnswer((_) async => '');
        return WorkerReviewsScreen(
          workerUid: 'w',
          workerName: 'Imran Khan',
          rating: 4.5,
          reviewCount: 120,
          userLanguage: 'en',
          reviewService: reviews,
          translationService: translations,
        );
      }),
      ('WorkersScreen', () {
        final profiles = MockProfiles();
        final locations = MockLocationService();
        when(() => locations.getPermissionStatus())
            .thenAnswer((_) async => LocationPermission.denied);
        when(() => profiles.searchWorkers(
              profession: any(named: 'profession'),
              fromLocation: any(named: 'fromLocation'),
              maxDistanceKm: any(named: 'maxDistanceKm'),
              limit: any(named: 'limit'),
            )).thenAnswer((_) async => const <WorkerProfile>[]);
        return WorkersScreen(
          user: user(),
          profileService: profiles,
          locationService: locations,
        );
      }),
      ('ClientHomeScreen', () {
        final jobs = MockJobs();
        final locations = MockLocationService();
        final profiles = MockProfiles();
        final notifications = MockNotifications();
        when(() => jobs.watchUserJobs('u'))
            .thenAnswer((_) => Stream.value(const <JobModel>[]));
        when(() => locations.getPermissionStatus())
            .thenAnswer((_) async => LocationPermission.denied);
        when(() => profiles.searchWorkers(
              profession: any(named: 'profession'),
              fromLocation: any(named: 'fromLocation'),
              maxDistanceKm: any(named: 'maxDistanceKm'),
              limit: any(named: 'limit'),
            )).thenAnswer((_) async => const <WorkerProfile>[]);
        when(() => notifications.watchItems('u'))
            .thenAnswer((_) => Stream.value(const <AppNotification>[]));
        return ClientHomeScreen(
          user: user(),
          jobService: jobs,
          locationService: locations,
          profileService: profiles,
          notificationService: notifications,
        );
      }),
      ('ClientJobDetailScreen', () {
        final jobs = MockJobs();
        final requests = MockRequests();
        final images = MockImages();
        when(() => jobs.watchJob('j'))
            .thenAnswer((_) => Stream.value(job()));
        when(() => jobs.getJob('j')).thenAnswer((_) async => job());
        when(() => requests.watchPendingCountForJob('j'))
            .thenAnswer((_) => Stream.value(0));
        when(() => requests.watchUserRequests(any(), any()))
            .thenAnswer((_) => Stream.value(const <JobRequest>[]));
        when(() => images.readImage(any())).thenAnswer((_) async => null);
        return ClientJobDetailScreen(
            job: job(), currentUserId: 'u', imageStore: images);
      }),
      ('PostJobScreen', () => PostJobScreen(
            userId: 'user-1',
            locationService: LocationService(provider: _DeniedProvider()),
          )),
      ('LoginScreen', () => const LoginScreen()),
      ('SignUpScreen', () {
        final languages = MockLanguages();
        when(() => languages.getAvailableLanguages())
            .thenAnswer((_) async => const <AppLanguage>[]);
        return SignUpScreen(
            languageService: languages, authService: MockAuth());
      }),
      ('MyJobsScreen', () {
        final jobs = MockJobs();
        final payments = MockPayments();
        final profiles = MockProfiles();
        when(() => jobs.watchWorkerJobs('w1'))
            .thenAnswer((_) => Stream.value(const <JobModel>[]));
        when(() => jobs.watchCompletedJobsForWorker('w1'))
            .thenAnswer((_) => Stream.value(const <JobModel>[]));
        when(() => payments.watchPaymentsByWorker('w1'))
            .thenAnswer((_) => Stream.value(const <Payment>[]));
        when(() => profiles.getWorkerProfile(any()))
            .thenAnswer((_) async => null);
        return MyJobsScreen(
          workerId: 'w1',
          jobService: jobs,
          paymentService: payments,
          profileService: profiles,
        );
      }),
      ('JobRequestScreen', () => JobRequestScreen(job: job())),
      ('ReviewScreen', () =>
          const ReviewScreen(jobId: 'j', workerId: 'w', reviewerId: 'u')),
      ('EditProfileScreen', () {
        final auth = MockAuth();
        final images = MockImages();
        when(() => auth.updateProfile(
                uid: any(named: 'uid'), fullName: any(named: 'fullName')))
            .thenAnswer((_) async {});
        when(() => images.readImage(any())).thenAnswer((_) async => null);
        return EditProfileScreen(
            user: user(), authService: auth, imageStore: images);
      }),
      ('ProfileScreen', () {
        final auth = MockAuth();
        final payments = MockPayments();
        final reviews = MockReviews();
        final profiles = MockProfiles();
        final jobs = MockJobs();
        when(() => auth.watchUser('u'))
            .thenAnswer((_) => Stream.value(user()));
        when(() => payments.watchPaymentsByWorker('u'))
            .thenAnswer((_) => Stream.value(const <Payment>[]));
        when(() => reviews.watchReviewsByUser('u'))
            .thenAnswer((_) => Stream.value(const <Review>[]));
        when(() => profiles.watchWorkerProfile('u'))
            .thenAnswer((_) => Stream.value(null));
        when(() => jobs.watchUserJobs('u'))
            .thenAnswer((_) => Stream.value(const <JobModel>[]));
        when(() => jobs.watchWorkerJobs('u'))
            .thenAnswer((_) => Stream.value(const <JobModel>[]));
        when(() => jobs.watchCompletedJobsForWorker('u'))
            .thenAnswer((_) => Stream.value(const <JobModel>[]));
        return ProfileScreen(
          user: user(),
          authService: auth,
          paymentService: payments,
          reviewService: reviews,
          profileService: profiles,
          jobService: jobs,
        );
      }),
      ('WorkerDashboardScreen', () {
        final jobs = MockJobs();
        final requests = MockRequests();
        final profiles = MockProfiles();
        final auth = MockAuth();
        when(() => jobs.watchOpenJobs())
            .thenAnswer((_) => Stream.value(const <JobModel>[]));
        when(() => requests.getExistingRequest(any(), any()))
            .thenAnswer((_) async => null);
        when(() => auth.getUserProfile(any())).thenAnswer((_) async => null);
        return WorkerDashboardScreen(
          user: user(role: UserRole.worker),
          workerProfile: workerProfile(),
          jobService: jobs,
          requestService: requests,
          profileService: profiles,
          authService: auth,
        );
      }),
      ('QuoteFeatureEntry (feature OFF)', () {
        final quotes = MockQuotes();
        when(() => quotes.isEnabled()).thenAnswer((_) async => false);
        return QuoteFeatureEntry(user: user(), quoteService: quotes);
      }),
      ('JobDisputeLink', () {
        final cases = MockCases();
        final jobs = MockJobs();
        final payments = MockPayments();
        when(() => cases.getForJob('j')).thenAnswer((_) async => null);
        when(() => jobs.getJob('j')).thenAnswer((_) async => job());
        when(() => payments.getPaymentsForJob('j'))
            .thenAnswer((_) async => const <Payment>[]);
        return JobDisputeLink(
          jobId: 'j',
          userId: 'u',
          disputeService: cases,
          jobService: jobs,
          paymentService: payments,
        );
      }),
    ];

    for (final (name, build) in cases) {
      testWidgets('no overflow at 320px: $name', (tester) async {
        await pumpNarrow(tester, build());
        expect(tester.takeException(), isNull,
            reason: '$name overflowed or threw at 320x640.');
      });
      testWidgets('no overflow at 320px with 2.0 text scale: $name',
          (tester) async {
        await pumpNarrow(tester, build(), scale: 2.0);
        expect(tester.takeException(), isNull,
            reason: '$name overflowed or threw at 320x640 with 2.0 text scale.');
      });
    }
  });

  // ----------------------------------------------------------------
  // T2: frozen headers
  // ----------------------------------------------------------------
  group('frozen headers', () {
    testWidgets('JobScheduleScreen keeps the weekday header fixed while '
        'bookings scroll', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final jobs = MockJobs();
      final auth = MockAuth();
      final day = DateTime(2026, 10, 19);
      when(() => jobs.watchScheduledJobs('w')).thenAnswer((_) => Stream.value([
            booking(day),
            booking(day),
            booking(day),
            booking(day),
            booking(day),
            booking(day),
          ]));
      when(() => auth.getUserProfile(any())).thenAnswer((_) async => null);
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: JobScheduleScreen(
          workerId: 'w',
          jobService: jobs,
          authService: auth,
          initialDate: day,
        ),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      final header = find.text('Mon');
      expect(header, findsOneWidget);
      final before = tester.getRect(header);
      final vertical = find.byWidgetPredicate((widget) => widget is Scrollable &&
          widget.axisDirection == AxisDirection.down);
      expect(vertical, findsWidgets);
      final state = tester.state<ScrollableState>(vertical.last);
      expect(state.position.maxScrollExtent, greaterThan(0));
      state.position.jumpTo(state.position.maxScrollExtent);
      await tester.pump();
      expect(tester.getRect(header).dy, closeTo(before.dy, 0.5));
      expect(header, findsOneWidget);
      // The bookings really did scroll: six tiles are mounted.
      expect(find.byKey(const Key('schedule-job-j')), findsWidgets);
    });

    testWidgets('WorkerComparisonScreen keeps the worker header fixed '
        'while rows scroll', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final comparison = MockComparison();
      when(() => comparison.annualCount(any()))
          .thenAnswer((_) async => 156);
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2.0)),
          child: child!,
        ),
        home: WorkerComparisonScreen(
          myId: 'me',
          workers: [workerProfile(), workerProfile(uid: 'w2', name: 'Ali Raza')],
          comparisonService: comparison,
        ),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      final header = find.text('Imran Khan');
      final before = tester.getRect(header);
      final vertical = find.byWidgetPredicate((widget) => widget is Scrollable &&
          widget.axisDirection == AxisDirection.down);
      final state = tester.state<ScrollableState>(vertical.last);
      state.position.jumpTo(state.position.maxScrollExtent);
      await tester.pump();
      expect(tester.getRect(header).dy, closeTo(before.dy, 0.5));
      expect(header, findsOneWidget);
    });
  });

  // ----------------------------------------------------------------
  // T2: dialog focus trapping and touch targets
  // ----------------------------------------------------------------
  group('dialog focus and touch targets', () {
    testWidgets('report confirmation dialog traps focus and returns it on '
        'dismiss', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final service = MockReport();
      when(() => service.hasOpenReport(any(), any()))
          .thenAnswer((_) async => false);
      when(() => service.submitReport(
            reporterId: any(named: 'reporterId'),
            reportedId: any(named: 'reportedId'),
            reason: any(named: 'reason'),
            jobId: any(named: 'jobId'),
            details: any(named: 'details'),
          )).thenAnswer((_) async {});
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: ReportScreen(
          myId: 'me',
          reportedId: 'them',
          reportedName: 'the worker',
          reportService: service,
        ),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('report-reason-Other')));
      await tester.pump();
      await tester.enterText(
          find.byKey(const Key('report-details-field')), 'Kept calling after hours.');
      await test_viewport.reveal(tester, find.byKey(const Key('submit-report-button')));
      await tester.tap(find.byKey(const Key('submit-report-button')));
      await tester.pumpAndSettle();

      expect(find.text('Submit report?'), findsOneWidget);
      final dialog = tester.element(find.byType(AlertDialog));
      expect(_focusWithin(dialog), isTrue,
          reason: 'the report dialog must receive focus when opened');
      await tester.sendKeyDownEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(_focusWithin(dialog), isTrue,
          reason: 'Tab must stay trapped inside the report dialog');

      _assertDialogTouchTargets(tester);

      await tester.tap(find.descendant(
          of: find.byType(AlertDialog), matching: find.text('Cancel')));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(_focusWithin(dialog), isFalse,
          reason: 'focus must leave the dialog when it is dismissed');
    });

    testWidgets('delete account confirmation dialog traps focus and '
        'returns it on dismiss', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final deletion = MockDeletion();
      when(() => deletion.deleteAccount(
            uid: any(named: 'uid'),
            password: any(named: 'password'),
          )).thenAnswer((_) async {});
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: DeleteAccountScreen(user: user(), accountDeletionService: deletion),
      ));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const Key('delete-account-typed')), 'DELETE');
      await tester.enterText(
          find.byKey(const Key('delete-account-password')), 'password');
      tester.testTextInput.hide();
      await tester.pump();
      await test_viewport.reveal(
          tester, find.byKey(const Key('delete-account-submit')));
      await tester.tap(find.byKey(const Key('delete-account-submit')));
      await tester.pumpAndSettle();

      expect(find.text('Permanently delete this account?'), findsOneWidget);
      final dialog = tester.element(find.byType(AlertDialog));
      expect(_focusWithin(dialog), isTrue);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(_focusWithin(dialog), isTrue,
          reason: 'Tab must stay trapped inside the deletion dialog');

      _assertDialogTouchTargets(tester);

      await tester.tap(find.descendant(
          of: find.byType(AlertDialog), matching: find.text('Keep account')));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(_focusWithin(dialog), isFalse);
    });

    testWidgets('cancel-job confirmation dialog traps focus and returns '
        'it on dismiss', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final jobs = MockJobs();
      when(() => jobs.watchJob('j'))
          .thenAnswer((_) => Stream.value(job()));
      when(() => jobs.changeSchedule(
            jobId: 'j',
            ownerId: 'u',
            cancel: true,
            date: any(named: 'date'),
            time: any(named: 'time'),
            reason: any(named: 'reason'),
          )).thenAnswer((_) async {});
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: RescheduleJobScreen(
          jobId: 'j',
          userId: 'u',
          initialCancel: true,
          jobService: jobs,
        ),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('cancel-reason-Plans changed')));
      await tester.pump();
      await test_viewport.reveal(tester, find.byKey(const Key('job-change-submit')));
      await tester.tap(find.byKey(const Key('job-change-submit')));
      await tester.pumpAndSettle();

      expect(find.text('Cancel this job?'), findsOneWidget);
      final dialog = tester.element(find.byType(AlertDialog));
      expect(_focusWithin(dialog), isTrue);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(_focusWithin(dialog), isTrue,
          reason: 'Tab must stay trapped inside the cancel dialog');

      _assertDialogTouchTargets(tester);

      await tester.tap(find.descendant(
          of: find.byType(AlertDialog), matching: find.text('Keep current')));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(_focusWithin(dialog), isFalse);
    });
  });

  // ----------------------------------------------------------------
  // T2: contrast floor and keyboard reachability
  // ----------------------------------------------------------------
  group('contrast and keyboard', () {
    test('textMuted meets WCAG AA on white and on the light scaffold', () {
      double channel(double v) {
        final s = v / 255;
        return s <= 0.04045 ? s / 12.92 : pow((s + 0.055) / 1.055, 2.4).toDouble();
      }

      double luminance(Color c) =>
          0.2126 * channel(c.red) + 0.7152 * channel(c.green) + 0.0722 * channel(c.blue);

      double ratio(Color a, Color b) {
        final high = max(luminance(a), luminance(b));
        final low = min(luminance(a), luminance(b));
        return (high + 0.05) / (low + 0.05);
      }

      expect(ratio(AppTheme.textMuted, AppTheme.surfaceWhite),
          greaterThanOrEqualTo(4.5));
      expect(ratio(AppTheme.textMuted, AppTheme.bgLight),
          greaterThanOrEqualTo(4.5));
    });

    testWidgets('post-job form stays reachable with the keyboard open',
        (tester) async {
      await pumpNarrow(tester, PostJobScreen(
        userId: 'user-1',
        locationService: LocationService(provider: _DeniedProvider()),
      ));
      final fields = find.byType(TextFormField);
      expect(fields, findsWidgets);
      await tester.enterText(fields.first, 'Leaky faucet');
      tester.view.viewInsets = const EdgeInsets.only(bottom: 300);
      await tester.pump();
      expect(tester.takeException(), isNull);
      // The submit control stays reachable above the simulated keyboard.
      await test_viewport.reveal(tester, find.text('Post Job'));
      final rect = tester.getRect(find.text('Post Job'));
      expect(rect.bottom, lessThanOrEqualTo(640 - 300 + 1));
      tester.testTextInput.hide();
      tester.view.viewInsets = EdgeInsets.zero;
      await tester.pump();
    });

    testWidgets('review form stays reachable with the keyboard open',
        (tester) async {
      await pumpNarrow(tester,
          const ReviewScreen(jobId: 'j', workerId: 'w', reviewerId: 'u'));
      final field = find.byType(TextField);
      expect(field, findsOneWidget);
      await tester.enterText(field, 'بہت اچھا کام');
      tester.view.viewInsets = const EdgeInsets.only(bottom: 300);
      await tester.pump();
      expect(tester.takeException(), isNull);
      await test_viewport.reveal(tester, find.text('Submit Review'));
      final rect = tester.getRect(find.text('Submit Review'));
      expect(rect.bottom, lessThanOrEqualTo(640 - 300 + 1));
      tester.testTextInput.hide();
      tester.view.viewInsets = EdgeInsets.zero;
      await tester.pump();
    });
  });
}

class _DeniedProvider implements LocationProvider {
  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.denied;

  @override
  Future<LocationPermission> requestPermission() async =>
      LocationPermission.denied;

  @override
  Future<Position> getCurrentPosition() async => throw UnimplementedError();
}
