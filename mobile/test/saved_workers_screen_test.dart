import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quickfix/core/widgets/loading_list.dart';
import 'package:quickfix/models/saved_worker.dart';
import 'package:quickfix/models/user_model.dart';
import 'package:quickfix/models/worker_profile.dart';
import 'package:quickfix/services/profile_service.dart';
import 'package:quickfix/services/worker_filter_service.dart';
import 'package:quickfix/views/client/saved_workers_screen.dart';
class MockProfiles extends Mock implements ProfileService {}
class MockFilters extends Mock implements WorkerFilterService {}
void main() {
  late MockProfiles profiles; late MockFilters filters;
  final user = UserModel(uid: 'u', email: '', fullName: 'Client', phone: '', role: UserRole.user, createdAt: DateTime(2026), updatedAt: DateTime(2026));
  setUpAll(() { registerFallbackValue(DateTime(2026)); registerFallbackValue(<String>[]); });
  setUp(() {
    profiles = MockProfiles(); filters = MockFilters();
    when(() => profiles.watchSavedWorkers('u')).thenAnswer((_) => Stream.value([]));
    when(() => filters.loadAnnualCounts(any(), now: any(named: 'now'))).thenAnswer((_) async => {'w': 156});
    when(() => profiles.setWorkerSaved(uid: 'u', workerId: any(named: 'workerId'), saved: any(named: 'saved'))).thenAnswer((_) async {});
  });
  Future<void> pump(WidgetTester tester) async { await tester.pumpWidget(MaterialApp(home: SavedWorkersScreen(user: user, profileService: profiles, workerFilterService: filters))); await tester.pump(); }
  testWidgets('loading and actionable empty branches', (tester) async {
    final pending = StreamController<List<SavedWorker>>(); addTearDown(pending.close);
    when(() => profiles.watchSavedWorkers('u')).thenAnswer((_) => pending.stream); await pump(tester); expect(find.byType(LoadingList), findsOneWidget);
    pending.add([]); await tester.pumpAndSettle(); expect(find.text('No saved workers yet'), findsOneWidget); expect(find.text('Browse workers'), findsOneWidget);
  });
  testWidgets('stream failure has a working retry', (tester) async {
    when(() => profiles.watchSavedWorkers('u')).thenAnswer((_) => Stream.error(StateError('offline'))); await pump(tester); await tester.pump();
    expect(find.text('Could not load your saved workers.'), findsOneWidget);
    when(() => profiles.watchSavedWorkers('u')).thenAnswer((_) => Stream.value([])); await tester.tap(find.text('Retry')); await tester.pumpAndSettle();
    expect(find.text('No saved workers yet'), findsOneWidget);
  });
  testWidgets('a deleted worker remains removable and undo restores only the ID', (tester) async {
    when(() => profiles.watchSavedWorkers('u')).thenAnswer((_) => Stream.value([const SavedWorker(uid: 'gone')])); await pump(tester); await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('saved-remove-gone'))); await tester.pumpAndSettle();
    verify(() => profiles.setWorkerSaved(uid: 'u', workerId: 'gone', saved: false)).called(1);
    await tester.tap(find.text('Undo')); await tester.pumpAndSettle(); verify(() => profiles.setWorkerSaved(uid: 'u', workerId: 'gone', saved: true)).called(1);
  });
  testWidgets('card uses annual rank, RTL name and separate profile/chat actions', (tester) async {
    final worker = WorkerProfile(uid: 'w', fullName: 'احمد', email: '', completedJobs: 9999, createdAt: DateTime(2026), updatedAt: DateTime(2026));
    when(() => profiles.watchSavedWorkers('u')).thenAnswer((_) => Stream.value([SavedWorker(uid: 'w', profile: worker)])); await pump(tester); await tester.pumpAndSettle();
    expect(find.text('Journeyman'), findsOneWidget); expect(find.text('Grandmaster'), findsNothing);
    expect(tester.widget<Text>(find.text('احمد')).textDirection, TextDirection.rtl);
    expect(find.byKey(const Key('saved-chat-w')), findsOneWidget); expect(find.byKey(const Key('saved-profile-w')), findsOneWidget);
  });
}
