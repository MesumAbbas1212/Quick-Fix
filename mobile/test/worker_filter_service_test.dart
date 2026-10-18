import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quickfix/models/app_language.dart';
import 'package:quickfix/models/job_model.dart';
import 'package:quickfix/models/worker_filter.dart';
import 'package:quickfix/models/worker_profile.dart';
import 'package:quickfix/services/job_service.dart';
import 'package:quickfix/services/worker_filter_service.dart';

class MockJobs extends Mock implements JobService {}
final _now = DateTime(2026, 10, 18, 12);
const _urdu = AppLanguage(code: 'ur', nativeName: 'اردو', englishName: 'Urdu');
const _balti = AppLanguage(code: 'bft', nativeName: 'بلتی', englishName: 'Balti');
WorkerProfile _worker(String id, {List<JobCategory> categories = const [JobCategory.plumbing],
  double min = 1000, double max = 4000, double rating = 4.5,
  bool available = true, List<String> languages = const [], GeoPoint? location, int lifetime = 900,
}) => WorkerProfile(uid: id, fullName: 'Worker $id', email: '$id@example.com', professions: categories,
  minBudget: min, maxBudget: max, rating: rating, isAvailable: available, languages: languages,
  location: location, completedJobs: lifetime, createdAt: _now, updatedAt: _now);
JobModel _job(String worker, DateTime date, {JobStatus status = JobStatus.completed}) => JobModel(
  id: '$worker-${date.microsecondsSinceEpoch}', userId: 'client', workerId: worker, title: 'Completed work',
  description: '', category: JobCategory.plumbing, address: 'Attock', location: const GeoPoint(33.77, 72.36),
  budgetMin: 1000, budgetMax: 2000, preferredDate: date, status: status, completedAt: date,
  createdAt: date, updatedAt: date);

void main() {
  group('immutable WorkerFilter', () {
    test('copies input collections and exposes no mutable selection', () {
      final input = <JobCategory>{JobCategory.plumbing};
      final filter = WorkerFilter(categories: input, ranks: ['Expert'], languages: [_urdu]);
      input.clear();
      expect(filter.categories, {JobCategory.plumbing});
      expect(() => filter.categories.add(JobCategory.cleaning), throwsUnsupportedError);
      expect(() => filter.ranks.clear(), throwsUnsupportedError);
      expect(() => filter.languages.add(_balti), throwsUnsupportedError);
    });
    test('copyWith supports clearing optional limits without changing the original', () {
      final first = WorkerFilter(maxPrice: 4000, maxDistanceKm: 10, onlyAvailable: true);
      final next = first.copyWith(clearMaxPrice: true, clearDistance: true);
      expect(next.maxPrice, isNull); expect(next.maxDistanceKm, isNull); expect(next.onlyAvailable, isTrue);
      expect(first.maxPrice, 4000); expect(first.maxDistanceKm, 10);
    });
    test('unordered equal criteria have equal value hashes', () {
      final first = WorkerFilter(categories: [JobCategory.plumbing, JobCategory.cleaning], languages: [_urdu, _balti]);
      final second = WorkerFilter(categories: [JobCategory.cleaning, JobCategory.plumbing], languages: [_balti, _urdu]);
      expect(first, second); expect(first.hashCode, second.hashCode);
      expect(WorkerFilter().isDefault, isTrue);
      expect(first.isDefault, isFalse);
    });
  });

  group('client-side criteria', () {
    late WorkerFilterService service;
    setUp(() { service = WorkerFilterService(); }); // Pure use never initializes Firebase.
    test('no criteria includes the whole pool, including missing prices/locations', () {
      final pool = [_worker('a'), _worker('b', min: 0, max: 0)];
      expect(service.apply(pool, WorkerFilter()), pool);
    });
    test('categories are OR selections and combine with the name search', () {
      final pool = [_worker('a'), _worker('b', categories: [JobCategory.cleaning]), _worker('c', categories: [JobCategory.beauty])];
      final filter = WorkerFilter(categories: [JobCategory.plumbing, JobCategory.cleaning]);
      expect(service.apply(pool, filter).map((w) => w.uid), ['a', 'b']);
      expect(service.apply(pool, filter, query: 'WORKER B').single.uid, 'b');
    });
    test('price ranges overlap inclusively rather than matching one endpoint', () {
      final pool = [_worker('overlap', min: 1000, max: 4000), _worker('touch', min: 6000, max: 8000),
        _worker('cheap', min: 100, max: 1000), _worker('high', min: 7000, max: 9000)];
      expect(service.apply(pool, WorkerFilter(minPrice: 3000, maxPrice: 6000)).map((w) => w.uid), ['overlap', 'touch']);
    });
    test('unknown and invalid prices do not masquerade as a matching free quote', () {
      final pool = [_worker('missing', min: 0, max: 0), _worker('invalid', min: 4000, max: 1000),
        _worker('nan', max: double.nan), _worker('known')];
      expect(service.apply(pool, WorkerFilter(maxPrice: 5000)).single.uid, 'known');
    });
    test('rating threshold and availability combine', () {
      final pool = [_worker('rated'), _worker('low', rating: 3), _worker('busy', available: false), _worker('nan', rating: double.nan)];
      expect(service.apply(pool, WorkerFilter(minimumRating: 4, onlyAvailable: true)).single.uid, 'rated');
    });
    test('distance is geodesic in kilometres and excludes missing positions only with a limit', () {
      const origin = GeoPoint(33.77, 72.36);
      final pool = [_worker('far', location: const GeoPoint(24.86, 67.01)), _worker('unknown'), _worker('near', location: origin)];
      expect(service.distanceKm(origin, origin), closeTo(0, 0.001));
      expect(service.distanceKm(const GeoPoint(24.86, 67.01), origin), greaterThan(1000));
      expect(service.apply(pool, WorkerFilter(maxDistanceKm: 10), origin: origin).single.uid, 'near');
      expect(service.apply(pool, WorkerFilter(), origin: origin).map((w) => w.uid), ['near', 'far', 'unknown']);
    });
    test('a distance constraint with no origin never invents nearby matches', () {
      expect(service.apply([_worker('a')], WorkerFilter(maxDistanceKm: 10)), isEmpty);
    });
    test('equal distances and unknown positions retain stable pool order', () {
      const origin = GeoPoint(33.77, 72.36);
      final pool = [_worker('missing-first'), _worker('first', location: origin), _worker('second', location: origin), _worker('missing-last')];
      expect(service.apply(pool, WorkerFilter(), origin: origin).map((w) => w.uid), ['first', 'second', 'missing-first', 'missing-last']);
    });
    test('rank filters use annual counts, never the worker lifetime field', () {
      final pool = [_worker('new', lifetime: 10000), _worker('annual', lifetime: 0), _worker('unknown', lifetime: 10000)];
      expect(service.apply(pool, WorkerFilter(ranks: ['Expert']), annualCounts: {'new': 0, 'annual': 312}).single.uid, 'annual');
      expect(service.apply(pool, WorkerFilter(ranks: ['Apprentice']), annualCounts: {'new': 0, 'annual': 312}).single.uid, 'new');
    });
    test('every 156-completion boundary matches the exact annual rank ladder', () {
      final pool = [for (final id in ['a', 'j', 'e', 'm', 'g']) _worker(id)];
      final counts = {'a': 155, 'j': 156, 'e': 312, 'm': 468, 'g': 624};
      for (final entry in {'Apprentice': 'a', 'Journeyman': 'j', 'Expert': 'e', 'Master': 'm', 'Grandmaster': 'g'}.entries) {
        expect(service.apply(pool, WorkerFilter(ranks: [entry.key]), annualCounts: counts).single.uid, entry.value);
      }
    });
    test('dynamic language metadata matches codes, names, native text and region tags', () {
      final pool = [_worker('code', languages: ['ur']), _worker('name', languages: [' Urdu ']),
        _worker('native', languages: ['اردو']), _worker('region', languages: ['ur_PK']), _worker('other', languages: ['Balti'])];
      expect(service.apply(pool, WorkerFilter(languages: [_urdu])).map((w) => w.uid), ['code', 'name', 'native', 'region']);
    });
    test('language multi-select is any selected language and needs no fixed supported list', () {
      final pool = [_worker('balti', languages: ['Balti']), _worker('urdu', languages: ['ur']), _worker('none')];
      expect(service.apply(pool, WorkerFilter(languages: [_urdu, _balti])).map((w) => w.uid), ['balti', 'urdu']);
    });
    test('language options merge a dynamic catalog and observed data without alias duplicates', () {
      final options = service.languageOptions([_urdu, _balti], [
        _worker('a', languages: ['Urdu', 'ur_PK', 'اردو', 'Pahari', ' pahari ', '']),
      ]);
      expect(options.map((l) => l.code), ['bft', 'pahari', 'ur']);
      expect(options.singleWhere((l) => l.code == 'pahari').displayName, 'Pahari');
    });
    test('price ceiling accommodates the pool and a previously selected maximum', () {
      expect(service.priceCeiling([_worker('a', max: 11501)], WorkerFilter()), 12000);
      expect(service.priceCeiling([], WorkerFilter(maxPrice: 20000)), 20000);
    });
    test('combined filters do not mutate the source pool', () {
      final pool = [_worker('a', languages: ['Urdu']), _worker('b', available: false)];
      final result = service.apply(pool, WorkerFilter(onlyAvailable: true, minPrice: 2000, languages: [_urdu]));
      expect(result.single.uid, 'a'); expect(pool.length, 2);
      expect(() => result.clear(), throwsUnsupportedError);
    });
  });

  group('bounded annual-rank lookup', () {
    late MockJobs jobs;
    late WorkerFilterService service;
    setUp(() { jobs = MockJobs(); service = WorkerFilterService(jobService: jobs); });
    test('counts only completed jobs within the inclusive trailing 365-day window', () async {
      when(() => jobs.getWorkerJobs('w1')).thenAnswer((_) async => [
        _job('w1', _now), _job('w1', _now.subtract(const Duration(days: 365))),
        _job('w1', _now.subtract(const Duration(days: 365, seconds: 1))),
        _job('w1', _now.add(const Duration(seconds: 1))), _job('w1', _now, status: JobStatus.assigned), _job('other', _now),
      ]);
      final result = await service.loadAnnualCounts(['w1', 'w1'], now: _now);
      expect(result, {'w1': 2}); expect(service.hasAnnualCounts(['w1'], _now), isTrue);
      expect(service.hasAnnualCounts(['w1'], _now.add(const Duration(minutes: 6))), isFalse);
      expect(service.hasAnnualCounts(['missing'], _now), isFalse);
      expect(() => result['w1'] = 9, throwsUnsupportedError);
      verify(() => jobs.getWorkerJobs('w1')).called(1);
    });
    test('a failed history read does not silently count a worker as Apprentice', () async {
      when(() => jobs.getWorkerJobs('w1')).thenThrow(StateError('offline'));
      await expectLater(service.loadAnnualCounts(['w1'], now: _now), throwsStateError);
      expect(service.annualCounts, isEmpty); expect(service.countsAsOf, isNull);
      expect(service.apply([_worker('w1')], WorkerFilter(ranks: ['Apprentice'])), isEmpty);
    });
    test('at most eight history requests are in flight and later requests are queued', () async {
      final pending = <String, Completer<List<JobModel>>>{};
      var active = 0; var maximum = 0;
      when(() => jobs.getWorkerJobs(any())).thenAnswer((call) {
        final id = call.positionalArguments.single as String;
        final completer = Completer<List<JobModel>>(); pending[id] = completer;
        active++; if (active > maximum) maximum = active;
        return completer.future.whenComplete(() { active--; });
      });
      final result = service.loadAnnualCounts([for (var i = 0; i < 12; i++) 'w$i'], now: _now);
      await Future<void>.delayed(Duration.zero);
      expect(active, 8); expect(pending.length, 8);
      for (final completer in pending.values.toList()) { completer.complete([]); }
      await Future<void>.delayed(Duration.zero);
      expect(pending.length, 12); expect(maximum, 8);
      for (final completer in pending.values.where((c) => !c.isCompleted).toList()) { completer.complete([]); }
      expect((await result).length, 12);
    });
    test('cancellation stops queued reads and does not cache a partial result', () async {
      var cancelled = false;
      final pending = <Completer<List<JobModel>>>[];
      when(() => jobs.getWorkerJobs(any())).thenAnswer((_) {
        final completer = Completer<List<JobModel>>(); pending.add(completer); return completer.future;
      });
      final result = service.loadAnnualCounts([for (var i = 0; i < 12; i++) 'w$i'], now: _now, isCancelled: () => cancelled);
      final expectation = expectLater(result, throwsStateError);
      await Future<void>.delayed(Duration.zero); cancelled = true;
      for (final completer in pending) { completer.complete([]); }
      await expectation;
      expect(pending.length, 8); expect(service.annualCounts, isEmpty);
    });
    test('deadline failures surface instead of hanging', () async {
      when(() => jobs.getWorkerJobs(any())).thenAnswer((_) async => []);
      await expectLater(service.loadAnnualCounts(['w1'], now: _now, totalTimeout: Duration.zero), throwsA(isA<TimeoutException>()));
      verifyNever(() => jobs.getWorkerJobs(any()));
    });
    test('stalled individual queries time out without caching unknown ranks', () async {
      final pending = Completer<List<JobModel>>();
      when(() => jobs.getWorkerJobs(any())).thenAnswer((_) => pending.future);
      await expectLater(service.loadAnnualCounts(['w1'], now: _now, queryTimeout: Duration.zero), throwsA(isA<TimeoutException>()));
      expect(service.annualCounts, isEmpty);
      pending.complete([]);
    });
    test('rank lookup never schedules more than the 500-worker browse cap', () async {
      when(() => jobs.getWorkerJobs(any())).thenAnswer((_) async => []);
      final counts = await service.loadAnnualCounts([for (var i = 0; i < 510; i++) 'w$i'], now: _now);
      expect(counts.length, 500);
      verify(() => jobs.getWorkerJobs(any())).called(500);
    });
    test('an empty pool completes with an empty, valid snapshot', () async {
      expect(await service.loadAnnualCounts([], now: _now), isEmpty);
      expect(service.hasAnnualCounts([], _now), isTrue);
      verifyNever(() => jobs.getWorkerJobs(any()));
    });
  });
}
