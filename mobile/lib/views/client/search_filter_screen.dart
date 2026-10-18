import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:quickfix/core/theme/app_theme.dart';
import 'package:quickfix/core/utils/content_direction.dart';
import 'package:quickfix/core/widgets/app_card.dart';
import 'package:quickfix/core/widgets/job_category_icons.dart';
import 'package:quickfix/core/widgets/loading_list.dart';
import 'package:quickfix/core/widgets/rank_badge.dart';
import 'package:quickfix/models/app_language.dart';
import 'package:quickfix/models/service_category.dart';
import 'package:quickfix/models/worker_filter.dart';
import 'package:quickfix/models/worker_profile.dart';
import 'package:quickfix/models/worker_rank.dart';
import 'package:quickfix/services/category_service.dart';
import 'package:quickfix/services/job_service.dart';
import 'package:quickfix/services/language_service.dart';
import 'package:quickfix/services/worker_filter_service.dart';

/// Refines a snapshot of the already-fetched browse pool (at most 500).
/// Returning criteria is the only effect on the previous route. Rank histories
/// are read only on demand; category/language choices come from backend data.
class SearchFilterScreen extends StatefulWidget {
  final List<WorkerProfile> pool;
  final WorkerFilter? initialFilter;
  final GeoPoint? location;
  final String query;
  final CategoryService? categoryService;
  final LanguageService? languageService;
  final JobService? jobService;
  final WorkerFilterService? filterService;
  final DateTime Function()? now;

  const SearchFilterScreen({super.key, required this.pool, this.initialFilter,
    this.location, this.query = '', this.categoryService, this.languageService,
    this.jobService, this.filterService, this.now});
  @override
  State<SearchFilterScreen> createState() => _SearchFilterScreenState();
}

class _SearchFilterScreenState extends State<SearchFilterScreen> {
  late final CategoryService _categories = widget.categoryService ?? CategoryService();
  late final LanguageService _languages = widget.languageService ?? LanguageService();
  late final WorkerFilterService _filters = widget.filterService ?? WorkerFilterService(jobService: widget.jobService);
  late final List<WorkerProfile> _pool = List.unmodifiable(widget.pool.take(500));
  late final DateTime _clock = widget.now?.call() ?? DateTime.now();
  late WorkerFilter _filter;
  late final double _priceCeiling;
  List<ServiceCategory> _categoryOptions = const [];
  List<AppLanguage> _languageCatalog = const [];
  bool _categoryLoading = true;
  bool _languageLoading = true;
  bool _rankLoading = false;
  String? _categoryError;
  String? _languageError;
  String? _rankError;
  int _categoryGeneration = 0;
  int _languageGeneration = 0;
  int _rankGeneration = 0;

  @override
  void initState() {
    super.initState();
    _filter = widget.initialFilter ?? WorkerFilter();
    if (widget.location == null && _filter.maxDistanceKm != null) _filter = _filter.copyWith(clearDistance: true);
    _priceCeiling = _filters.priceCeiling(_pool, _filter);
    _loadCategories();
    _loadLanguages();
    if (_filter.ranks.isNotEmpty && !_filters.hasAnnualCounts(_pool.map((w) => w.uid), _clock)) _loadRanks();
  }

  @override
  void dispose() {
    _rankGeneration++; // Stop scheduling further on-demand history reads.
    super.dispose();
  }

  Future<void> _loadCategories() async {
    final generation = ++_categoryGeneration;
    setState(() { _categoryLoading = true; _categoryError = null; });
    try {
      final options = await _categories.getCategories().timeout(const Duration(seconds: 10));
      if (!mounted || generation != _categoryGeneration) return;
      setState(() { _categoryOptions = options.where((item) => item.isActive).toList(); _categoryLoading = false; });
    } catch (_) {
      if (!mounted || generation != _categoryGeneration) return;
      setState(() {
        _categoryError = 'Could not load the category catalog. Standard services are shown below.';
        _categoryOptions = CategoryService.standardCategories;
        _categoryLoading = false;
      });
    }
  }

  Future<void> _loadLanguages() async {
    final generation = ++_languageGeneration;
    setState(() { _languageLoading = true; _languageError = null; });
    try {
      final options = await _languages.getSpokenLanguages().timeout(const Duration(seconds: 15));
      if (!mounted || generation != _languageGeneration) return;
      setState(() { _languageCatalog = options; _languageLoading = false; });
    } catch (_) {
      if (!mounted || generation != _languageGeneration) return;
      setState(() {
        _languageError = 'Could not load the language catalog. Languages observed on worker profiles are still available.';
        _languageLoading = false;
      });
    }
  }

  Future<void> _loadRanks() async {
    if (_rankLoading) return;
    final generation = ++_rankGeneration;
    setState(() { _rankLoading = true; _rankError = null; });
    try {
      await _filters.loadAnnualCounts(_pool.map((worker) => worker.uid), now: _clock,
        isCancelled: () => !mounted || generation != _rankGeneration);
      if (!mounted || generation != _rankGeneration) return;
      setState(() { _rankLoading = false; });
    } catch (_) {
      if (!mounted || generation != _rankGeneration) return;
      setState(() { _rankLoading = false; _rankError = 'Could not calculate annual ranks. Retry or clear the rank selection.'; });
    }
  }

  void _toggleRank(WorkerRank rank) {
    final ranks = {..._filter.ranks};
    ranks.contains(rank.name) ? ranks.remove(rank.name) : ranks.add(rank.name);
    setState(() {
      _filter = _filter.copyWith(ranks: ranks);
      if (ranks.isEmpty) { _rankGeneration++; _rankLoading = false; _rankError = null; }
    });
    if (ranks.isNotEmpty && !_filters.hasAnnualCounts(_pool.map((w) => w.uid), _clock)) _loadRanks();
  }

  void _reset() => setState(() {
    _filter = WorkerFilter(); _rankGeneration++; _rankLoading = false; _rankError = null;
  });

  @override
  Widget build(BuildContext context) {
    final count = _filters.apply(_pool, _filter, origin: widget.location, query: widget.query).length;
    final ranksUnavailable = _filter.ranks.isNotEmpty && (_rankLoading || _rankError != null);
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(backgroundColor: AppTheme.surfaceWhite, elevation: 0,
        title: const Text('Filter workers', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700))),
      body: SafeArea(child: ListView(padding: const EdgeInsets.all(16), children: [
        _section('Services', [
          const Text('Match any selected service.', style: _hint),
          if (_categoryLoading) const LoadingList(rows: 1) else ...[
            if (_categoryError != null) _retry(_categoryError!, 'Retry categories', 'filter-categories-retry', _loadCategories),
            if (_categoryOptions.isEmpty) ...[
              const Text('No active services in the catalog. Leave this selection empty to include all services.', style: _hint),
              TextButton(key: const Key('filter-categories-reload'), onPressed: _loadCategories, child: const Text('Reload services')),
            ],
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final item in _categoryOptions) FilterChip(
                key: Key('filter-category-${item.category.name}'),
                avatar: Icon(jobCategoryIcon(item.category), size: 18, color: AppTheme.brandBlue),
                label: Text(_categoryLabel(item), textDirection: contentDirection(_categoryLabel(item)), style: const TextStyle(fontSize: 12)),
                selected: _filter.categories.contains(item.category),
                onSelected: (_) => setState(() {
                  final selected = {..._filter.categories};
                  selected.contains(item.category) ? selected.remove(item.category) : selected.add(item.category);
                  _filter = _filter.copyWith(categories: selected);
                }),
                materialTapTargetSize: MaterialTapTargetSize.padded,
              ),
              // Keep a previously selected deactivated service removable.
              for (final category in _filter.categories.where((category) => !_categoryOptions.any((item) => item.category == category)))
                InputChip(key: Key('filter-inactive-category-${category.name}'), label: Text('${jobCategoryLabel(category)} (unlisted)'),
                  onDeleted: () => setState(() { _filter = _filter.copyWith(categories: _filter.categories.where((item) => item != category)); })),
            ]),
          ],
        ]),
        _section('Price range', [
          Text('${_money(_filter.minPrice)} – ${_filter.maxPrice == null ? 'Any maximum' : _money(_filter.maxPrice!)}',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.brandBlue)),
          const Text('Matches overlapping worker price ranges. Prices not provided are excluded only when you set a limit.', style: _hint),
          RangeSlider(key: const Key('filter-price-slider'), min: 0, max: _priceCeiling, divisions: 100,
            activeColor: AppTheme.brandBlue, inactiveColor: AppTheme.borderGray,
            values: RangeValues(_filter.minPrice, _filter.maxPrice ?? _priceCeiling),
            labels: RangeLabels(_money(_filter.minPrice), _filter.maxPrice == null ? 'Any maximum' : _money(_filter.maxPrice!)),
            onChanged: (range) => setState(() { _filter = _filter.copyWith(minPrice: range.start,
              maxPrice: range.end, clearMaxPrice: range.end == _priceCeiling); })),
        ]),
        _section('Distance', [
          SwitchListTile(key: const Key('filter-distance-toggle'), contentPadding: EdgeInsets.zero,
            title: const Text('Use a distance limit', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            value: _filter.maxDistanceKm != null,
            onChanged: widget.location == null ? null : (enabled) => setState(() {
              _filter = _filter.copyWith(maxDistanceKm: enabled ? 10 : null, clearDistance: !enabled);
            })),
          Text(widget.location == null ? 'Location unavailable. Distance is not applied; no GPS is requested on this page.' :
            _filter.maxDistanceKm == null ? 'All distances. Workers without a location remain included.' :
            'Within ${_filter.maxDistanceKm!.round()} km. Workers without a location are excluded.', style: _hint),
          Slider(key: const Key('filter-distance-slider'), min: 1, max: 50, divisions: 49,
            value: _filter.maxDistanceKm ?? 10,
            label: '${(_filter.maxDistanceKm ?? 10).round()} km', activeColor: AppTheme.brandBlue,
            inactiveColor: AppTheme.borderGray,
            onChanged: widget.location == null || _filter.maxDistanceKm == null ? null :
              (value) => setState(() { _filter = _filter.copyWith(maxDistanceKm: value); })),
        ]),
        _section('Minimum rating', [
          Wrap(spacing: 2, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
            ChoiceChip(key: const Key('filter-rating-any'), label: const Text('Any', style: TextStyle(fontSize: 12)),
              selected: _filter.minimumRating == 0, onSelected: (_) => setState(() { _filter = _filter.copyWith(minimumRating: 0); })),
            for (var stars = 1; stars <= 5; stars++) IconButton(key: Key('filter-rating-$stars'),
              tooltip: 'At least $stars ${stars == 1 ? 'star' : 'stars'}',
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44), padding: const EdgeInsets.all(10),
              icon: Icon(stars <= _filter.minimumRating ? Icons.star : Icons.star_border,
                color: stars <= _filter.minimumRating ? AppTheme.ctaOrange : AppTheme.textMuted, size: 24),
              onPressed: () => setState(() { _filter = _filter.copyWith(minimumRating: stars.toDouble()); })),
          ]),
          Text(_filter.minimumRating == 0 ? 'Any rating' : 'At least ${_filter.minimumRating.toInt()} stars', style: _hint),
        ]),
        _section('Annual rank', [
          const Text('Based on completed jobs in the last 365 days, not lifetime jobs. Match any selected tier.', style: _hint),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final rank in WorkerRank.tiers) FilterChip(key: Key('filter-rank-${rank.name}'),
              avatar: RankEmblem(rank: rank, size: 22),
              label: Text(rank.name, style: const TextStyle(fontSize: 12)),
              selected: _filter.ranks.contains(rank.name), onSelected: (_) => _toggleRank(rank),
              materialTapTargetSize: MaterialTapTargetSize.padded),
          ]),
          if (_filter.ranks.isNotEmpty) ...[
            if (_rankLoading) const Padding(padding: EdgeInsets.symmetric(vertical: 8),
              child: LinearProgressIndicator(color: AppTheme.brandBlue)),
            if (_rankLoading) const Text('Calculating annual ranks…', style: _hint),
            if (_rankError != null) _retry(_rankError!, 'Retry ranks', 'filter-ranks-retry', _loadRanks),
            if (!_rankLoading && _rankError == null)
              TextButton(key: const Key('filter-ranks-refresh'), onPressed: _loadRanks, child: const Text('Refresh annual ranks')),
          ],
        ]),
        _section('Availability', [
          SwitchListTile(key: const Key('filter-availability-toggle'), contentPadding: EdgeInsets.zero,
            title: const Text('Available now only', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            subtitle: const Text('Based on each worker’s current availability setting.', style: _hint),
            value: _filter.onlyAvailable, onChanged: (value) => setState(() { _filter = _filter.copyWith(onlyAvailable: value); })),
        ]),
        _languageSection(),
        if (widget.query.trim().isNotEmpty)
          const Padding(padding: EdgeInsets.only(bottom: 16), child: Text('Your current name search also applies to this count.', style: _hint)),
      ])),
      bottomNavigationBar: SafeArea(top: false, child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: const BoxDecoration(color: AppTheme.surfaceWhite, border: Border(top: BorderSide(color: AppTheme.borderGray))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (count == 0 && !ranksUnavailable) const Padding(padding: EdgeInsets.only(bottom: 8),
            child: Text('No workers match — widen your filters', key: Key('filter-no-matches'),
              textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: AppTheme.textMuted))),
          Row(children: [
            OutlinedButton(key: const Key('filter-reset-button'), onPressed: _reset,
              style: OutlinedButton.styleFrom(minimumSize: const Size(80, 48)), child: const Text('Reset')),
            const SizedBox(width: 12),
            Expanded(child: ElevatedButton(key: const Key('filter-show-button'),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.ctaOrange, foregroundColor: AppTheme.surfaceWhite,
                minimumSize: const Size.fromHeight(48)),
              onPressed: ranksUnavailable ? null : () => Navigator.pop(context, _filter),
              child: Text(ranksUnavailable ? 'Waiting for ranks…' : 'Show $count ${count == 1 ? 'worker' : 'workers'}',
                textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)))),
          ]),
        ]),
      )),
    );
  }

  static const _hint = TextStyle(fontSize: 12, color: AppTheme.textMuted);
  Widget _section(String title, List<Widget> children) => Padding(padding: const EdgeInsets.only(bottom: 16),
    child: AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textDark)),
      const SizedBox(height: 10), ...children,
    ])));
  Widget _retry(String message, String label, String key, VoidCallback onRetry) => Column(
    crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(message, style: _hint), TextButton(key: Key(key), onPressed: onRetry, child: Text(label)),
    ]);

  Widget _languageSection() {
    final options = _filters.languageOptions([..._languageCatalog, ..._filter.languages], _pool);
    return _section('Spoken languages', [
      const Text('Match any selected language. Choices come from the catalog and worker profiles.', style: _hint),
      if (_languageLoading) const LoadingList(rows: 1) else ...[
        if (_languageError != null) _retry(_languageError!, 'Retry languages', 'filter-languages-retry', _loadLanguages),
        if (options.isEmpty) ...[
          const Text('No languages have been provided yet. Leave this empty to include every worker.', style: _hint),
          TextButton(key: const Key('filter-languages-reload'), onPressed: _loadLanguages, child: const Text('Reload languages')),
        ],
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final language in options) FilterChip(key: Key('filter-language-${language.code}'),
            label: Text(language.displayName, textDirection: contentDirection(language.displayName), style: const TextStyle(fontSize: 12)),
            selected: _filter.languages.contains(language),
            onSelected: (_) => setState(() {
              final selected = {..._filter.languages};
              selected.contains(language) ? selected.remove(language) : selected.add(language);
              _filter = _filter.copyWith(languages: selected);
            }), materialTapTargetSize: MaterialTapTargetSize.padded),
        ]),
      ],
    ]);
  }

  String _money(double value) => 'PKR ${intl.NumberFormat('#,##0', 'en_PK').format(value)}';
  String _categoryLabel(ServiceCategory item) => item.name == item.category.name ? jobCategoryLabel(item.category) : item.name;
}
