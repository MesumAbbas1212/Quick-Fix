import 'package:flutter/material.dart';
import 'package:quickfix/core/theme/app_theme.dart';
import 'package:quickfix/core/widgets/job_image_thumb.dart';
import 'package:quickfix/models/job_model.dart';
import 'package:quickfix/models/user_model.dart';
import 'package:quickfix/models/worker_profile.dart';
import 'package:quickfix/services/auth_service.dart';
import 'package:quickfix/services/job_service.dart';
import 'package:quickfix/services/local_image_store.dart';
import 'package:quickfix/services/profile_service.dart';
import 'package:quickfix/views/jobs/job_request_screen.dart';

class WorkerDashboardScreen extends StatefulWidget {
  final UserModel user;
  final WorkerProfile? workerProfile;
  final JobService? jobService;
  final ProfileService? profileService;
  final AuthService? authService;
  final LocalImageStore? imageStore;

  const WorkerDashboardScreen({
    super.key,
    required this.user,
    this.workerProfile,
    this.jobService,
    this.profileService,
    this.authService,
    this.imageStore,
  });

  @override
  State<WorkerDashboardScreen> createState() => _WorkerDashboardScreenState();
}

class _WorkerDashboardScreenState extends State<WorkerDashboardScreen> {
  late bool _isAvailable = widget.workerProfile?.isAvailable ?? true;
  late final JobService _jobService = widget.jobService ?? JobService();
  late final ProfileService _profileService =
      widget.profileService ?? ProfileService();

  Future<void> _toggleAvailability() async {
    final next = !_isAvailable;
    setState(() => _isAvailable = next);
    try {
      await _profileService.setAvailability(widget.user.uid, next);
    } catch (_) {
      // Keep UI in sync even if the write fails quietly.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _buildJobs(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      color: AppTheme.brandBlue,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Jobs',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
              GestureDetector(
                onTap: _toggleAvailability,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _isAvailable
                        ? AppTheme.successGreen
                        : AppTheme.textMuted,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _isAvailable ? 'Available' : 'Busy',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'Hi, $_firstName!',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFFBFDBFE),
            ),
          ),
        ],
      ),
    );
  }

  String get _firstName {
    final name = (widget.workerProfile?.fullName ?? widget.user.fullName)
        .trim();
    if (name.isEmpty) return 'there';
    return name.split(RegExp(r'\s+')).first;
  }

  Widget _buildJobs() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Suggested Jobs For You',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textDark,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<JobModel>>(
            stream: _jobService.watchOpenJobs(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Center(
                  child: Text(
                    'Could not load jobs',
                    style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                  ),
                );
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(
                  child: Text(
                    'No open jobs right now',
                    style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.all(14),
                itemCount: snapshot.data!.length,
                itemBuilder: (context, index) {
                  final job = snapshot.data![index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildSuggestionCard(job),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSuggestionCard(JobModel job) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => JobRequestScreen(
            job: job,
            client: null,
            workerId: widget.user.uid,
            jobService: _jobService,
            authService: widget.authService,
            // Single pop only - JobRequestScreen no longer pops itself
            // when a callback is supplied (double-pop caused a black screen).
            onAccept: () => Navigator.pop(context),
            onDecline: () => Navigator.pop(context),
          ),
        ),
      ),
      child: Container(
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
          children: [
            JobImageThumb(
              image: job.images.firstOrNull,
              fallbackIcon: _categoryIcon(job.category),
              fallbackColor: _categoryColor(job.category),
              imageStore: widget.imageStore,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    job.title,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textDark,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    job.address,
                    style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          'PKR ${_formatBudget(job.budgetMin)}-'
                          '${_formatBudget(job.budgetMax)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textDark,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.brandBlue.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _categoryLabel(job.category),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.brandBlue,
                          ),
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

  String _formatBudget(double budget) {
    if (budget >= 1000) {
      final k = budget / 1000;
      return '${k == k.roundToDouble() ? k.toStringAsFixed(0) : k.toStringAsFixed(1)}k';
    }
    return budget.toStringAsFixed(0);
  }

  String _categoryLabel(JobCategory cat) {
    return cat.name[0].toUpperCase() +
        cat.name.substring(1).replaceAll('_', ' ');
  }

  Color _categoryColor(JobCategory cat) {
    switch (cat) {
      case JobCategory.plumbing:
        return AppTheme.brandBlue;
      case JobCategory.electrical:
        return AppTheme.accentYellow;
      case JobCategory.applianceRepair:
        return const Color(0xFFEC4899);
      case JobCategory.cleaning:
        return const Color(0xFF10B981);
      case JobCategory.carpentry:
        return const Color(0xFF8B5CF6);
      default:
        return AppTheme.textMuted;
    }
  }

  IconData _categoryIcon(JobCategory cat) {
    switch (cat) {
      case JobCategory.plumbing:
        return Icons.water_drop;
      case JobCategory.electrical:
        return Icons.flash_on;
      case JobCategory.applianceRepair:
        return Icons.ac_unit;
      case JobCategory.cleaning:
        return Icons.cleaning_services;
      case JobCategory.carpentry:
        return Icons.chair;
      default:
        return Icons.handyman;
    }
  }
}