import 'package:quickfix/views/client/worker_comparison_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:quickfix/core/utils/location_access.dart';
import 'package:quickfix/core/theme/app_theme.dart';
import 'package:quickfix/core/utils/content_direction.dart';
import 'package:quickfix/core/widgets/empty_state.dart';
import 'package:quickfix/core/widgets/error_state.dart';
import 'package:quickfix/core/widgets/loading_list.dart';
import 'package:quickfix/core/widgets/job_category_icons.dart';
import 'package:quickfix/core/widgets/user_avatar.dart';
import 'package:quickfix/models/job_model.dart';
import 'package:quickfix/models/user_model.dart';
import 'package:quickfix/models/worker_profile.dart';
import 'package:quickfix/models/worker_filter.dart';
import 'package:quickfix/services/job_service.dart';
import 'package:quickfix/services/category_service.dart';
import 'package:quickfix/services/language_service.dart';
import 'package:quickfix/services/worker_filter_service.dart';
import 'package:quickfix/views/client/search_filter_screen.dart';
import 'package:quickfix/services/location_service.dart';
import 'package:quickfix/services/profile_service.dart';
import 'package:quickfix/services/review_service.dart';
import 'package:quickfix/services/translation_service.dart';
import 'package:quickfix/views/client/category_grid_screen.dart';
import 'package:quickfix/views/client/worker_detail_screen.dart';

/// Browse workers: profession filter, distance from the client's location
/// and a tap-through to the worker detail screen.
class WorkersScreen extends StatefulWidget {
  final UserModel user;
  final ProfileService? profileService;
  final LocationService? locationService;
  final ReviewService? reviewService;
  final TranslationService? translationService;
  final JobService? jobService;
  final CategoryService? categoryService;
  final LanguageService? languageService;
  final WorkerFilterService? filterService;
  final DateTime Function()? now;

  /// Pre-selects the profession filter (used by CategoryGridScreen so a
  /// tile tap lands on an already-filtered browse list).
  final JobCategory? initialProfession;

  const WorkersScreen({
    super.key,
    required this.user,
    this.profileService,
    this.locationService,
    this.reviewService,
    this.translationService,
    this.jobService,
    this.categoryService,
    this.languageService,
    this.filterService,
    this.now,
    this.initialProfession,
  });

  @override
  State<WorkersScreen> createState() => _WorkersScreenState();
}

class _WorkersScreenState extends State<WorkersScreen> {
  late final ProfileService _profileService =
      widget.profileService ?? ProfileService();
  late final LocationService _locationService =
      widget.locationService ?? LocationService();

  late final WorkerFilterService _filters = widget.filterService ?? WorkerFilterService(jobService: widget.jobService);
  late WorkerFilter _filter;
  List<WorkerProfile>? _pool;
  bool _poolLoading = true;
  JobCategory? _selectedProfession;
  Future<List<WorkerProfile>>? _workersFuture;
  GeoPoint? _userLocation;
  final _searchController = TextEditingController();
  String _query = '';

  /// First N cards shown before the "Show all" toggle expands the list.
  static const int _previewCount = 10;

  bool _compareMode = false;
  final _selected = <String>{};
  bool _showAllWorkers = false;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _selectedProfession = widget.initialProfession;
    _filter = WorkerFilter(categories: widget.initialProfession == null ? [] : [widget.initialProfession!]);
    _workersFuture = _loadWorkers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<List<WorkerProfile>> _loadWorkers() async {
    final generation = ++_loadGeneration;
    setState(() { _poolLoading = true; _pool = null; });
    try {
      GeoPoint? location;
      try {
        final allowed = await hasLocationAccess(_locationService);
        if (allowed) {
          location = await _locationService.getCurrentLocation().timeout(const Duration(seconds: 8));
        }
      } catch (_) { location = null; }
      if (!mounted || generation != _loadGeneration) return [];
      // Always fetch the unfiltered pool. Applying/widening criteria must not
      // silently operate on only the previously selected profession.
      final rows = await _profileService.searchWorkers(profession: null,
        fromLocation: location, maxDistanceKm: null, limit: 500)
          .timeout(const Duration(seconds: 10));
      if (!mounted || generation != _loadGeneration) return [];
      final pool = List<WorkerProfile>.unmodifiable(rows.take(500));
      setState(() {
        _pool = pool; _selected.removeWhere((id) => !pool.any((worker) => worker.uid == id)); _userLocation = location;
        if (location == null) _filter = _filter.copyWith(clearDistance: true);
      });
      final now = widget.now?.call() ?? DateTime.now();
      if (_filter.ranks.isNotEmpty && !_filters.hasAnnualCounts(pool.map((worker) => worker.uid), now)) {
        await _filters.loadAnnualCounts(pool.map((worker) => worker.uid), now: now,
          isCancelled: () => !mounted || generation != _loadGeneration);
      }
      return pool;
    } finally {
      if (mounted && generation == _loadGeneration) setState(() { _poolLoading = false; });
    }
  }

  void _onProfessionChanged(JobCategory? value) => setState(() {
    _selectedProfession = value;
    _filter = _filter.copyWith(categories: value == null ? [] : [value]);
    _showAllWorkers = false;
  });

  void _resetFilters() => setState(() {
    _filter = WorkerFilter(); _selectedProfession = null;
    _query = ''; _searchController.clear(); _showAllWorkers = false;
    if (_pool != null) _workersFuture = Future.value(_pool!);
  });

  Future<void> _openFilters() async {
    final pool = _pool;
    if (pool == null || _poolLoading) return;
    final filter = await Navigator.of(context).push<WorkerFilter>(MaterialPageRoute(
      builder: (_) => SearchFilterScreen(pool: pool, initialFilter: _filter,
        location: _userLocation, query: _query, categoryService: widget.categoryService,
        languageService: widget.languageService, jobService: widget.jobService,
        filterService: _filters, now: widget.now),
    ));
    if (!mounted || filter == null) return;
    setState(() {
      _filter = filter;
      _selectedProfession = filter.categories.length == 1 ? filter.categories.first : null;
      _showAllWorkers = false;
      _workersFuture = Future.value(pool); // No second worker query on Apply.
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            _buildSearchField(),
            _buildFilterRow(),
            _comparisonControls(),
            if (!_filter.isDefault || _query.trim().isNotEmpty)
              Padding(padding: const EdgeInsets.symmetric(horizontal: 14), child: Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, spacing: 8, children: [
                const Text('Filters active', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                TextButton(key: const Key('browse-reset-filters'), onPressed: _resetFilters, child: const Text('Clear filters')),
              ])),
            Expanded(
              child: FutureBuilder<List<WorkerProfile>>(
                future: _workersFuture,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return ErrorState(
                      message: 'Could not load workers. Check your connection.',
                      onRetry: () => setState(() {
                        _workersFuture = _loadWorkers();
                      }),
                    );
                  }
                  if (snapshot.connectionState != ConnectionState.done || !snapshot.hasData) {
                    return const LoadingList(rows: 3);
                  }
                  final workers = _filters.apply(snapshot.data!, _filter, origin: _userLocation, query: _query);
                  if (workers.isEmpty) {
                    return EmptyState(
                      icon: Icons.search_off_outlined,
                      title: _filter.isDefault && _query.trim().isEmpty ? 'No workers found' : 'No workers match — widen your filters',
                      message: 'Try another category, clear your name search or reset the filters.',
                      action: Column(mainAxisSize: MainAxisSize.min, children: [
                        if (!_filter.isDefault || _query.trim().isNotEmpty) OutlinedButton(
                          key: const Key('browse-empty-reset'), onPressed: _resetFilters, child: const Text('Reset filters')),
                        TextButton(
                          key: const Key('browse-category-cta'),
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => CategoryGridScreen(
                                user: widget.user,
                                profileService: _profileService,
                                locationService: _locationService,
                                jobService: widget.jobService,
                                reviewService: widget.reviewService,
                                translationService: widget.translationService,
                              ),
                            ),
                          ),
                          child: const Text('Browse by category',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                                  color: AppTheme.brandBlue)),
                        ),
                      ]),
                    );
                  }
                  final shown = _showAllWorkers
                      ? workers
                      : workers.take(_previewCount).toList();
                  return Column(
                    children: [
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.all(14),
                          itemCount: shown.length,
                          itemBuilder: (context, index) {
                            final worker = shown[index];
                            return _buildWorkerCard(worker);
                          },
                        ),
                      ),
                      if (workers.length > _previewCount)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                          child: TextButton(
                            key: const Key('show-all-workers-button'),
                            onPressed: () =>
                                setState(() => _showAllWorkers = !_showAllWorkers),
                            child: Text(
                              _showAllWorkers
                                  ? 'Show less'
                                  : 'Show all ${workers.length} workers',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.brandBlue,
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleComparison(String uid) {
    if (uid == widget.user.uid) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Choose another worker, not your own profile.'))); return; }
    if (_selected.contains(uid)) { setState(() { _selected.remove(uid); }); return; }
    if (_selected.length >= 3) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Compare up to three workers. Deselect one first.'))); return; }
    setState(() { _selected.add(uid); });
  }
  Widget _comparisonControls() {
    final selected = (_pool ?? const <WorkerProfile>[]).where((worker) => _selected.contains(worker.uid)).toList();
    return Padding(padding: const EdgeInsets.symmetric(horizontal: 14), child: Wrap(spacing: 10, children: [
      TextButton.icon(key: const Key('workers-compare-mode'), onPressed: () => setState(() { _compareMode = !_compareMode; if (!_compareMode) _selected.clear(); }), icon: const Icon(Icons.compare_arrows_outlined), label: Text(_compareMode ? 'Done selecting' : 'Select to compare')),
      if (_compareMode) ElevatedButton(key: const Key('workers-compare-selected'), onPressed: selected.length < 2 || selected.length > 3 || _poolLoading ? null : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => WorkerComparisonScreen(
        myId: widget.user.uid, workers: selected, origin: _userLocation, jobService: widget.jobService))), child: Text('Compare (${selected.length})')),
    ]));
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      color: AppTheme.brandBlue,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
      child: Row(
        children: [
          if (Navigator.of(context).canPop()) ...[
            IconButton(
              tooltip: 'Back',
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back, color: AppTheme.surfaceWhite),
            ),
            const SizedBox(width: 8),
          ],
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Workers',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800,
                        color: AppTheme.surfaceWhite)),
                SizedBox(height: 4),
                Text('Find skilled professionals near you.',
                    style: TextStyle(fontSize: 12, color: AppTheme.surfaceWhite)),
              ],
            ),
          ),
          IconButton(key: const Key('workers-location-button'), tooltip: 'Use my location',
            color: AppTheme.surfaceWhite, onPressed: _poolLoading ? null : () async {
              if (await explainLocationAccess(context, locationService: _locationService, purpose: 'Find workers near your current position') && mounted) {
                setState(() { _workersFuture = _loadWorkers(); });
              }
            }, icon: const Icon(Icons.my_location_outlined)),
          IconButton(key: const Key('workers-filter-button'), tooltip: 'Filter workers',
            onPressed: _pool == null || _poolLoading ? null : _openFilters,
            color: AppTheme.surfaceWhite, disabledColor: AppTheme.surfaceWhite.withValues(alpha: 0.5),
            icon: Icon(_filter.isDefault ? Icons.tune_outlined : Icons.filter_alt_outlined)),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
      child: TextField(
        key: const Key('workers-name-search'), controller: _searchController,
        textDirection: contentDirection(_query),
        onChanged: (value) => setState(() { _query = value; _showAllWorkers = false; }),
        decoration: InputDecoration(
          hintText: 'Search by name...',
          prefixIcon: const Icon(Icons.search, size: 20),
          filled: true,
          fillColor: AppTheme.surfaceWhite,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: AppTheme.borderGray),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: AppTheme.borderGray),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
      child: Row(
        children: [
          Expanded(child: Text(_userLocation == null ? 'All locations' : 'Nearest workers',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textDark))),
          const SizedBox(width: 8),
          Expanded(child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.surfaceWhite,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.borderGray),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<JobCategory?>(
                key: const Key('profession-filter'),
                isExpanded: true,
                value: _selectedProfession,
                hint: Text(
                  _filter.categories.length > 1 ? '${_filter.categories.length} services' : 'All Services',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                ),
                icon: const Icon(Icons.arrow_drop_down,
                    size: 18, color: AppTheme.brandBlue),
                borderRadius: BorderRadius.circular(16),
                items: [
                  const DropdownMenuItem<JobCategory?>(
                    value: null,
                    child: Text(
                      'All Services',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                  ...JobCategory.values.map(
                    (cat) => DropdownMenuItem<JobCategory?>(
                      value: cat,
                      child: Text(
                        _professionLabel(cat),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ],
                onChanged: _onProfessionChanged,
              ),
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildWorkerCard(WorkerProfile worker) {
    final distance = _distanceKm(worker.location, _userLocation);

    return GestureDetector(
      key: Key('worker-card-${worker.uid}'),
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (_compareMode) { _toggleComparison(worker.uid); return; }
        Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => WorkerDetailScreen(
            worker: worker,
            myId: widget.user.uid,
            reviewService: widget.reviewService,
            translationService: widget.translationService,
            jobService: widget.jobService,
            profileService: widget.profileService,
            userLanguage: widget.user.preferredLanguage,
          ),
        ),
      );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.surfaceWhite,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(color: _compareMode && _selected.contains(worker.uid) ? AppTheme.brandBlue : AppTheme.borderGray),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_compareMode) Checkbox(value: _selected.contains(worker.uid), onChanged: (_) => _toggleComparison(worker.uid)),
            UserAvatar(
              fullName: worker.fullName,
              avatarUrl: worker.avatarUrl,
              size: 48,
              online: worker.isAvailable,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          worker.fullName,
                          textDirection: contentDirection(worker.fullName),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textDark,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Icon(Icons.star,
                          size: 14, color: AppTheme.accentYellow),
                      const SizedBox(width: 2),
                      Text(
                        worker.rating.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: worker.professions.map((prof) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.brandBlue.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _professionLabel(prof),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.brandBlue,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (distance != null) ...[
                        const Icon(Icons.location_on_outlined,
                            size: 12, color: AppTheme.textMuted),
                        const SizedBox(width: 2),
                        Text(
                          '${distance.toStringAsFixed(1)} km away',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textMuted,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        '${worker.completedJobs} jobs',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppTheme.textMuted, size: 18),
          ],
        ),
      ),
    );
  }

  double? _distanceKm(GeoPoint? workerLocation, GeoPoint? userLocation) =>
      _filters.distanceKm(workerLocation, userLocation);

  String _professionLabel(JobCategory cat) => jobCategoryLabel(cat);
}
