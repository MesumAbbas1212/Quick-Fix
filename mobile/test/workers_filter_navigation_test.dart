import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quickfix/core/theme/app_theme.dart';
import 'package:quickfix/models/app_language.dart';
import 'package:quickfix/models/job_model.dart';
import 'package:quickfix/models/user_model.dart';
import 'package:quickfix/models/worker_profile.dart';
import 'package:quickfix/services/category_service.dart';
import 'package:quickfix/services/job_service.dart';
import 'package:quickfix/services/language_service.dart';
import 'package:quickfix/services/location_service.dart';
import 'package:quickfix/services/profile_service.dart';
import 'package:quickfix/views/client/search_filter_screen.dart';
import 'package:quickfix/views/client/workers_screen.dart';

class MockProfiles extends Mock implements ProfileService {}
class MockLocation extends Mock implements LocationService {}
class MockCategories extends Mock implements CategoryService {}
class MockLanguages extends Mock implements LanguageService {}
class MockJobs extends Mock implements JobService {}
final _now = DateTime(2026, 10, 18);
final _user = UserModel(uid: 'me', email: 'client@example.com', fullName: 'Client', phone: '',
  role: UserRole.user, createdAt: _now, updatedAt: _now);
WorkerProfile _worker(String id, JobCategory category, {bool available = true, List<String> languages = const []}) =>
  WorkerProfile(uid: id, fullName: 'Worker $id', email: '$id@example.com', professions: [category],
    languages: languages, isAvailable: available, minBudget: 1000, maxBudget: 4000,
    rating: 4.5, createdAt: _now, updatedAt: _now);

void main() {
  late MockProfiles profiles;
  late MockLocation location;
  late MockCategories categories;
  late MockLanguages languages;
  late MockJobs jobs;
  late List<WorkerProfile> pool;
  setUp(() {
    profiles = MockProfiles(); location = MockLocation(); categories = MockCategories(); languages = MockLanguages(); jobs = MockJobs();
    pool = [_worker('plumber', JobCategory.plumbing, languages: ['Urdu']),
      _worker('electrician', JobCategory.electrical, languages: ['Balti'], available: false)];
    when(() => profiles.searchWorkers(profession: any(named: 'profession'), fromLocation: any(named: 'fromLocation'),
      maxDistanceKm: any(named: 'maxDistanceKm'), limit: 500)).thenAnswer((_) async => pool);
    when(() => location.getPermissionStatus()).thenAnswer((_) async => LocationPermission.whileInUse);
    when(() => location.getCurrentLocation()).thenAnswer((_) async => null);
    when(() => categories.getCategories()).thenAnswer((_) async => CategoryService.standardCategories);
    when(() => languages.getSpokenLanguages()).thenAnswer((_) async => [
      const AppLanguage(code: 'ur', englishName: 'Urdu', nativeName: 'اردو'),
      const AppLanguage(code: 'bft', englishName: 'Balti', nativeName: 'بلتی'),
    ]);
    when(() => jobs.getWorkerJobs(any())).thenAnswer((_) async => []);
  });
  Future<void> pump(WidgetTester tester, {JobCategory? initial, Size size = const Size(500, 1000), double scale = 1}) async {
    tester.view.physicalSize = size; tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(theme: AppTheme.lightTheme,
      builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)), child: child!),
      home: WorkersScreen(user: _user, profileService: profiles, locationService: location,
        categoryService: categories, languageService: languages, jobService: jobs,
        initialProfession: initial, now: () => _now)));
    await tester.pumpAndSettle();
  }
  Future<void> open(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('workers-filter-button'))); await tester.pumpAndSettle();
  }
  void onePoolRead() {
    verify(() => profiles.searchWorkers(profession: null, fromLocation: null, maxDistanceKm: null, limit: 500)).called(1);
  }
  testWidgets('filter icon opens the actual screen with the full cached pool', (tester) async {
    await pump(tester); await open(tester);
    final page = tester.widget<SearchFilterScreen>(find.byType(SearchFilterScreen));
    expect(page.pool.length, 2); expect(page.categoryService, same(categories)); expect(page.languageService, same(languages));
    expect(find.text('Show 2 workers'), findsOneWidget);
    onePoolRead();
  });
  testWidgets('widening an initial category restores workers without another query', (tester) async {
    await pump(tester, initial: JobCategory.plumbing);
    expect(find.text('Worker plumber'), findsOneWidget); expect(find.text('Worker electrician'), findsNothing);
    await open(tester); expect(find.text('Show 1 worker'), findsOneWidget);
    await tester.tap(find.byKey(const Key('filter-reset-button'))); await tester.pumpAndSettle();
    expect(find.text('Show 2 workers'), findsOneWidget);
    await tester.tap(find.byKey(const Key('filter-show-button'))); await tester.pumpAndSettle();
    expect(find.text('Worker plumber'), findsOneWidget); expect(find.text('Worker electrician'), findsOneWidget);
    onePoolRead();
  });
  testWidgets('returned dynamic-language criteria match the same workers as the footer', (tester) async {
    await pump(tester); await open(tester);
    await tester.scrollUntilVisible(find.byKey(const Key('filter-language-bft')), 240,
      scrollable: find.byType(Scrollable).last);
    await tester.tap(find.byKey(const Key('filter-language-bft'))); await tester.pumpAndSettle();
    expect(find.text('Show 1 worker'), findsOneWidget);
    await tester.tap(find.byKey(const Key('filter-show-button'))); await tester.pumpAndSettle();
    expect(find.text('Worker electrician'), findsOneWidget); expect(find.text('Worker plumber'), findsNothing);
    onePoolRead();
  });
  testWidgets('empty filtered results have a working reset action', (tester) async {
    await pump(tester); await open(tester);
    await tester.tap(find.byKey(const Key('filter-category-cleaning'))); await tester.pumpAndSettle();
    expect(find.text('No workers match — widen your filters'), findsOneWidget);
    await tester.tap(find.byKey(const Key('filter-show-button'))); await tester.pumpAndSettle();
    expect(find.text('No workers match — widen your filters'), findsOneWidget);
    await tester.tap(find.byKey(const Key('browse-empty-reset'))); await tester.pumpAndSettle();
    expect(find.text('Worker plumber'), findsOneWidget); expect(find.text('Worker electrician'), findsOneWidget);
    onePoolRead();
  });
  testWidgets('legacy dropdown now narrows locally and preserves the unfiltered pool', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('profession-filter'))); await tester.pumpAndSettle();
    await tester.tap(find.text('Plumbing').last); await tester.pumpAndSettle();
    expect(find.text('Worker plumber'), findsOneWidget); expect(find.text('Worker electrician'), findsNothing);
    await tester.tap(find.byKey(const Key('browse-reset-filters'))); await tester.pumpAndSettle();
    expect(find.text('Worker electrician'), findsOneWidget);
    onePoolRead();
  });
  testWidgets('Show all still expands beyond the ten-card preview', (tester) async {
    pool = [for (var i = 0; i < 12; i++) _worker('$i', JobCategory.plumbing)];
    await pump(tester);
    expect(find.text('Show all 12 workers'), findsOneWidget);
    await tester.tap(find.byKey(const Key('show-all-workers-button'))); await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byKey(const Key('worker-card-11')), 240);
    expect(find.byKey(const Key('worker-card-11')), findsOneWidget);
    expect(find.text('Show less'), findsOneWidget);
    onePoolRead();
  });
  testWidgets('browse header and category dropdown fit narrow enlarged UI', (tester) async {
    pool = [_worker('repair', JobCategory.applianceRepair)];
    await pump(tester, initial: JobCategory.applianceRepair, size: const Size(320, 900), scale: 1.5);
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('workers-filter-button')), findsOneWidget);
  });
}
