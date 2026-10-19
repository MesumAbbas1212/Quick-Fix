import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quickfix/core/widgets/loading_list.dart';
import 'package:quickfix/models/review_model.dart';
import 'package:quickfix/models/user_model.dart';
import 'package:quickfix/services/profile_service.dart';
import 'package:quickfix/services/review_service.dart';
import 'package:quickfix/views/reviews/my_reviews_screen.dart';
class MockReviews extends Mock implements ReviewService {}
class MockProfiles extends Mock implements ProfileService {}
Review review(double rating) => Review(id: '$rating', jobId: 'j', reviewerId: 'u', workerId: 'w', rating: rating, originalText: 'بہت اچھا', originalLang: 'ur', createdAt: DateTime(2026));
void main() {
  late MockReviews reviews; late MockProfiles profiles;
  final user = UserModel(uid: 'u', email: '', fullName: '', phone: '', role: UserRole.user, createdAt: DateTime(2026), updatedAt: DateTime(2026));
  setUp(() { reviews = MockReviews(); profiles = MockProfiles(); when(() => reviews.watchReviewsByUser('u')).thenAnswer((_) => Stream.value([])); when(() => profiles.getWorkerProfile('w')).thenAnswer((_) async => null); });
  Future<void> pump(WidgetTester tester) async { await tester.pumpWidget(MaterialApp(home: MyReviewsScreen(user: user, reviewService: reviews, profileService: profiles))); await tester.pump(); }
  test('written summary uses valid scores and does not invent an empty average', () {
    expect(ReviewService.writtenSummary([]).average, isNull); final result = ReviewService.writtenSummary([review(4), review(5), review(double.nan)]);
    expect(result.count, 3); expect(result.average, 4.5);
  });
  testWidgets('loading/empty/error/retry are distinct', (tester) async {
    final stream = StreamController<List<Review>>(); addTearDown(stream.close); when(() => reviews.watchReviewsByUser('u')).thenAnswer((_) => stream.stream); await pump(tester);
    expect(find.byType(LoadingList), findsOneWidget); stream.addError(StateError('offline')); await tester.pumpAndSettle();
    when(() => reviews.watchReviewsByUser('u')).thenAnswer((_) => Stream.value([])); await tester.tap(find.text('Retry')); await tester.pumpAndSettle();
    expect(find.text('You haven’t reviewed anyone yet'), findsOneWidget); expect(find.text('Browse workers'), findsOneWidget);
  });
  testWidgets('own text stays read-only, with unavailable worker fallback and no Translate', (tester) async {
    when(() => reviews.watchReviewsByUser('u')).thenAnswer((_) => Stream.value([review(4)])); await pump(tester); await tester.pumpAndSettle();
    expect(find.text('Former worker'), findsOneWidget); expect(find.text('بہت اچھا'), findsOneWidget); expect(find.text('Translate'), findsNothing); expect(find.textContaining('Average given: 4.0'), findsOneWidget);
  });
}
