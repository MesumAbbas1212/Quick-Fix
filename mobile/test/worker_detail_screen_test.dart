import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quickfix/models/job_model.dart';
import 'package:quickfix/models/review_model.dart';
import 'package:quickfix/models/worker_profile.dart';
import 'package:quickfix/services/review_service.dart';
import 'package:quickfix/services/translation_service.dart';
import 'package:quickfix/views/chat/chat_screen.dart';
import 'package:quickfix/views/client/worker_detail_screen.dart';

class MockReviewService extends Mock implements ReviewService {}
class MockTranslationService extends Mock implements TranslationService {}

WorkerProfile _worker() {
  return WorkerProfile(
    uid: 'w1',
    fullName: 'Imran Khan',
    email: 'imran@quickfix.com',
    about: 'Plumber with 8 years of experience.',
    professions: const [JobCategory.plumbing, JobCategory.electrical],
    languages: const ['Urdu', 'English'],
    minBudget: 1500,
    maxBudget: 4000,
    rating: 4.5,
    completedJobs: 27,
    reviews: 2,
    isAvailable: true,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );
}

Review _review({String text = 'بہت اچھا کام'}) {
  return Review(
    id: 'r1',
    jobId: 'job-1',
    reviewerId: 'user-1',
    workerId: 'w1',
    rating: 5,
    originalText: text,
    originalLang: 'ur',
    createdAt: DateTime(2026, 8, 11),
  );
}

void main() {
  late MockReviewService reviewService;
  late MockTranslationService translationService;

  setUp(() {
    reviewService = MockReviewService();
    translationService = MockTranslationService();
    when(() => reviewService.watchReviewsForWorker('w1'))
        .thenAnswer((_) => Stream.value(<Review>[]));
  });

  Future<void> pumpDetail(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: WorkerDetailScreen(
        worker: _worker(),
        myId: 'u1',
        reviewService: reviewService,
        translationService: translationService,
      ),
    ));
    await tester.pump();
  }

  testWidgets('shows worker info: name, professions, about', (tester) async {
    await pumpDetail(tester);

    expect(find.text('Imran Khan'), findsOneWidget);
    expect(find.text('Plumbing'), findsOneWidget);
    expect(find.text('Electrical'), findsOneWidget);
    expect(find.text('Plumber with 8 years of experience.'), findsOneWidget);
  });

  testWidgets('shows stats: rating, completed jobs, review count',
      (tester) async {
    await pumpDetail(tester);

    expect(find.text('4.5'), findsOneWidget);
    expect(find.text('27'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('lists reviews from the live stream', (tester) async {
    when(() => reviewService.watchReviewsForWorker('w1'))
        .thenAnswer((_) => Stream.value([_review()]));

    await pumpDetail(tester);
    await tester.pump();

    expect(find.text('بہت اچھا کام'), findsOneWidget);
    expect(find.text('Translate'), findsOneWidget);
  });

  testWidgets('tapping Translate calls the translation service and shows result',
      (tester) async {
    when(() => reviewService.watchReviewsForWorker('w1'))
        .thenAnswer((_) => Stream.value([_review()]));
    when(() => translationService.translate('بہت اچھا کام', 'en'))
        .thenAnswer((_) async => 'Very good work');

    await pumpDetail(tester);
    await tester.pump();

    await tester.tap(find.text('Translate'));
    await tester.pump();
    await tester.pump();

    verify(() => translationService.translate('بہت اچھا کام', 'en')).called(1);
    expect(find.text('Very good work'), findsOneWidget);
  });

  testWidgets('shows empty state when no reviews', (tester) async {
    await pumpDetail(tester);

    expect(find.text('No reviews yet'), findsOneWidget);
  });

  testWidgets('Chat button pushes ChatScreen with worker peer', (tester) async {
    await pumpDetail(tester);

    await tester.tap(find.byKey(const Key('chat-worker-button')));
    await tester.pumpAndSettle();

    expect(find.byType(ChatScreen), findsOneWidget);
  });
}
