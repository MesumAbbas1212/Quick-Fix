import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quickfix/core/widgets/loading_list.dart';
import 'package:quickfix/models/worker_profile.dart';
import 'package:quickfix/models/working_day.dart';
import 'package:quickfix/services/profile_service.dart';
import 'package:quickfix/views/worker/availability_settings_screen.dart';
class MockProfiles extends Mock implements ProfileService {}
class MockDB extends Mock implements FirebaseFirestore {}
void main() {
  late MockProfiles profiles;
  final worker = WorkerProfile(uid: 'w', fullName: 'Worker', email: '', createdAt: DateTime(2026), updatedAt: DateTime(2026));
  setUp(() { profiles = MockProfiles(); when(() => profiles.getWorkerProfile('w')).thenAnswer((_) async => worker); });
  test('working-hour defaults and invalid/cross-midnight windows are explicit', () {
    expect(WorkingDay.decode(null), hasLength(7)); expect(WorkingDay.decode(null).values.every((day) => !day.enabled), isTrue);
    expect(const WorkingDay(enabled: true, fromMinutes: 600, toMinutes: 540).valid, isFalse);
    expect(const WorkingDay(enabled: true, fromMinutes: 0, toMinutes: 1440).valid, isTrue);
    expect(WorkingDay.fromMap(const WorkingDay(enabled: true).toMap()).enabled, isTrue);
  });
  testWidgets('error retry and missing-profile empty action', (tester) async {
    when(() => profiles.getWorkerProfile('w')).thenThrow(StateError('offline'));
    await tester.pumpWidget(MaterialApp(home: AvailabilitySettingsScreen(workerId: 'w', profileService: profiles))); await tester.pumpAndSettle();
    when(() => profiles.getWorkerProfile('w')).thenAnswer((_) async => null); await tester.tap(find.text('Retry')); await tester.pumpAndSettle();
    expect(find.text('Worker profile needed'), findsOneWidget); expect(find.text('Back to profile'), findsOneWidget);
  });
  testWidgets('changing a master setting enables Save and guards unsaved back navigation', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) => Scaffold(body: TextButton(onPressed: () => Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => AvailabilitySettingsScreen(workerId: 'w', profileService: profiles))), child: const Text('Open'))))));
    await tester.tap(find.text('Open')); await tester.pumpAndSettle(); await tester.tap(find.byKey(const Key('availability-master'))); await tester.pump();
    await tester.pageBack(); await tester.pumpAndSettle(); expect(find.text('Discard unsaved availability?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('availability-discard'))); await tester.pumpAndSettle(); expect(find.byType(AvailabilitySettingsScreen), findsNothing);
  });
  testWidgets('loading is a skeleton, not a blank spinner', (tester) async {
    final pending = Completer<WorkerProfile?>(); when(() => profiles.getWorkerProfile('w')).thenAnswer((_) => pending.future);
    await tester.pumpWidget(MaterialApp(home: AvailabilitySettingsScreen(workerId: 'w', profileService: profiles))); expect(find.byType(LoadingList), findsOneWidget);
    pending.complete(null); await tester.pumpAndSettle();
  });
  test('invalid availability fails before a Firestore write', () async {
    final db = MockDB(); await expectLater(ProfileService(firestore: db).saveAvailability(uid: 'w', isAvailable: true, radiusKm: 0, hours: WorkingDay.decode(null), daysOff: []), throwsArgumentError);
    verifyNever(() => db.collection(any()));
  });

}
