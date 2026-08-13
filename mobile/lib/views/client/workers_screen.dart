import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:quickfix/core/theme/app_theme.dart';
import 'package:quickfix/core/widgets/user_avatar.dart';
import 'package:quickfix/models/job_model.dart';
import 'package:quickfix/models/user_model.dart';
import 'package:quickfix/models/worker_profile.dart';
import 'package:quickfix/services/location_service.dart';
import 'package:quickfix/services/profile_service.dart';
import 'package:quickfix/services/review_service.dart';
import 'package:quickfix/services/translation_service.dart';
import 'package:quickfix/views/client/worker_detail_screen.dart';

/// Browse workers: profession filter, distance from the client's location
/// and a tap-through to the worker detail screen.
class WorkersScreen extends StatefulWidget {
  final UserModel user;
  final ProfileService? profileService;
  final LocationService? locationService;
  final ReviewService? reviewService;
  final TranslationService? translationService;

  const WorkersScreen({
    super.key,
    required this.user,
    this.profileService,
    this.locationService,
    this.reviewService,
    this.translationService,
  });

  @override
  State<WorkersScreen> createState() => _WorkersScreenState();
}

class _WorkersScreenState extends State<WorkersScreen> {
  late final ProfileService _profileService =
      widget.profileService ?? ProfileService();
  late final LocationService _locationService =
      widget.locationService ?? LocationService();

  JobCategory? _selectedProfession;
  Future<List<WorkerProfile>>? _workersFuture;
  GeoPoint? _userLocation;
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _workersFuture = _loadWorkers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<List<WorkerProfile>> _loadWorkers() async {
    GeoPoint? location;
    try {
      location = await _locationService.getCurrentLocation();
    } catch (_) {
      location = null;
    }
    if (!mounted) return [];
    setState(() => _userLocation = location);
    return _profileService.searchWorkers(
      profession: _selectedProfession,
      fromLocation: location,
      maxDistanceKm: location != null ? 25 : null,
    );
  }

  void _onProfessionChanged(JobCategory? value) {
    setState(() {
      _selectedProfession = value;
      _workersFuture = _loadWorkers();
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
            Expanded(
              child: FutureBuilder<List<WorkerProfile>>(
                future: _workersFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.brandBlue,
                      ),
                    );
                  }
                  final workers = _filterByName(snapshot.data!);
                  if (snapshot.hasError || workers.isEmpty) {
                    return const Center(
                      child: Text(
                        'No workers found',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.all(14),
                    itemCount: workers.length,
                    itemBuilder: (context, index) {
                      final worker = workers[index];
                      return _buildWorkerCard(worker);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<WorkerProfile> _filterByName(List<WorkerProfile> workers) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return workers;
    return workers
        .where((w) => w.fullName.toLowerCase().contains(q))
        .toList();
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      color: AppTheme.brandBlue,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Workers',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Find skilled professionals near you.',
            style: TextStyle(fontSize: 12, color: Color(0xFF93C5FD)),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
      child: TextField(
        controller: _searchController,
        onChanged: (value) => setState(() => _query = value),
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
          const Text(
            'Nearby Workers',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppTheme.textDark,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.surfaceWhite,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.borderGray),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<JobCategory?>(
                key: const Key('profession-filter'),
                value: _selectedProfession,
                hint: const Text(
                  'All Services',
                  style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
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
          ),
        ],
      ),
    );
  }

  Widget _buildWorkerCard(WorkerProfile worker) {
    final distance = _distanceKm(worker.location, _userLocation);

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => WorkerDetailScreen(
            worker: worker,
            myId: widget.user.uid,
            reviewService: widget.reviewService,
            translationService: widget.translationService,
          ),
        ),
      ),
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
          border: Border.all(color: AppTheme.borderGray),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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

  double? _distanceKm(GeoPoint? workerLocation, GeoPoint? userLocation) {
    if (workerLocation == null || userLocation == null) return null;
    return Geolocator.distanceBetween(
          userLocation.latitude,
          userLocation.longitude,
          workerLocation.latitude,
          workerLocation.longitude,
        ) /
        1000;
  }

  String _professionLabel(JobCategory cat) {
    return cat.name[0].toUpperCase() +
        cat.name.substring(1).replaceAll(RegExp(r'(?<=[a-z])([A-Z])'), r' $1');
  }
}
