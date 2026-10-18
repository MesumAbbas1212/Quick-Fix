import 'dart:async';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:quickfix/models/app_language.dart';
import 'package:quickfix/models/job_model.dart';
import 'package:quickfix/models/worker_filter.dart';
import 'package:quickfix/models/worker_profile.dart';
import 'package:quickfix/models/worker_rank.dart';
import 'package:quickfix/services/job_service.dart';

/// Client-side criteria and an on-demand annual-rank snapshot. Reuses the
/// existing single-worker history query, with bounded concurrency and deadlines;
/// no new query/index, lifetime-count substitution, or background subscription.
class WorkerFilterService {
  final JobService? _injectedJobs;
  WorkerFilterService({JobService? jobService}) : _injectedJobs = jobService;
  late final JobService _jobs = _injectedJobs ?? JobService();
  Map<String, int> _annualCounts = const {};
  DateTime? _countsAsOf;
  Map<String, int> get annualCounts => _annualCounts;
  DateTime? get countsAsOf => _countsAsOf;

  bool hasAnnualCounts(Iterable<String> ids, DateTime now) => _countsAsOf != null &&
      now.difference(_countsAsOf!).abs() <= const Duration(minutes: 5) &&
      ids.every(_annualCounts.containsKey);

  Future<Map<String, int>> loadAnnualCounts(Iterable<String> workerIds, {
    required DateTime now, bool Function()? isCancelled,
    Duration queryTimeout = const Duration(seconds: 5),
    Duration totalTimeout = const Duration(seconds: 20),
  }) async {
    final ids = workerIds.where((id) => id.isNotEmpty).toSet().take(500).toList();
    final result = <String, int>{};
    final clock = Stopwatch()..start();
    var next = 0;
    var aborted = false;
    void checkActive() {
      if (aborted || isCancelled?.call() == true) throw StateError('Rank lookup cancelled.');
      if (clock.elapsed >= totalTimeout) throw TimeoutException('Rank lookup timed out.');
    }
    Future<void> consume() async {
      while (next < ids.length) {
        checkActive();
        final id = ids[next++];
        final remaining = totalTimeout - clock.elapsed;
        final timeout = remaining < queryTimeout ? remaining : queryTimeout;
        final jobs = await _jobs.getWorkerJobs(id).timeout(timeout);
        checkActive();
        result[id] = WorkerRank.countCompletedInYear(jobs.where((job) =>
          job.workerId == id && job.status == JobStatus.completed)
            .map((job) => job.completedAt ?? job.updatedAt), now: now);
      }
    }
    try {
      await Future.wait(List.generate(math.min(8, ids.length), (_) => consume()), eagerError: true);
      checkActive();
      _annualCounts = Map.unmodifiable(result);
      _countsAsOf = now;
      return _annualCounts;
    } catch (_) {
      aborted = true; // Stop scheduling more history reads after any failure.
      rethrow;
    } finally { clock.stop(); }
  }

  List<WorkerProfile> apply(Iterable<WorkerProfile> pool, WorkerFilter filter, {
    GeoPoint? origin, String query = '', Map<String, int>? annualCounts,
  }) {
    final counts = annualCounts ?? _annualCounts;
    final name = query.trim().toLowerCase();
    final filtered = pool.where((worker) {
      if (name.isNotEmpty && !worker.fullName.toLowerCase().contains(name)) return false;
      if (filter.categories.isNotEmpty && !worker.professions.any(filter.categories.contains)) return false;
      if (filter.onlyAvailable && !worker.isAvailable) return false;
      if (filter.minimumRating > 0 && (!worker.rating.isFinite || worker.rating < filter.minimumRating)) return false;
      if (filter.minPrice > 0 || filter.maxPrice != null) {
        if (!worker.minBudget.isFinite || !worker.maxBudget.isFinite || worker.minBudget < 0 ||
            worker.maxBudget <= 0 || worker.maxBudget < worker.minBudget) return false;
        // Ranges overlap, inclusively; an unspecified price is not a free quote.
        if (worker.maxBudget < filter.minPrice || (filter.maxPrice != null && worker.minBudget > filter.maxPrice!)) return false;
      }
      if (filter.maxDistanceKm != null) {
        final distance = distanceKm(worker.location, origin);
        if (distance == null || distance > filter.maxDistanceKm!) return false;
      }
      if (filter.ranks.isNotEmpty) {
        final count = counts[worker.uid];
        if (count == null || !filter.ranks.contains(WorkerRank.forCompletedInYear(count).name)) return false;
      }
      if (filter.languages.isNotEmpty && !filter.languages.any((language) =>
          worker.languages.any((raw) => _speaks(raw, language)))) return false;
      return true;
    }).toList();
    if (origin == null) return List.unmodifiable(filtered);
    final sorted = filtered.asMap().entries.map((entry) => (
      worker: entry.value, distance: distanceKm(entry.value.location, origin), index: entry.key,
    )).toList()..sort((a, b) {
      final first = a.distance; final second = b.distance;
      if (first == null && second != null) return 1;
      if (first != null && second == null) return -1;
      final order = first == null || second == null ? 0 : first.compareTo(second);
      return order == 0 ? a.index.compareTo(b.index) : order;
    });
    return List.unmodifiable(sorted.map((entry) => entry.worker));
  }

  double? distanceKm(GeoPoint? worker, GeoPoint? origin) {
    if (worker == null || origin == null) return null;
    return Geolocator.distanceBetween(origin.latitude, origin.longitude,
      worker.latitude, worker.longitude) / 1000;
  }

  String _normalize(String value) => value.trim().toLowerCase().replaceAll('_', '-');
  bool _speaks(String raw, AppLanguage language) {
    final value = _normalize(raw);
    final code = _normalize(language.code);
    if (value.isEmpty) return false;
    return value == code || value == _normalize(language.nativeName) ||
      value == _normalize(language.englishName) ||
      (value.contains('-') && value.split('-').first == code);
  }

  /// Catalog aliases plus observed backend profile data, never a fixed list.
  List<AppLanguage> languageOptions(Iterable<AppLanguage> catalog, Iterable<WorkerProfile> pool) {
    final options = <String, AppLanguage>{};
    for (final language in catalog) {
      final code = _normalize(language.code);
      if (code.isEmpty) continue;
      options[code] = AppLanguage(code: code, nativeName: language.nativeName, englishName: language.englishName);
    }
    for (final worker in pool) {
      for (final raw in worker.languages) {
        final name = raw.trim(); final key = _normalize(name);
        if (key.isEmpty || options.values.any((language) => _speaks(name, language))) continue;
        options[key] = AppLanguage(code: key, nativeName: name, englishName: name);
      }
    }
    final result = options.values.toList()..sort((a, b) => _normalize(a.englishName.isEmpty ? a.displayName : a.englishName)
        .compareTo(_normalize(b.englishName.isEmpty ? b.displayName : b.englishName)));
    return List.unmodifiable(result);
  }

  double priceCeiling(Iterable<WorkerProfile> pool, WorkerFilter initial) {
    var maximum = math.max(5000.0, initial.maxPrice ?? initial.minPrice);
    for (final worker in pool) {
      if (worker.maxBudget.isFinite) maximum = math.max(maximum, worker.maxBudget);
    }
    return (maximum / 500).ceil() * 500.0;
  }
}
