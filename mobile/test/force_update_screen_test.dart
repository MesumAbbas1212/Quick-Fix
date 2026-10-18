import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quickfix/models/app_release_config.dart';
import 'package:quickfix/services/app_release_service.dart';
import 'package:quickfix/views/auth/force_update_screen.dart';

class MockReleaseService extends Mock implements AppReleaseService {}
const _config = AppReleaseConfig(minBuild: 2, latestBuild: 3, message: 'Install the latest QuickFix build.',
  storeUrl: 'https://play.google.com/store/apps/details?id=pk.quickfix.app');
void main() {
  late MockReleaseService service;
  setUp(() { service = MockReleaseService(); });
  testWidgets('required update includes message, installed version and a working launch', (tester) async {
    when(() => service.openStore(any())).thenAnswer((_) async => true);
    await tester.pumpWidget(MaterialApp(home: ForceUpdateScreen(config: _config, currentBuild: 1, releaseService: service)));
    expect(find.text('Update required'), findsOneWidget); expect(find.text(_config.message), findsOneWidget);
    expect(find.textContaining('Installed build 1'), findsOneWidget);
    await tester.tap(find.byKey(const Key('force-update-now'))); await tester.pumpAndSettle();
    verify(() => service.openStore(_config.storeUrl)).called(1);
  });
  testWidgets('store failure explains how to retry', (tester) async {
    when(() => service.openStore(any())).thenAnswer((_) async => false);
    await tester.pumpWidget(MaterialApp(home: ForceUpdateScreen(config: _config, releaseService: service)));
    await tester.tap(find.byKey(const Key('force-update-now'))); await tester.pumpAndSettle();
    expect(find.textContaining('Could not open the app store.'), findsOneWidget);
    when(() => service.openStore(any())).thenAnswer((_) async => true);
    await tester.tap(find.byKey(const Key('force-update-now'))); await tester.pumpAndSettle();
    expect(find.textContaining('Could not open the app store.'), findsNothing);
  });
  testWidgets('gate blocks only a successful minBuild decision and rechecks', (tester) async {
    when(() => service.checkForUpdate()).thenAnswer((_) async => const AppReleaseDecision(config: _config, currentBuild: 1));
    await tester.pumpWidget(MaterialApp(home: AppReleaseGate(releaseService: service, child: const Text('Main app'))));
    await tester.pumpAndSettle(); expect(find.byType(ForceUpdateScreen), findsOneWidget); expect(find.text('Main app'), findsNothing);
    when(() => service.checkForUpdate()).thenAnswer((_) async => const AppReleaseDecision(currentBuild: 1));
    await tester.tap(find.byKey(const Key('force-update-recheck'))); await tester.pumpAndSettle();
    expect(find.text('Main app'), findsOneWidget);
  });
  testWidgets('soft updates and failures never gate app entry', (tester) async {
    when(() => service.checkForUpdate()).thenAnswer((_) async => const AppReleaseDecision(config: _config, currentBuild: 2));
    await tester.pumpWidget(MaterialApp(home: AppReleaseGate(releaseService: service, child: const Text('Soft app'))));
    await tester.pumpAndSettle(); expect(find.text('Soft app'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    when(() => service.checkForUpdate()).thenThrow(StateError('config offline'));
    await tester.pumpWidget(MaterialApp(home: AppReleaseGate(releaseService: service, child: const Text('Offline app'))));
    await tester.pumpAndSettle(); expect(find.text('Offline app'), findsOneWidget);
  });
  testWidgets('a hung check is bounded and fails open', (tester) async {
    final pending = Completer<AppReleaseDecision>();
    when(() => service.checkForUpdate()).thenAnswer((_) => pending.future);
    await tester.pumpWidget(MaterialApp(home: AppReleaseGate(releaseService: service, child: const Text('Allowed app'))));
    await tester.pump(const Duration(seconds: 7)); await tester.pumpAndSettle();
    expect(find.text('Allowed app'), findsOneWidget);
    pending.complete(const AppReleaseDecision(config: _config, currentBuild: 1)); await tester.pump();
    expect(find.text('Allowed app'), findsOneWidget);
  });
}
