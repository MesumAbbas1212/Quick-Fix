import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quickfix/models/job_model.dart';
import 'package:quickfix/models/review_model.dart';
import 'package:quickfix/models/worker_profile.dart';
import 'package:quickfix/services/job_service.dart';
import 'package:quickfix/services/review_service.dart';
import 'package:quickfix/services/translation_service.dart';
import 'package:quickfix/views/client/worker_detail_screen.dart';

class MockReviewService extends Mock implements ReviewService {}

class MockTranslationService extends Mock implements TranslationService {}

class MockJobService extends Mock implements JobService {}

void main() {
  late MockReviewService reviewService;
  late MockTranslationService translationService;
  late MockJobService jobService;

  setUp(() {
    reviewService = MockReviewService();
    translationService = MockTranslationService();
    jobService = MockJobService();
  });

  WorkerProfile _worker({int completedJobs = 2}) {
    return WorkerProfile(
      uid: 'w1',
      fullName: 'Imran Khan',
      email: 'imran@quickfix.com',
      rating: 4.5,
      completedJobs: completedJobs,
      reviews: 0,
      isAvailable: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  JobModel _completedJob(String title, DateTime at, {double? rating}) {
    return JobModel(
      id: 'job-$title',
      userId: 'u1',
      workerId: 'w1',
      title: title,
      description: 'desc',
      category: JobCategory.plumbing,
      address: 'Lahore',
      location: const GeoPoint(31.0, 74.0),
      budgetMin: 1000,
      budgetMax: 2000,
      preferredDate: at,
      status: JobStatus.completed,
      rating: rating,
      createdAt: at,
      updatedAt: at,
      completedAt: at,
    );
  }

  Future<void> pumpDetail(
    WidgetTester tester, {
    List<JobModel> completed = const [],
    String userLanguage = 'en',
  }) async {
    when(() => reviewService.watchReviewsForWorker('w1'))
        .thenAnswer((_) => Stream.value(const <Review>[]));
    when(() => jobService.watchCompletedJobsForWorker('w1'))
        .thenAnswer((_) => Stream.value(completed));

    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: WorkerDetailScreen(
        worker: _worker(),
        myId: 'u1',
        reviewService: reviewService,
        translationService: translationService,
        jobService: jobService,
        userLanguage: userLanguage,
      ),
    ));
    await tester.pump();
  }

  testWidgets('lists completed jobs in the work history card', (tester) async {
    await pumpDetail(
      tester,
      completed: [
        _completedJob('Kitchen sink leak', DateTime(2026, 8, 1), rating: 5),
        _completedJob('Fan wiring', DateTime(2026, 7, 15)),
      ],
    );

    expect(find.text('Work History'), findsOneWidget);
    expect(find.text('Kitchen sink leak'), findsOneWidget);
    expect(find.text('Fan wiring'), findsOneWidget);
  });

  testWidgets('shows empty work history state', (tester) async {
    await pumpDetail(tester);
    expect(find.text('Work History'), findsOneWidget);
    expect(find.text('No completed jobs yet'), findsOneWidget);
  });

  testWidgets('rank reflects only jobs completed within the last year',
      (tester) async {
    final now = DateTime.now();
    // 155 completions inside the trailing year + 2 outside it = 157 total.
    // Counting the window correctly (155) keeps the worker an Apprentice;
    // counting all completions (157) would wrongly promote to Journeyman
    // (156 threshold).
    final recent = List.generate(
      155,
      (i) => _completedJob(
        'Recent job $i',
        now.subtract(Duration(days: i + 1)),
      ),
    );
    final old = [
      _completedJob('Old job 1', now.subtract(const Duration(days: 400))),
      _completedJob('Old job 2', now.subtract(const Duration(days: 500))),
    ];
    await pumpDetail(tester, completed: [...recent, ...old]);

    expect(find.text('Apprentice'), findsOneWidget);
    expect(find.text('Journeyman'), findsNothing);
    expect(find.text('Expert'), findsNothing);
  });

  testWidgets('falls back to lifetime count without a job service',
      (tester) async {
    when(() => reviewService.watchReviewsForWorker('w1'))
        .thenAnswer((_) => Stream.value(const <Review>[]));

    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: WorkerDetailScreen(
        worker: _worker(completedJobs: 500),
        myId: 'u1',
        reviewService: reviewService,
        translationService: translationService,
      ),
    ));
    await tester.pump();

    // 500 lifetime completions -> Master (468 threshold);
    // no work history section without a job service.
    expect(find.text('Master'), findsOneWidget);
    expect(find.text('Work History'), findsNothing);
  });

  testWidgets('translates reviews into the viewer app language',
      (tester) async {
    // An English review viewed by a user whose app language is Urdu must
    // be translated into Urdu when the user taps Translate.
    final english = Review(
      id: 'r1',
      jobId: 'j1',
      reviewerId: 'u1',
      workerId: 'w1',
      rating: 5,
      originalText: 'Great work',
      originalLang: 'en',
      createdAt: DateTime(2026, 8, 11),
    );
    when(() => reviewService.watchReviewsForWorker('w1'))
        .thenAnswer((_) => Stream.value([english]));
    when(() => jobService.watchCompletedJobsForWorker('w1'))
        .thenAnswer((_) => Stream.value(const <JobModel>[]));
    when(() => translationService.translate('Great work', 'ur'))
        .thenAnswer((_) async => 'کام بہت اچھا تھا');

    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: WorkerDetailScreen(
        worker: _worker(),
        myId: 'u1',
        reviewService: reviewService,
        translationService: translationService,
        jobService: jobService,
        userLanguage: 'ur',
      ),
    ));
    await tester.pump();

    await tester.tap(find.text('Translate'));
    await tester.pump();
    await tester.pump();

    verify(() => translationService.translate('Great work', 'ur')).called(1);
    expect(find.text('کام بہت اچھا تھا'), findsOneWidget);
  });
}
