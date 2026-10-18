import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quickfix/core/theme/app_theme.dart';
import 'package:quickfix/services/preferences_service.dart';
import 'package:quickfix/views/onboarding/onboarding_carousel.dart';

class MockPreferences extends Mock implements PreferencesService {}
void main() {
  late MockPreferences preferences;
  late bool finished;
  setUp(() { preferences = MockPreferences(); finished = false;
    when(() => preferences.markOnboardingSeen()).thenAnswer((_) async {}); });
  Future<void> pump(WidgetTester tester, {double scale = 1}) async {
    tester.view.physicalSize = const Size(320, 800); tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(theme: AppTheme.lightTheme,
      builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)), child: child!),
      home: OnboardingCarousel(preferencesService: preferences, onFinished: () { finished = true; })));
  }
  testWidgets('has three accessible pages with a working final action', (tester) async {
    await pump(tester);
    expect(find.text('Post a job in a minute'), findsOneWidget);
    for (var i = 0; i < 2; i++) { await tester.tap(find.byKey(const Key('onboarding-next'))); await tester.pumpAndSettle(); }
    expect(find.text('Reviews in your language'), findsOneWidget);
    expect(find.text('Get started'), findsOneWidget);
    verifyNever(() => preferences.markOnboardingSeen());
    await tester.tap(find.byKey(const Key('onboarding-next'))); await tester.pumpAndSettle();
    expect(finished, isTrue); verify(() => preferences.markOnboardingSeen()).called(1);
  });
  testWidgets('Skip saves the flag before finishing', (tester) async {
    await pump(tester); await tester.tap(find.byKey(const Key('onboarding-skip'))); await tester.pumpAndSettle();
    expect(finished, isTrue); verify(() => preferences.markOnboardingSeen()).called(1);
  });
  testWidgets('failed save is visible and can be retried', (tester) async {
    when(() => preferences.markOnboardingSeen()).thenThrow(StateError('storage full'));
    await pump(tester); await tester.tap(find.byKey(const Key('onboarding-skip'))); await tester.pumpAndSettle();
    expect(finished, isFalse); expect(find.textContaining('Could not save your preference.'), findsOneWidget);
    when(() => preferences.markOnboardingSeen()).thenAnswer((_) async {});
    await tester.tap(find.byKey(const Key('onboarding-skip'))); await tester.pumpAndSettle(); expect(finished, isTrue);
  });
  testWidgets('enlarged small-screen content scrolls without overflow', (tester) async {
    await pump(tester, scale: 1.8); expect(tester.takeException(), isNull);
  });
  test('flag persists, and clearing account caches retains device flags', () async {
    SharedPreferences.setMockInitialValues({'cached_jobs': '[]', 'cached_categories': '[]'});
    final service = PreferencesService(); expect(await service.hasSeenOnboarding(), isFalse);
    await service.markOnboardingSeen(); await service.rememberBuild(7); await service.clearAccountCache();
    expect(await service.hasSeenOnboarding(), isTrue); expect(await service.lastSeenBuild(), 7);
    expect((await SharedPreferences.getInstance()).containsKey('cached_jobs'), isFalse);
  });
}
