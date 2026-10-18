import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quickfix/services/location_service.dart';
import 'package:quickfix/views/settings/permission_explainer_screen.dart';

class MockLocationService extends Mock implements LocationService {}

void main() {
  late MockLocationService locationService;
  late Completer<bool?> popResult;

  Future<void> pumpExplainer(WidgetTester tester) async {
    popResult = Completer<bool?>();
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                popResult.complete(
                  await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                      builder: (_) => PermissionExplainerScreen(
                        purpose: 'to find nearby workers',
                        locationService: locationService,
                      ),
                    ),
                  ),
                );
              },
              child: const Text('open-explainer'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open-explainer'));
    await tester.pumpAndSettle();
  }

  setUp(() {
    locationService = MockLocationService();
  });

  testWidgets('auto-pops with true when already granted', (tester) async {
    when(() => locationService.getPermissionStatus())
        .thenAnswer((_) async => LocationPermission.whileInUse);
    await pumpExplainer(tester);

    // The explainer should have popped itself back to home.
    expect(find.byType(PermissionExplainerScreen), findsNothing);
    expect(popResult.isCompleted, isTrue);
    expect(await popResult.future, isTrue);
  });

  testWidgets('shows explainer and pops false on Not now', (tester) async {
    when(() => locationService.getPermissionStatus())
        .thenAnswer((_) async => LocationPermission.denied);
    await pumpExplainer(tester);

    expect(find.byType(PermissionExplainerScreen), findsOneWidget);
    expect(find.text('to find nearby workers'), findsOneWidget);
    expect(find.byKey(const Key('allow-location-button')), findsOneWidget);
    expect(find.byKey(const Key('open-settings-button')), findsNothing);

    await tester.tap(find.byKey(const Key('not-now-button')));
    await tester.pumpAndSettle();

    expect(find.byType(PermissionExplainerScreen), findsNothing);
    expect(await popResult.future, isFalse);
  });

  testWidgets('Allow requests permission and pops true when granted',
      (tester) async {
    when(() => locationService.getPermissionStatus())
        .thenAnswer((_) async => LocationPermission.denied);
    when(() => locationService.requestPermission())
        .thenAnswer((_) async => LocationPermission.whileInUse);
    await pumpExplainer(tester);

    await tester.tap(find.byKey(const Key('allow-location-button')));
    await tester.pumpAndSettle();

    verify(() => locationService.requestPermission()).called(1);
    expect(find.byType(PermissionExplainerScreen), findsNothing);
    expect(await popResult.future, isTrue);
  });

  testWidgets('Allow pops false when the user denies the system dialog',
      (tester) async {
    when(() => locationService.getPermissionStatus())
        .thenAnswer((_) async => LocationPermission.denied);
    when(() => locationService.requestPermission())
        .thenAnswer((_) async => LocationPermission.denied);
    await pumpExplainer(tester);

    await tester.tap(find.byKey(const Key('allow-location-button')));
    await tester.pumpAndSettle();

    expect(await popResult.future, isFalse);
  });

  testWidgets('deniedForever offers Open settings and re-checks on return',
      (tester) async {
    var checks = 0;
    when(() => locationService.getPermissionStatus()).thenAnswer((_) async {
      checks++;
      return checks == 1
          ? LocationPermission.deniedForever
          : LocationPermission.whileInUse;
    });
    when(() => locationService.openAppSettings())
        .thenAnswer((_) async => true);
    await pumpExplainer(tester);

    expect(find.byKey(const Key('open-settings-button')), findsOneWidget);

    await tester.tap(find.byKey(const Key('open-settings-button')));
    await tester.pumpAndSettle();

    verify(() => locationService.openAppSettings()).called(1);
    expect(checks, 2);
    expect(find.byType(PermissionExplainerScreen), findsNothing);
    expect(await popResult.future, isTrue);
  });
  testWidgets('permanent refusal after Allow changes to the Settings recovery action', (tester) async {
    when(() => locationService.getPermissionStatus()).thenAnswer((_) async => LocationPermission.denied);
    when(() => locationService.requestPermission()).thenAnswer((_) async => LocationPermission.deniedForever);
    await pumpExplainer(tester);
    await tester.tap(find.byKey(const Key('allow-location-button'))); await tester.pumpAndSettle();
    expect(find.byKey(const Key('open-settings-button')), findsOneWidget);
    expect(find.byKey(const Key('allow-location-button')), findsNothing);
    expect(popResult.isCompleted, isFalse);
  });
  testWidgets('failed permission checks expose an actual retry', (tester) async {
    when(() => locationService.getPermissionStatus()).thenThrow(StateError('platform unavailable'));
    await pumpExplainer(tester);
    expect(find.byKey(const Key('permission-retry')), findsOneWidget);
    when(() => locationService.getPermissionStatus()).thenAnswer((_) async => LocationPermission.whileInUse);
    await tester.tap(find.byKey(const Key('permission-retry'))); await tester.pumpAndSettle();
    expect(await popResult.future, isTrue);
  });
  testWidgets('missing settings handler is explained instead of silently ignored', (tester) async {
    when(() => locationService.getPermissionStatus()).thenAnswer((_) async => LocationPermission.deniedForever);
    when(() => locationService.openAppSettings()).thenAnswer((_) async => false);
    await pumpExplainer(tester);
    await tester.tap(find.byKey(const Key('open-settings-button'))); await tester.pumpAndSettle();
    expect(find.textContaining('Could not open app settings.'), findsOneWidget);
    expect(popResult.isCompleted, isFalse);
  });
  testWidgets('permission screen itself never reads GPS', (tester) async {
    when(() => locationService.getPermissionStatus()).thenAnswer((_) async => LocationPermission.denied);
    await pumpExplainer(tester);
    verifyNever(() => locationService.getCurrentLocation());
    await tester.tap(find.byKey(const Key('not-now-button'))); await tester.pumpAndSettle();
    verifyNever(() => locationService.requestPermission());
  });

}
