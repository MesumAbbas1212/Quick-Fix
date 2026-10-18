import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quickfix/models/job_model.dart';
import 'package:quickfix/core/widgets/loading_list.dart';
import 'package:quickfix/models/user_model.dart';
import 'package:quickfix/models/worker_profile.dart';
import 'package:quickfix/services/location_service.dart';
import 'package:quickfix/services/profile_service.dart';
import 'package:quickfix/services/review_service.dart';
import 'package:quickfix/services/translation_service.dart';
import 'package:quickfix/views/client/worker_detail_screen.dart';
import 'package:quickfix/views/client/workers_screen.dart';
import 'package:quickfix/views/client/category_grid_screen.dart';

class MockProfileService extends Mock implements ProfileService {}
class MockLocationService extends Mock implements LocationService {}
class MockReviewService extends Mock implements ReviewService {}
class MockTranslationService extends Mock implements TranslationService {}

UserModel _user() {
  return UserModel(
    uid: 'u1',
    email: 'client@quickfix.com',
    fullName: 'Ahmed Ali',
    phone: '03001234567',
    role: UserRole.user,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );
}

WorkerProfile _worker({String uid = 'w1', GeoPoint? location}) {
  return WorkerProfile(
    uid: uid,
    fullName: 'Imran Khan',
    email: 'imran@quickfix.com',
    about: 'Plumber with 8 years of experience.',
    professions: const [JobCategory.plumbing, JobCategory.electrical],
    languages: const ['Urdu', 'English'],
    location: location,
    minBudget: 1500,
    maxBudget: 4000,
    rating: 4.5,
    completedJobs: 27,
    reviews: 31,
    isAvailable: true,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );
}

void main() {
  late MockProfileService profileService;
  late MockLocationService locationService;
  late MockReviewService reviewService;
  late MockTranslationService translationService;

  setUp(() {
    profileService = MockProfileService();
    locationService = MockLocationService();
    reviewService = MockReviewService();
    translationService = MockTranslationService();
    when(() => reviewService.watchReviewsForWorker(any()))
        .thenAnswer((_) => Stream.value(const []));
    when(() => locationService.getCurrentLocation())
        .thenAnswer((_) async => const GeoPoint(31.5, 74.3));
    when(() => profileService.searchWorkers(
          profession: any(named: 'profession'),
          maxDistanceKm: any(named: 'maxDistanceKm'),
          fromLocation: any(named: 'fromLocation'),
          limit: any(named: 'limit'),
        )).thenAnswer((_) async => [_worker()]);
  });

  Future<void> pumpWorkers(WidgetTester tester, {JobCategory? initialProfession}) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: WorkersScreen(
        user: _user(),
        initialProfession: initialProfession,
        profileService: profileService,
        locationService: locationService,
        reviewService: reviewService,
        translationService: translationService,
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('shows worker name and profession chips', (tester) async {
    await pumpWorkers(tester);

    expect(find.text('Imran Khan'), findsOneWidget);
    expect(find.text('Plumbing'), findsOneWidget);
    expect(find.text('Electrical'), findsOneWidget);
  });

  testWidgets('shows rating, completed jobs and distance', (tester) async {
    when(() => profileService.searchWorkers(
          profession: any(named: 'profession'),
          maxDistanceKm: any(named: 'maxDistanceKm'),
          fromLocation: any(named: 'fromLocation'),
          limit: any(named: 'limit'),
        )).thenAnswer((_) async => [
          _worker(location: const GeoPoint(31.53, 74.36)),
        ]);

    await pumpWorkers(tester);

    expect(find.text('4.5'), findsOneWidget);
    expect(find.text('27 jobs'), findsOneWidget);
    expect(find.textContaining('km away'), findsOneWidget);
  });

  testWidgets('hides distance when worker has no location', (tester) async {
    when(() => profileService.searchWorkers(
          profession: any(named: 'profession'),
          maxDistanceKm: any(named: 'maxDistanceKm'),
          fromLocation: any(named: 'fromLocation'),
          limit: any(named: 'limit'),
        )).thenAnswer((_) async => [_worker(location: null)]);

    await pumpWorkers(tester);

    expect(find.textContaining('km away'), findsNothing);
  });

  testWidgets('filters the existing pool by profession via dropdown', (tester) async {
    await pumpWorkers(tester);

    await tester.tap(find.byKey(const Key('profession-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Plumbing').last);
    await tester.pumpAndSettle();

    verify(() => profileService.searchWorkers(
          profession: null,
          maxDistanceKm: any(named: 'maxDistanceKm'),
          fromLocation: any(named: 'fromLocation'),
          limit: any(named: 'limit'),
        )).called(1);
  });

  testWidgets('shows empty state when no workers found', (tester) async {
    when(() => profileService.searchWorkers(
          profession: any(named: 'profession'),
          maxDistanceKm: any(named: 'maxDistanceKm'),
          fromLocation: any(named: 'fromLocation'),
          limit: any(named: 'limit'),
        )).thenAnswer((_) async => []);

    await pumpWorkers(tester);

    expect(find.text('No workers found'), findsOneWidget);
  });

  testWidgets('tapping a worker opens the detail screen', (tester) async {
    await pumpWorkers(tester);

    await tester.tap(find.text('Imran Khan'));
    await tester.pumpAndSettle();

    expect(find.byType(WorkerDetailScreen), findsOneWidget);
  });

  testWidgets('typing in search filters workers by name', (tester) async {
    when(() => profileService.searchWorkers(
          profession: any(named: 'profession'),
          maxDistanceKm: any(named: 'maxDistanceKm'),
          fromLocation: any(named: 'fromLocation'),
          limit: any(named: 'limit'),
        )).thenAnswer((_) async => [
          _worker(),
          _worker(uid: 'w2').copyWith(fullName: 'Ali Khan'),
        ]);

    await pumpWorkers(tester);

    expect(find.text('Imran Khan'), findsOneWidget);
    expect(find.text('Ali Khan'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'ali');
    await tester.pumpAndSettle();

    expect(find.text('Ali Khan'), findsOneWidget);
    expect(find.text('Imran Khan'), findsNothing);
  });

  testWidgets('initialProfession is selected without restricting the fetched pool', (tester) async {
    await pumpWorkers(tester, initialProfession: JobCategory.gardening);
    final filter = tester.widget<DropdownButton<JobCategory?>>(
        find.byKey(const Key('profession-filter')));
    expect(filter.value, JobCategory.gardening);
    verify(() => profileService.searchWorkers(
      profession: null,
      maxDistanceKm: null,
      fromLocation: const GeoPoint(31.5, 74.3),
      limit: 500,
    )).called(1);
  });

  testWidgets('worker fetch errors render before accessing missing snapshot data', (tester) async {
    when(() => profileService.searchWorkers(
      profession: any(named: 'profession'),
      maxDistanceKm: any(named: 'maxDistanceKm'),
      fromLocation: any(named: 'fromLocation'),
      limit: any(named: 'limit'),
    )).thenThrow(Exception('offline'));
    await pumpWorkers(tester);
    expect(find.text('Could not load workers. Check your connection.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    when(() => profileService.searchWorkers(
      profession: any(named: 'profession'),
      maxDistanceKm: any(named: 'maxDistanceKm'),
      fromLocation: any(named: 'fromLocation'),
      limit: any(named: 'limit'),
    )).thenAnswer((_) async => [_worker()]);
    await tester.tap(find.byKey(const Key('error-retry-button')));
    await tester.pumpAndSettle();
    expect(find.text('Imran Khan'), findsOneWidget);
  });

  testWidgets('the empty-state category CTA opens the grid with the same services', (tester) async {
    when(() => profileService.searchWorkers(
      profession: any(named: 'profession'),
      maxDistanceKm: any(named: 'maxDistanceKm'),
      fromLocation: any(named: 'fromLocation'),
      limit: any(named: 'limit'),
    )).thenAnswer((_) async => []);
    await pumpWorkers(tester);
    await tester.tap(find.byKey(const Key('browse-category-cta')));
    await tester.pumpAndSettle();
    final grid = tester.widget<CategoryGridScreen>(find.byType(CategoryGridScreen));
    expect(grid.profileService, same(profileService));
    expect(grid.locationService, same(locationService));
    expect(find.text('Browse by category'), findsOneWidget);
    expect(find.text('No workers available yet'), findsOneWidget);
  });


  testWidgets('a stalled location request falls back to the whole worker pool', (tester) async {
    final pending = Completer<GeoPoint?>();
    when(() => locationService.getCurrentLocation()).thenAnswer((_) => pending.future);
    await pumpWorkers(tester);
    expect(find.byType(LoadingList), findsOneWidget);
    await tester.pump(const Duration(seconds: 9));
    await tester.pumpAndSettle();
    expect(find.text('Imran Khan'), findsOneWidget);
    expect(find.textContaining('km away'), findsNothing);
    verify(() => profileService.searchWorkers(
      profession: null, maxDistanceKm: null, fromLocation: null, limit: 500,
    )).called(1);
    pending.complete(null);
    await tester.pump();
  });

}
