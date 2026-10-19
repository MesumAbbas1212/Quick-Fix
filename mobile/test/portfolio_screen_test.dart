import 'package:quickfix/services/local_image_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quickfix/models/job_model.dart';
import 'package:quickfix/models/worker_content.dart';
import 'package:quickfix/services/profile_service.dart';
import 'package:quickfix/views/worker/portfolio_screen.dart';
class MockProfiles extends Mock implements ProfileService {}
class MockImages extends Mock implements LocalImageStore {}
void main() {
  test('portfolio metadata round-trips with unknown categories safely labelled other', () {
    final work = PortfolioWork.fromMap({'caption': 'مرمت', 'imagePath': '/missing', 'category': 'legacy'}, 'legacy-0');
    expect(work.category, JobCategory.other); expect(work.toMap()['caption'], 'مرمت'); expect(work.createdAt, isNull);
  });
  testWidgets('error retry yields an actionable owner empty state', (tester) async {
    final profiles = MockProfiles(); when(() => profiles.watchPortfolio('w')).thenAnswer((_) => Stream.error(StateError('offline')));
    await tester.pumpWidget(MaterialApp(home: PortfolioScreen(workerId: 'w', profileService: profiles))); await tester.pumpAndSettle();
    when(() => profiles.watchPortfolio('w')).thenAnswer((_) => Stream.value([])); await tester.tap(find.text('Retry')); await tester.pumpAndSettle();
    expect(find.text('Show clients your work'), findsOneWidget); expect(find.byKey(const Key('portfolio-add')), findsOneWidget);
  });
  testWidgets('client mode exposes local-file limits and never owner add/delete controls', (tester) async {
    final images = MockImages(); when(() => images.readImage(any())).thenAnswer((_) async => null);
    final profiles = MockProfiles(); when(() => profiles.watchPortfolio('w')).thenAnswer((_) => Stream.value([const PortfolioWork(id: 'a', imagePath: '/missing', caption: 'مرمت', category: JobCategory.plumbing)]));
    await tester.pumpWidget(MaterialApp(home: PortfolioScreen(workerId: 'w', readOnly: true, profileService: profiles, imageStore: images))); await tester.pumpAndSettle();
    expect(find.byKey(const Key('portfolio-add')), findsNothing); expect(find.byKey(const Key('portfolio-remove-a')), findsNothing);
    expect(tester.widget<Text>(find.text('مرمت')).textDirection, TextDirection.rtl); expect(find.text('Photo not on this device'), findsOneWidget);
  });
}
