import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quickfix/core/utils/content_direction.dart';
import 'package:quickfix/core/widgets/review_list_tile.dart';
import 'package:quickfix/models/chat_message.dart';
import 'package:quickfix/models/review_model.dart';
import 'package:quickfix/models/worker_profile.dart';
import 'package:quickfix/services/chat_service.dart';
import 'package:quickfix/services/review_service.dart';
import 'package:quickfix/services/translation_service.dart';
import 'package:quickfix/services/worker_comparison_service.dart';
import 'package:quickfix/views/chat/chat_screen.dart';
import 'package:quickfix/views/client/worker_comparison_screen.dart';
import 'package:quickfix/views/client/worker_detail_screen.dart';

class MockReviewService extends Mock implements ReviewService {}

class MockTranslationService extends Mock implements TranslationService {}

class MockComparison extends Mock implements WorkerComparisonService {}

class MockChat extends Mock implements ChatService {}

/// A 300-character Urdu review, as a real reviewer might write it.
const String longUrduReview =
    'یہ کام بہت اچھا تھا۔ کاریگر نے وقت پر کام کیا اور صفائی بھی کر دی۔ '
    'میں نے اس کی سفارش دوستوں کو بھی کر دی ہے۔ قیمت مناسب تھی اور معاہدہ '
    'کے مطابق کام مکمل ہوا۔ اگر مزید کام آئے تو وہی کاریگر بلانا گا۔ '
    'شکریہ یار، آپ سب سے بہترین ہیں۔ اس کی آڑ میں کوئی شکایت نہیں۔ '
    'اگلی بار پھر ضرور رابطہ کروں گا۔ بہت ہی خوشگوار تجربہ رہا۔ '
    'اور کام کی کوالٹی بے مثال تھی، جو دیکھی وہ پسند آئی۔ '
    'آپ کی مہارت اور لگن دیکھ کر خوشی ہوئی۔ اللہ کرے ہمیشہ ایسے ہی '
    'کام کرتے رہیں۔ ہر گھر میں آپ کی خدمات کا اندازہ ہو۔ شکریہ۔';

const String urduName = 'محمد علی خان';

WorkerProfile _urduWorker() => WorkerProfile(
      uid: 'w1',
      fullName: urduName,
      email: 'imran@example.com',
      about: 'پانی کی ٹیوب کی مرمت اور نصب کا کام',
      professions: const [JobCategory.plumbing],
      languages: const ['اردو', 'English'],
      minBudget: 1500,
      maxBudget: 4000,
      rating: 4.5,
      completedJobs: 27,
      reviews: 2,
      isAvailable: true,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

Review _urduReview() => Review(
      id: 'r1',
      jobId: 'job-1',
      reviewerId: 'user-1',
      workerId: 'w1',
      rating: 5,
      originalText: longUrduReview,
      originalLang: 'ur',
      createdAt: DateTime(2026, 8, 11),
    );

void main() {
  group('contentDirection', () {
    test('Urdu names and Arabic content are RTL', () {
      expect(contentDirection('محمد علی'), TextDirection.rtl);
      expect(contentDirection('مرحبا بالعالم'), TextDirection.rtl);
    });
    test('English and empty content are LTR', () {
      expect(contentDirection('Ali Khan'), TextDirection.ltr);
      expect(contentDirection(''), TextDirection.ltr);
    });
    test('non-Latin does not imply RTL', () {
      expect(contentDirection('बहुत अच्छा काम'), TextDirection.ltr);
    });
  });

  group('RTL review rendering', () {
    testWidgets('a 300-character Urdu review wraps at 320px without overflow',
        (tester) async {
      expect(longUrduReview.length, greaterThanOrEqualTo(300));
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: ReviewListTile(review: _urduReview())),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final text = tester.widget<Text>(find.text(longUrduReview));
      expect(text.textDirection, TextDirection.rtl);
      // The review actually wrapped: the tile is taller than one line.
      expect(tester.getSize(find.byType(ReviewListTile)).height,
          greaterThan(60));
    });

    testWidgets('the same review survives a 2.0 text scale at 320px',
        (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2.0)),
          child: child!,
        ),
        home: Scaffold(body: ReviewListTile(review: _urduReview())),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text(longUrduReview), findsOneWidget);
    });

    testWidgets('an Urdu worker name is RTL on the detail screen',
        (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final reviews = MockReviewService();
      final translations = MockTranslationService();
      when(() => reviews.watchReviewsForWorker('w1'))
          .thenAnswer((_) => Stream.value(const <Review>[]));
      await tester.pumpWidget(MaterialApp(
        home: WorkerDetailScreen(
          worker: _urduWorker(),
          myId: 'me',
          reviewService: reviews,
          translationService: translations,
        ),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(tester.widget<Text>(find.text(urduName)).textDirection,
          TextDirection.rtl);
    });

    testWidgets('an Urdu chat message renders RTL in its bubble',
        (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final chat = MockChat();
      when(() => chat.watchMessages(user1: any(named: 'user1'), user2: any(named: 'user2')))
          .thenAnswer((_) => Stream.value(<ChatMessage>[
                ChatMessage(
                  id: 'm1',
                  senderId: 'peer-1',
                  receiverId: 'me-1',
                  text: longUrduReview,
                  createdAt: DateTime(2026),
                ),
              ]));
      when(() => chat.markAsRead(
            conversationId: any(named: 'conversationId'),
            userId: any(named: 'userId'),
          )).thenAnswer((_) async {});
      when(() => chat.watchLatestSharedLocation(any(), any(),
              senderId: any(named: 'senderId'), since: any(named: 'since')))
          .thenAnswer((_) => Stream.value(null));
      await tester.pumpWidget(MaterialApp(
        home: ChatScreen(peerName: urduName, peerId: 'peer-1', myId: 'me-1', chatService: chat),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(tester.widget<Text>(find.text(longUrduReview)).textDirection,
          TextDirection.rtl);
    });

    testWidgets('Urdu names render RTL in the comparison grid and the '
        'header row stays fixed while rows scroll', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final comparison = MockComparison();
      when(() => comparison.annualCount(any())).thenAnswer((_) async => 156);
      await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2.0)),
          child: child!,
        ),
        home: WorkerComparisonScreen(
          myId: 'me',
          workers: [
            _urduWorker(),
            WorkerProfile(
              uid: 'w2',
              fullName: 'طاہر حسین',
              email: 'tahir@example.com',
              rating: 4.0,
              reviews: 10,
              completedJobs: 200,
              createdAt: DateTime(2026),
              updatedAt: DateTime(2026),
            ),
          ],
          comparisonService: comparison,
        ),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(tester.widget<Text>(find.text(urduName)).textDirection,
          TextDirection.rtl);
      expect(
          tester.widget<Text>(find.text('طاہر حسین')).textDirection,
          TextDirection.rtl);

      // Frozen header: scroll the body column to its end; the worker
      // name header must not move.
      final header = find.text(urduName);
      final before = tester.getRect(header);
      final vertical = find.byWidgetPredicate((widget) => widget is Scrollable &&
          widget.axisDirection == AxisDirection.down);
      expect(vertical, findsWidgets);
      final state = tester.state<ScrollableState>(vertical.last);
      state.position.jumpTo(state.position.maxScrollExtent);
      await tester.pump();
      expect(tester.getRect(header).dy, closeTo(before.dy, 0.5));
      expect(find.text(urduName), findsOneWidget);
    });
  });

  group('LTR review rendering', () {
    testWidgets('an English review stays LTR and wraps at 320px',
        (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final review = Review(
        id: 'r2',
        jobId: 'job-1',
        reviewerId: 'user-1',
        workerId: 'w1',
        rating: 4,
        originalText: 'The plumber arrived on time and fixed the leaking '
            'kitchen tap completely. The workmanship was careful, the price '
            'was fair and the site was left clean. I would happily hire '
            'them again for any future plumbing work in the area.',
        originalLang: 'en',
        createdAt: DateTime(2026, 8, 11),
      );
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: ReviewListTile(review: review)),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(tester.widget<Text>(find.text(review.originalText)).textDirection,
          TextDirection.ltr);
    });
  });
}
