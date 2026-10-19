import 'helpers/visible.dart' as test_viewport;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quickfix/models/location_selection.dart';
import 'package:quickfix/services/location_service.dart';
import 'package:quickfix/services/map_launcher.dart';
import 'package:quickfix/views/client/location_picker_screen.dart';
import 'package:quickfix/views/jobs/post_job_screen.dart';
class MockLocations extends Mock implements LocationService {}
class MockMaps extends Mock implements UrlLauncher {}
void main() {
  late MockLocations locations; late MockMaps maps;
  setUp(() { locations = MockLocations(); maps = MockMaps(); when(() => locations.getPermissionStatus()).thenAnswer((_) async => LocationPermission.always); });
  test('coordinate parsing rejects nonfinite and out of range and normalizes precision', () {
    for (final value in ['NaN', 'Infinity', '91', '-91', 'no']) { expect(LocationSelection.parse(value, '72'), isNull); }
    expect(LocationSelection.parse('33', '181'), isNull); expect(LocationSelection.parse('33.123456', '72.123456'), const GeoPoint(33.12346, 72.12346));
    expect(LocationSelection.parse('0', '0'), const GeoPoint(0, 0));
  });
  testWidgets('opening never requests a position and manual input works without permission', (tester) async {
    await tester.pumpWidget(MaterialApp(home: LocationPickerScreen(locationService: locations, initialAddress: 'Attock')));
    verifyNever(() => locations.getCurrentLocation());
    await tester.tap(find.byKey(const Key('location-manual-fallback'))); await tester.pump();
    await tester.enterText(find.byKey(const Key('location-latitude')), '33.77'); await tester.enterText(find.byKey(const Key('location-longitude')), '72.36'); await tester.pump();
    expect(find.text('33.77000, 72.36000'), findsOneWidget); verifyNever(() => locations.requestPermission());
  });
  testWidgets('GPS failure exposes a retry and manual fallback', (tester) async {
    when(() => locations.getCurrentLocation()).thenThrow(StateError('no fix'));
    await tester.pumpWidget(MaterialApp(home: LocationPickerScreen(locationService: locations)));
    await tester.tap(find.byKey(const Key('location-current'))); await tester.pumpAndSettle(); expect(find.textContaining('Could not get a position'), findsOneWidget);
    when(() => locations.getCurrentLocation()).thenAnswer((_) async => const GeoPoint(33.77, 72.36));
    await tester.tap(find.byKey(const Key('location-current'))); await tester.pumpAndSettle(); expect(find.text('33.77000, 72.36000'), findsOneWidget);
  });
  testWidgets('map failure is visible without losing the selected pin', (tester) async {
    when(() => maps.openLocation(33, 72)).thenAnswer((_) async => false);
    await tester.pumpWidget(MaterialApp(home: LocationPickerScreen(initialLocation: const GeoPoint(33, 72), initialAddress: 'Attock', urlLauncher: maps)));
    await tester.tap(find.byKey(const Key('location-open-maps'))); await tester.pumpAndSettle(); expect(find.textContaining('Could not open Maps'), findsOneWidget);
    expect(find.text('33.00000, 72.00000'), findsOneWidget);
  });
  testWidgets('Post Job accepts a manually corrected location through the picker result', (tester) async {
    await tester.pumpWidget(MaterialApp(home: PostJobScreen(userId: 'u', suggestedAddress: 'Attock', locationService: locations)));
    await test_viewport.reveal(tester, find.byKey(const Key('postjob-location-picker'))); await tester.tap(find.byKey(const Key('postjob-location-picker'))); await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('location-manual-fallback'))); await tester.pump();
    await tester.enterText(find.byKey(const Key('location-latitude')), '33.77'); await tester.enterText(find.byKey(const Key('location-longitude')), '72.36'); await tester.pump();
    await test_viewport.reveal(tester, find.byKey(const Key('location-use'))); await tester.tap(find.byKey(const Key('location-use'))); await tester.pumpAndSettle();
    expect(find.text('Selected pin: 33.77000, 72.36000'), findsOneWidget); verifyNever(() => locations.getCurrentLocation());
  });
}
