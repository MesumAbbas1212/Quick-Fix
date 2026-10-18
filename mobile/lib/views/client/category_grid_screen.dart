import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:quickfix/core/utils/location_access.dart';
import 'package:geolocator/geolocator.dart';
import 'package:quickfix/core/theme/app_theme.dart';
import 'package:quickfix/core/widgets/empty_state.dart';
import 'package:quickfix/core/widgets/job_category_icons.dart';
import 'package:quickfix/core/widgets/loading_list.dart';
import 'package:quickfix/models/job_model.dart';
import 'package:quickfix/models/user_model.dart';
import 'package:quickfix/models/worker_profile.dart';
import 'package:quickfix/services/job_service.dart';
import 'package:quickfix/services/location_service.dart';
import 'package:quickfix/services/profile_service.dart';
import 'package:quickfix/services/review_service.dart';
import 'package:quickfix/services/translation_service.dart';
import 'package:quickfix/views/client/workers_screen.dart';

/// Category counts come from one fetched pool, not one query per tile.
/// Nearby means the client is inside a worker's configured travel radius.
/// Without location, counts are explicitly labelled as all fetched workers.
class CategoryGridScreen extends StatefulWidget {
  final UserModel user;
  final ProfileService? profileService;
  final LocationService? locationService;
  final JobService? jobService;
  final ReviewService? reviewService;
  final TranslationService? translationService;

  const CategoryGridScreen({
    super.key,
    required this.user,
    this.profileService,
    this.locationService,
    this.jobService,
    this.reviewService,
    this.translationService,
  });

  @override
  State<CategoryGridScreen> createState() => _CategoryGridScreenState();
}

class _CategoryGridScreenState extends State<CategoryGridScreen> {
  late final ProfileService _profileService =
      widget.profileService ?? ProfileService();
  late final LocationService _locationService =
      widget.locationService ?? LocationService();
  late Future<List<WorkerProfile>> _pool;
  GeoPoint? _origin;

  @override
  void initState() {
    super.initState();
    _pool = _loadPool();
  }

  Future<GeoPoint?> _location() async {
    try {
      if (!await hasLocationAccess(_locationService)) return null;
      return await _locationService.getCurrentLocation().timeout(
        const Duration(seconds: 8), onTimeout: () => null,
      );
    } catch (_) {
      return null;
    }
  }

  Future<List<WorkerProfile>> _loadPool() async {
    final location = _location();
    final workers = await _profileService
        .searchWorkers(limit: 500)
        .timeout(const Duration(seconds: 10));
    _origin = await location;
    return workers;
  }

  void _retry() {
    setState(() { _pool = _loadPool(); });
  }

  bool _isNearby(WorkerProfile worker) {
    final origin = _origin;
    final point = worker.location;
    if (origin == null || point == null) return false;
    return Geolocator.distanceBetween(
          origin.latitude, origin.longitude, point.latitude, point.longitude,
        ) / 1000 <= worker.serviceRadiusKm;
  }

  void _openCategory(JobCategory category) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => WorkersScreen(
        user: widget.user,
        initialProfession: category,
        profileService: _profileService,
        locationService: _locationService,
        jobService: widget.jobService,
        reviewService: widget.reviewService,
        translationService: widget.translationService,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(
        backgroundColor: AppTheme.brandBlue,
        foregroundColor: AppTheme.surfaceWhite,
        title: const Text('Browse by category',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        centerTitle: true,
        elevation: 0,
        actions: [IconButton(key: const Key('category-location-button'), tooltip: 'Use my location',
          onPressed: () async {
            if (await explainLocationAccess(context, locationService: _locationService, purpose: 'Show service counts near your position') && mounted) _retry();
          }, icon: const Icon(Icons.my_location_outlined))],
      ),
      body: SafeArea(
        child: FutureBuilder<List<WorkerProfile>>(
          future: _pool,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const LoadingList(rows: 3);
            }
            // Unlike an ordinary list error, B4 keeps the category tiles
            // usable even when counts cannot be fetched.
            final unknown = snapshot.hasError;
            final pool = snapshot.data ?? const <WorkerProfile>[];
            final countedPool = _origin == null
                ? pool
                : pool.where(_isNearby).toList();
            final counts = <JobCategory, int>{
              for (final category in JobCategory.values)
                category: countedPool.where((w) => w.professions.contains(category)).length,
            };
            return ListView(
              padding: const EdgeInsets.all(14),
              children: [
                if (unknown)
                  _countsError()
                else if (pool.isEmpty)
                  EmptyState(
                    icon: Icons.groups_outlined,
                    title: 'No workers available yet',
                    message: 'You can still browse services. Refresh to check for new workers.',
                    action: OutlinedButton(
                      key: const Key('empty-categories-refresh'),
                      onPressed: _retry,
                      child: const Text('Refresh workers'),
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Text(
                      _origin == null
                          ? 'Location unavailable — showing counts from the fetched worker pool.'
                          : 'Nearby means within each worker\'s travel radius. '
                              'Browse shows all workers, nearest first.',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                    ),
                  ),
                for (var i = 0; i < JobCategory.values.length; i += 2)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: _tile(JobCategory.values[i], counts, unknown)),
                          const SizedBox(width: 14),
                          Expanded(
                            child: i + 1 < JobCategory.values.length
                                ? _tile(JobCategory.values[i + 1], counts, unknown)
                                : const SizedBox.shrink(),
                          ),
                        ],
                      ),
                    ),
                  ),
                const Text(
                  'Counts are based on up to 500 fetched worker profiles.',
                  style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _countsError() => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(
          children: [
            const Icon(Icons.cloud_off_outlined, color: AppTheme.textMuted),
            const SizedBox(width: 10),
            const Expanded(
              child: Text('Worker counts could not load. You can still browse categories.',
                  style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
            ),
            TextButton(
              key: const Key('category-counts-retry'),
              onPressed: _retry,
              child: const Text('Retry'),
            ),
          ],
        ),
      );

  Widget _tile(JobCategory category, Map<JobCategory, int> counts, bool unknown) {
    final count = counts[category] ?? 0;
    return Material(
      color: AppTheme.surfaceWhite,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        key: Key('category-tile-${category.name}'),
        borderRadius: BorderRadius.circular(20),
        onTap: () => _openCategory(category),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.borderGray),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.brandBlue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(jobCategoryIcon(category), size: 20, color: AppTheme.brandBlue),
              ),
              const SizedBox(height: 10),
              Text(jobCategoryLabel(category),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                      color: AppTheme.textDark)),
              const SizedBox(height: 6),
              Text(
                unknown
                    ? 'Counts unavailable'
                    : '$count worker${count == 1 ? '' : 's'}${_origin == null ? '' : ' nearby'}',
                style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
