import 'helpers/visible.dart' as test_viewport;
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quickfix/core/theme/app_theme.dart';
import 'package:quickfix/core/widgets/loading_list.dart';
import 'package:quickfix/core/widgets/rank_badge.dart';
import 'package:quickfix/models/app_language.dart';
import 'package:quickfix/models/job_model.dart';
import 'package:quickfix/models/service_category.dart';
import 'package:quickfix/models/worker_filter.dart';
import 'package:quickfix/models/worker_profile.dart';
import 'package:quickfix/services/category_service.dart';
import 'package:quickfix/services/job_service.dart';
import 'package:quickfix/services/language_service.dart';
import 'package:quickfix/services/worker_filter_service.dart';
import 'package:quickfix/views/client/search_filter_screen.dart';

class MockCategories extends Mock implements CategoryService {}
class MockLanguages extends Mock implements LanguageService {}
class MockJobs extends Mock implements JobService {}
final _now = DateTime(2026, 10, 18, 12);
const _urdu = AppLanguage(code: 'ur', nativeName: 'اردو', englishName: 'Urdu');
const _balti = AppLanguage(code: 'bft', nativeName: 'بلتی', englishName: 'Balti');
WorkerProfile _worker(String id, JobCategory category, {bool available = true,
  List<String> languages = const [], double min = 1000, double max = 4000,
  GeoPoint? location = const GeoPoint(33.77, 72.36), int lifetime = 0,
}) => WorkerProfile(uid: id, fullName: 'Worker $id', email: '$id@example.com', professions: [category],
  languages: languages, minBudget: min, maxBudget: max, rating: 4.5, isAvailable: available,
  location: location, completedJobs: lifetime, createdAt: _now, updatedAt: _now);
JobModel _completed(String worker, int index) => JobModel(id: '$worker-$index', userId: 'client',
  workerId: worker, title: 'Work', description: '', category: JobCategory.plumbing,
  address: 'Attock', location: const GeoPoint(33.77, 72.36), budgetMin: 1000, budgetMax: 2000,
  preferredDate: _now, status: JobStatus.completed, completedAt: _now.subtract(const Duration(days: 1)),
  createdAt: _now, updatedAt: _now);

void main() {
  late MockCategories categories;
  late MockLanguages languages;
  late MockJobs jobs;
  late WorkerFilterService filters;
  late WorkerFilter? returned;
  late List<WorkerProfile> pool;
  setUp(() {
    categories = MockCategories(); languages = MockLanguages(); jobs = MockJobs();
    filters = WorkerFilterService(jobService: jobs); returned = null;
    pool = [
      _worker('w1', JobCategory.plumbing, languages: ['Urdu'], lifetime: 10000),
      _worker('w2', JobCategory.electrical, languages: ['Balti'], available: false, min: 2000, max: 6000),
      _worker('w3', JobCategory.cleaning, languages: ['Pahari'], min: 500, max: 1000, location: const GeoPoint(24.86, 67.01)),
    ];
    when(() => categories.getCategories()).thenAnswer((_) async => CategoryService.standardCategories);
    when(() => languages.getSpokenLanguages()).thenAnswer((_) async => [_urdu, _balti]);
    when(() => jobs.getWorkerJobs(any())).thenAnswer((_) async => []);
  });
  Future<void> pump(WidgetTester tester, {WorkerFilter? initial, GeoPoint? location = const GeoPoint(33.77, 72.36),
    String query = '', Size size = const Size(500, 1000), double scale = 1, bool settle = true,
  }) async {
    tester.view.physicalSize = size; tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(theme: AppTheme.lightTheme,
      builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)), child: child!),
      home: Builder(builder: (context) => Scaffold(body: Center(child: ElevatedButton(
        key: const Key('open-filters'), onPressed: () async {
          returned = await Navigator.of(context).push<WorkerFilter>(MaterialPageRoute(builder: (_) => SearchFilterScreen(
            pool: pool, initialFilter: initial, location: location, query: query,
            categoryService: categories, languageService: languages, jobService: jobs,
            filterService: filters, now: () => _now)));
        }, child: const Text('Open filters')))))));
    await tester.tap(find.byKey(const Key('open-filters')));
    if (settle) { await tester.pumpAndSettle(); } else { await tester.pump(); }
  }
  Future<void> reveal(WidgetTester tester, String key) async {
    await tester.scrollUntilVisible(find.byKey(Key(key)), 220, scrollable: find.byType(Scrollable).first);
    await test_viewport.reveal(tester, find.byKey(Key(key)));
  }
  testWidgets('catalog sections show skeletons while waiting and keep a live footer', (tester) async {
    final categoryRequest = Completer<List<ServiceCategory>>(); final languageRequest = Completer<List<AppLanguage>>();
    when(() => categories.getCategories()).thenAnswer((_) => categoryRequest.future);
    when(() => languages.getSpokenLanguages()).thenAnswer((_) => languageRequest.future);
    await pump(tester);
    expect(find.byType(LoadingList), findsWidgets);
    expect(find.text('Show 3 workers'), findsOneWidget);
    categoryRequest.complete(CategoryService.standardCategories); languageRequest.complete([_urdu]);
    await tester.pumpAndSettle();
  });
  testWidgets('category chips update result count and return immutable criteria', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('filter-category-plumbing'))); await tester.pumpAndSettle();
    expect(find.text('Show 1 worker'), findsOneWidget);
    await tester.tap(find.byKey(const Key('filter-show-button'))); await tester.pumpAndSettle();
    expect(returned!.categories, {JobCategory.plumbing});
    expect(() => returned!.categories.clear(), throwsUnsupportedError);
    verifyNever(() => jobs.getWorkerJobs(any()));
  });
  testWidgets('multiple services are OR selections', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('filter-category-plumbing')));
    await tester.tap(find.byKey(const Key('filter-category-electrical'))); await tester.pumpAndSettle();
    expect(find.text('Show 2 workers'), findsOneWidget);
  });
  testWidgets('price slider changes its labels, count and returned bounds', (tester) async {
    await pump(tester);
    await reveal(tester, 'filter-price-slider');
    tester.widget<RangeSlider>(find.byKey(const Key('filter-price-slider'))).onChanged!(const RangeValues(1500, 3000));
    await tester.pumpAndSettle();
    expect(find.text('PKR 1,500 – PKR 3,000'), findsOneWidget);
    expect(find.text('Show 2 workers'), findsOneWidget);
    await tester.tap(find.byKey(const Key('filter-show-button'))); await tester.pumpAndSettle();
    expect(returned!.minPrice, 1500); expect(returned!.maxPrice, 3000);
  });
  testWidgets('distance limit excludes far and unknown worker locations', (tester) async {
    pool.add(_worker('unknown', JobCategory.plumbing, location: null));
    await pump(tester); await reveal(tester, 'filter-distance-toggle');
    await tester.tap(find.byKey(const Key('filter-distance-toggle'))); await tester.pumpAndSettle();
    expect(find.text('Show 2 workers'), findsOneWidget);
    await tester.tap(find.byKey(const Key('filter-show-button'))); await tester.pumpAndSettle();
    expect(returned!.maxDistanceKm, 10);
  });
  testWidgets('no client location disables the radius and clears an inherited limit', (tester) async {
    await pump(tester, location: null, initial: WorkerFilter(maxDistanceKm: 5));
    await reveal(tester, 'filter-distance-toggle');
    expect(tester.widget<SwitchListTile>(find.byKey(const Key('filter-distance-toggle'))).onChanged, isNull);
    expect(find.textContaining('Location unavailable.'), findsOneWidget);
    expect(find.text('Show 3 workers'), findsOneWidget);
    await tester.tap(find.byKey(const Key('filter-show-button'))); await tester.pumpAndSettle();
    expect(returned!.maxDistanceKm, isNull);
  });
  testWidgets('rating stars and availability update the live count', (tester) async {
    await pump(tester); await reveal(tester, 'filter-rating-5');
    await tester.tap(find.byKey(const Key('filter-rating-5'))); await tester.pumpAndSettle();
    expect(find.text('Show 0 workers'), findsOneWidget);
    expect(find.byKey(const Key('filter-no-matches')), findsOneWidget);
    await tester.tap(find.byKey(const Key('filter-rating-any'))); await tester.pumpAndSettle();
    await reveal(tester, 'filter-availability-toggle');
    await tester.tap(find.byKey(const Key('filter-availability-toggle'))); await tester.pumpAndSettle();
    expect(find.text('Show 2 workers'), findsOneWidget);
  });
  testWidgets('new backend languages and observed profile languages are selectable dynamically', (tester) async {
    await pump(tester); await reveal(tester, 'filter-language-bft');
    expect(find.byKey(const Key('filter-language-pahari')), findsOneWidget);
    expect(tester.widget<Text>(find.text('بلتی')).textDirection, TextDirection.rtl);
    await tester.tap(find.byKey(const Key('filter-language-bft'))); await tester.pumpAndSettle();
    expect(find.text('Show 1 worker'), findsOneWidget);
    await tester.tap(find.byKey(const Key('filter-show-button'))); await tester.pumpAndSettle();
    expect(returned!.languages.single.code, 'bft');
    expect(filters.apply(pool, returned!).single.uid, 'w2');
  });
  testWidgets('annual ranks load only on selection and ignore lifetime totals', (tester) async {
    when(() => jobs.getWorkerJobs('w2')).thenAnswer((_) async => [for (var i = 0; i < 312; i++) _completed('w2', i)]);
    await pump(tester); verifyNever(() => jobs.getWorkerJobs(any()));
    await reveal(tester, 'filter-rank-Expert');
    expect(find.byType(RankEmblem), findsNWidgets(5));
    await tester.tap(find.byKey(const Key('filter-rank-Expert'))); await tester.pumpAndSettle();
    expect(find.text('Show 1 worker'), findsOneWidget);
    await tester.tap(find.byKey(const Key('filter-show-button'))); await tester.pumpAndSettle();
    expect(filters.apply(pool, returned!).single.uid, 'w2');
    expect(filters.annualCounts['w1'], 0);
  });
  testWidgets('rank lookup failure blocks Apply until a real Retry succeeds', (tester) async {
    when(() => jobs.getWorkerJobs(any())).thenThrow(StateError('offline'));
    await pump(tester); await reveal(tester, 'filter-rank-Expert');
    await tester.tap(find.byKey(const Key('filter-rank-Expert'))); await tester.pumpAndSettle();
    expect(tester.widget<ElevatedButton>(find.byKey(const Key('filter-show-button'))).onPressed, isNull);
    when(() => jobs.getWorkerJobs(any())).thenAnswer((_) async => []);
    await reveal(tester, 'filter-ranks-retry');
    await tester.tap(find.byKey(const Key('filter-ranks-retry'))); await tester.pumpAndSettle();
    expect(tester.widget<ElevatedButton>(find.byKey(const Key('filter-show-button'))).onPressed, isNotNull);
    expect(find.text('Show 0 workers'), findsOneWidget);
    expect(filters.annualCounts.keys, containsAll(['w1', 'w2', 'w3']));
  });
  testWidgets('Reset clears every criterion and restores the initial pool count', (tester) async {
    await pump(tester, initial: WorkerFilter(categories: [JobCategory.plumbing], minPrice: 1500, maxPrice: 3000,
      maxDistanceKm: 10, minimumRating: 5, ranks: ['Grandmaster'], onlyAvailable: true, languages: [_urdu]));
    await tester.tap(find.byKey(const Key('filter-reset-button'))); await tester.pumpAndSettle();
    expect(find.text('Show 3 workers'), findsOneWidget);
    await tester.tap(find.byKey(const Key('filter-show-button'))); await tester.pumpAndSettle();
    expect(returned!.isDefault, isTrue);
  });
  testWidgets('catalog errors retain usable choices and retry the real services', (tester) async {
    when(() => categories.getCategories()).thenThrow(StateError('offline'));
    when(() => languages.getSpokenLanguages()).thenThrow(StateError('offline'));
    await pump(tester);
    expect(find.textContaining('Could not load the category catalog.'), findsOneWidget);
    when(() => categories.getCategories()).thenAnswer((_) async => CategoryService.standardCategories);
    await tester.tap(find.byKey(const Key('filter-categories-retry'))); await tester.pumpAndSettle();
    verify(() => categories.getCategories()).called(2);
    await reveal(tester, 'filter-languages-retry');
    when(() => languages.getSpokenLanguages()).thenAnswer((_) async => [_urdu, _balti]);
    await tester.tap(find.byKey(const Key('filter-languages-retry'))); await tester.pumpAndSettle();
    await reveal(tester, 'filter-language-bft'); expect(find.byKey(const Key('filter-language-bft')), findsOneWidget);
    verify(() => languages.getSpokenLanguages()).called(2);
  });
  testWidgets('empty catalog and pool provide reload and reset actions', (tester) async {
    pool = [];
    when(() => categories.getCategories()).thenAnswer((_) async => []);
    when(() => languages.getSpokenLanguages()).thenAnswer((_) async => []);
    await pump(tester);
    expect(find.byKey(const Key('filter-categories-reload')), findsOneWidget);
    expect(find.byKey(const Key('filter-no-matches')), findsOneWidget);
    await reveal(tester, 'filter-languages-reload');
    expect(find.byKey(const Key('filter-languages-reload')), findsOneWidget);
    expect(find.byKey(const Key('filter-reset-button')), findsOneWidget);
  });
  testWidgets('the existing name search is included in the footer count', (tester) async {
    await pump(tester, query: 'worker w2');
    expect(find.text('Show 1 worker'), findsOneWidget);
  });
  testWidgets('Back discards local edits instead of returning criteria', (tester) async {
    await pump(tester); await tester.tap(find.byKey(const Key('filter-category-plumbing')));
    await tester.pageBack(); await tester.pumpAndSettle();
    expect(returned, isNull); expect(find.byType(SearchFilterScreen), findsNothing);
  });
  testWidgets('narrow enlarged UI wraps filter chips without overflow', (tester) async {
    await pump(tester, size: const Size(320, 900), scale: 1.5);
    await reveal(tester, 'filter-language-bft');
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('filter-show-button')), findsOneWidget);
  });
}
