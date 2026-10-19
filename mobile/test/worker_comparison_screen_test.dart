import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quickfix/models/user_model.dart';
import 'package:quickfix/models/worker_profile.dart';
import 'package:quickfix/services/location_service.dart';
import 'package:quickfix/services/profile_service.dart';
import 'package:quickfix/services/worker_comparison_service.dart';
import 'package:quickfix/views/client/worker_comparison_screen.dart';
import 'package:quickfix/views/client/workers_screen.dart';
class MockComparison extends Mock implements WorkerComparisonService {}
class MockProfiles extends Mock implements ProfileService {}
class MockLocations extends Mock implements LocationService {}
WorkerProfile worker(String uid) => WorkerProfile(uid: uid, fullName: uid == 'w1' ? 'احمد' : 'Worker $uid', email: '', rating: 4.5, reviews: 100, completedJobs: 9999, createdAt: DateTime(2026), updatedAt: DateTime(2026));
void main() {
  test('selection is guarded to two/three distinct profiles', () {
    expect(WorkerComparisonService.validSelection([worker('w1')]), isFalse); expect(WorkerComparisonService.validSelection([worker('w1'), worker('w1')]), isFalse);
    expect(WorkerComparisonService.validSelection([worker('w1'), worker('w2')]), isTrue); expect(WorkerComparisonService.validSelection([worker('w1'), worker('w2'), worker('w3'), worker('w4')]), isFalse);
  });
  testWidgets('annual rank ignores lifetime count and footer Chat stays outside vertical body', (tester) async {
    final service = MockComparison(); when(() => service.annualCount('w1')).thenAnswer((_) async => 156); when(() => service.annualCount('w2')).thenAnswer((_) async => 0);
    await tester.pumpWidget(MaterialApp(home: WorkerComparisonScreen(myId: 'me', workers: [worker('w1'), worker('w2')], comparisonService: service))); await tester.pumpAndSettle();
    expect(find.text('Journeyman'), findsOneWidget); expect(find.text('Grandmaster'), findsNothing); expect(tester.widget<Text>(find.text('احمد')).textDirection, TextDirection.rtl);
    expect(find.byKey(const Key('comparison-chat-w1')), findsOneWidget); expect(find.byKey(const Key('comparison-chat-w2')), findsOneWidget);
  });
  testWidgets('failed annual cell is a dash and retries without invented zero history', (tester) async {
    final service = MockComparison(); when(() => service.annualCount('w1')).thenThrow(StateError('offline')); when(() => service.annualCount('w2')).thenAnswer((_) async => 0);
    // Real service failures are asynchronous; mirror that for the widget contract.
    when(() => service.annualCount('w1')).thenAnswer((_) async => throw StateError('offline'));
    await tester.pumpWidget(MaterialApp(home: WorkerComparisonScreen(myId: 'me', workers: [worker('w1'), worker('w2')], comparisonService: service))); await tester.pumpAndSettle();
    expect(find.byTooltip('Annual work history unavailable — retry from the toolbar'), findsWidgets);
    when(() => service.annualCount('w1')).thenAnswer((_) async => 156); await tester.tap(find.byKey(const Key('comparison-retry'))); await tester.pumpAndSettle(); expect(find.text('Journeyman'), findsOneWidget);
  });
  testWidgets('Workers multi-select opens the real comparison page only with two choices', (tester) async {
    final profiles = MockProfiles(); final locations = MockLocations(); final user = UserModel(uid: 'me', email: '', fullName: 'Client', phone: '', role: UserRole.user, createdAt: DateTime(2026), updatedAt: DateTime(2026));
    when(() => locations.getPermissionStatus()).thenAnswer((_) async => LocationPermission.denied);
    when(() => profiles.searchWorkers(profession: null, fromLocation: null, maxDistanceKm: null, limit: 500)).thenAnswer((_) async => [worker('w1'), worker('w2')]);
    tester.view.physicalSize = const Size(1000, 1200); tester.view.devicePixelRatio = 1; addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: WorkersScreen(user: user, profileService: profiles, locationService: locations))); await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('workers-compare-mode'))); await tester.pump(); expect(tester.widget<ElevatedButton>(find.byKey(const Key('workers-compare-selected'))).onPressed, isNull);
    await tester.tap(find.byKey(const Key('worker-card-w1'))); await tester.pump(); await tester.tap(find.byKey(const Key('worker-card-w2'))); await tester.pump();
    await tester.tap(find.byKey(const Key('workers-compare-selected'))); await tester.pumpAndSettle(); expect(find.byType(WorkerComparisonScreen), findsOneWidget);
  });
}
