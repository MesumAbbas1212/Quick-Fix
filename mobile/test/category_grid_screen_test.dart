import 'helpers/visible.dart' as test_viewport;
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quickfix/core/widgets/job_category_icons.dart';
import 'package:quickfix/core/widgets/loading_list.dart';
import 'package:quickfix/models/job_model.dart';
import 'package:quickfix/models/user_model.dart';
import 'package:quickfix/models/worker_profile.dart';
import 'package:quickfix/services/job_service.dart';
import 'package:quickfix/services/location_service.dart';
import 'package:quickfix/services/profile_service.dart';
import 'package:quickfix/views/client/category_grid_screen.dart';
import 'package:quickfix/views/client/workers_screen.dart';

class MockProfileService extends Mock implements ProfileService {}
class MockLocationService extends Mock implements LocationService {}
class MockJobService extends Mock implements JobService {}

final _at = DateTime(2026, 10, 1);
final _client = UserModel(
  uid: 'c1', email: 'client@example.com', fullName: 'Client One',
  phone: '+92 300 7654321', role: UserRole.user, createdAt: _at, updatedAt: _at,
);

WorkerProfile _worker(String uid, List<JobCategory> professions, {
  GeoPoint? location, int radius = 5,
}) => WorkerProfile(
      uid: uid, fullName: 'Worker $uid', email: '$uid@example.com',
      professions: professions, location: location, serviceRadiusKm: radius,
      createdAt: _at, updatedAt: _at,
    );

void main() {
  group('CategoryGridScreen', () {
    late MockProfileService profiles;
    late MockLocationService location;
    late MockJobService jobs;

    void stubPool(List<WorkerProfile> pool) {
      when(() => profiles.searchWorkers(
        profession: any(named: 'profession'),
        fromLocation: any(named: 'fromLocation'),
        maxDistanceKm: any(named: 'maxDistanceKm'),
        limit: 500,
      )).thenAnswer((_) async => pool);
    }

    Future<void> pumpGrid(WidgetTester tester) async {
      tester.view.physicalSize = const Size(400, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: CategoryGridScreen(
          user: _client, profileService: profiles,
          locationService: location, jobService: jobs,
        ),
      ));
      await tester.pump();
      await tester.pump();
    }

    Finder tile(JobCategory category) =>
        find.byKey(Key('category-tile-${category.name}'));

    setUp(() {
      profiles = MockProfileService();
      location = MockLocationService();
      jobs = MockJobService();
      when(() => location.getPermissionStatus()).thenAnswer((_) async => LocationPermission.whileInUse);
      when(() => location.getCurrentLocation()).thenAnswer((_) async => null);
      stubPool([]);
    });

    testWidgets('shows skeletons while counts are loading', (tester) async {
      final pending = Completer<List<WorkerProfile>>();
      when(() => profiles.searchWorkers(limit: 500)).thenAnswer((_) => pending.future);
      await pumpGrid(tester);
      expect(find.byType(LoadingList), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      pending.complete([]);
      await tester.pumpAndSettle();
    });

    testWidgets('counts each profession once from one pool query', (tester) async {
      stubPool([
        _worker('w1', [JobCategory.plumbing]),
        _worker('w2', [JobCategory.plumbing, JobCategory.cleaning]),
        _worker('w3', [JobCategory.cleaning]),
      ]);
      await pumpGrid(tester);
      expect(find.text('Browse by category'), findsOneWidget);
      for (final category in JobCategory.values) {
        expect(tile(category), findsOneWidget);
        expect(find.descendant(of: tile(category),
            matching: find.byIcon(jobCategoryIcon(category))), findsOneWidget);
      }
      expect(find.text('2 workers'), findsNWidgets(2));
      expect(find.text('0 workers'), findsNWidgets(JobCategory.values.length - 2));
      expect(find.text('Appliance Repair'), findsOneWidget);
      expect(find.text('Plumbing'), findsOneWidget);
      expect(find.textContaining('Location unavailable'), findsOneWidget);
      expect(find.textContaining('workers nearby'), findsNothing);
      verify(() => profiles.searchWorkers(limit: 500)).called(1);
    });

    testWidgets('nearby counts respect worker travel radii and exclude unknown locations', (tester) async {
      when(() => location.getPermissionStatus()).thenAnswer((_) async => LocationPermission.whileInUse);
      when(() => location.getCurrentLocation())
          .thenAnswer((_) async => const GeoPoint(33.77, 72.37));
      stubPool([
        _worker('near', [JobCategory.plumbing], location: const GeoPoint(33.77, 72.37)),
        // About 3 km away, but this worker only travels 1 km.
        _worker('outside-radius', [JobCategory.plumbing],
            location: const GeoPoint(33.80, 72.37), radius: 1),
        _worker('far', [JobCategory.plumbing], location: const GeoPoint(24.86, 67.01)),
        _worker('unknown', [JobCategory.plumbing]),
      ]);
      await pumpGrid(tester);
      await tester.pumpAndSettle();
      verify(() => location.getPermissionStatus()).called(1);
      verify(() => location.getCurrentLocation()).called(1);
      expect(find.descendant(of: tile(JobCategory.plumbing),
          matching: find.text('1 worker nearby')), findsOneWidget);
      expect(find.text('0 workers nearby'), findsNWidgets(JobCategory.values.length - 1));
      expect(find.textContaining('within each worker'), findsOneWidget);
      expect(find.textContaining('nearest first'), findsOneWidget);
    });

    testWidgets('a tile opens WorkersScreen pre-filtered and preserves services', (tester) async {
      stubPool([_worker('w1', [JobCategory.gardening])]);
      await pumpGrid(tester);
      await test_viewport.reveal(tester, tile(JobCategory.gardening));
      await tester.tap(tile(JobCategory.gardening));
      await tester.pumpAndSettle();
      final browse = tester.widget<WorkersScreen>(find.byType(WorkersScreen));
      expect(browse.initialProfession, JobCategory.gardening);
      expect(browse.profileService, same(profiles));
      expect(browse.locationService, same(location));
      expect(browse.jobService, same(jobs));
      expect(browse.user.preferredLanguage, _client.preferredLanguage);
      // One full pool for grid counts and one for the pushed browse route;
      // the selected category is applied locally, not in the server query.
      verify(() => profiles.searchWorkers(
        profession: null, fromLocation: null,
        maxDistanceKm: null, limit: 500,
      )).called(2);
      expect(find.text('Worker w1'), findsOneWidget);
      // Pushed browse pages have a visible way back; shell tabs do not need one.
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(CategoryGridScreen), findsOneWidget);
    });

    testWidgets('an error keeps every tile usable and omits counts', (tester) async {
      when(() => profiles.searchWorkers(limit: 500))
          .thenThrow(Exception('offline'));
      await pumpGrid(tester);
      for (final category in JobCategory.values) {
        expect(tile(category), findsOneWidget);
      }
      expect(find.text('Counts unavailable'), findsNWidgets(JobCategory.values.length));
      expect(find.textContaining('Worker counts could not load'), findsOneWidget);
      expect(find.text('0 workers'), findsNothing);
      stubPool([_worker('w1', [JobCategory.plumbing])]);
      await tester.tap(find.byKey(const Key('category-counts-retry')));
      await tester.pumpAndSettle();
      expect(find.text('Counts unavailable'), findsNothing);
      expect(find.text('1 worker'), findsOneWidget);
      verify(() => profiles.searchWorkers(limit: 500)).called(2);
    });

    testWidgets('an empty pool still offers categories and a working refresh', (tester) async {
      await pumpGrid(tester);
      expect(find.text('No workers available yet'), findsOneWidget);
      expect(tile(JobCategory.plumbing), findsOneWidget);
      expect(find.text('0 workers'), findsNWidgets(JobCategory.values.length));
      stubPool([_worker('w1', [JobCategory.beauty])]);
      await tester.tap(find.byKey(const Key('empty-categories-refresh')));
      await tester.pumpAndSettle();
      expect(find.text('No workers available yet'), findsNothing);
      expect(find.text('1 worker'), findsOneWidget);
      verify(() => profiles.searchWorkers(limit: 500)).called(2);
    });

    testWidgets('a slow GPS request falls back to non-nearby counts', (tester) async {
      final pending = Completer<GeoPoint?>();
      when(() => location.getCurrentLocation()).thenAnswer((_) => pending.future);
      stubPool([_worker('w1', [JobCategory.plumbing])]);
      await pumpGrid(tester);
      expect(find.byType(LoadingList), findsOneWidget);
      await tester.pump(const Duration(seconds: 9));
      await tester.pumpAndSettle();
      expect(find.text('1 worker'), findsOneWidget);
      expect(find.textContaining('Location unavailable'), findsOneWidget);
      pending.complete(null);
      await tester.pump();
    });

    testWidgets('the odd final tile stays one column wide', (tester) async {
      stubPool([_worker('w1', [JobCategory.other])]);
      await pumpGrid(tester);
      final firstWidth = tester.getSize(tile(JobCategory.cleaning)).width;
      final lastWidth = tester.getSize(tile(JobCategory.other)).width;
      expect(lastWidth, closeTo(firstWidth, 0.01));
      expect(tester.takeException(), isNull);
    });
  });
}
