import 'package:flutter/material.dart';
import 'package:quickfix/core/theme/app_theme.dart';
import 'package:quickfix/core/widgets/job_image_thumb.dart';
import 'package:quickfix/core/widgets/job_category_icons.dart';
import 'package:quickfix/models/job_model.dart';
import 'package:quickfix/models/user_model.dart';
import 'package:quickfix/services/job_service.dart';
import 'package:quickfix/services/job_request_service.dart';
import 'package:quickfix/services/profile_service.dart';
import 'package:quickfix/services/location_service.dart';
import 'package:quickfix/services/review_service.dart';
import 'package:quickfix/services/translation_service.dart';
import 'package:quickfix/services/local_image_store.dart';
import 'package:quickfix/views/client/category_grid_screen.dart';
import 'package:quickfix/views/client/client_job_detail_screen.dart';
import 'package:quickfix/views/jobs/post_job_screen.dart';

/// Client dashboard: greeting, Post a Job hero and the client's posted jobs.
class ClientHomeScreen extends StatefulWidget {
  final UserModel user;
  final JobService? jobService;
  final LocalImageStore? imageStore;
  final ProfileService? profileService;
  final LocationService? locationService;
  final JobRequestService? jobRequestService;
  final ReviewService? reviewService;
  final TranslationService? translationService;

  const ClientHomeScreen({
    super.key,
    required this.user,
    this.jobService,
    this.imageStore,
    this.profileService,
    this.locationService,
    this.jobRequestService,
    this.reviewService,
    this.translationService,
  });

  @override
  State<ClientHomeScreen> createState() => _ClientHomeScreenState();
}

class _ClientHomeScreenState extends State<ClientHomeScreen> {
  late final JobService _jobService = widget.jobService ?? JobService();

  String get _firstName {
    final name = widget.user.fullName.trim();
    if (name.isEmpty) return 'there';
    final parts = name.split(RegExp(r'\s+'));
    return parts.first;
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
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(14),
                children: [
                  _buildHeroCard(),
                  const SizedBox(height: 14),
                  _buildBrowseCategoryCard(),
                  const SizedBox(height: 18),
                  const Text(
                    'My Posted Jobs',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textDark,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildPostedJobs(),
                ],
              ),
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
          const Text(
            'Dashboard',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFFBFDBFE),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Hi, $_firstName!',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Find the right worker for your job.',
            style: TextStyle(fontSize: 12, color: Color(0xFF93C5FD)),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.brandBlue, AppTheme.accentYellow],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.brandBlue.withValues(alpha: 0.35),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.add_circle, color: Colors.white, size: 22),
              SizedBox(width: 8),
              Text(
                'Post a Job',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Describe your task and get offers from verified workers.',
            style: TextStyle(fontSize: 12, color: Colors.white70),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 42,
            child: ElevatedButton.icon(
              key: const Key('post-job-cta'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => PostJobScreen(userId: widget.user.uid),
                ),
              ),
              icon: const Icon(Icons.edit, size: 16),
              label: const Text(
                'Create Job',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppTheme.brandBlue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// "My sink leaks" → the right tradesmen: entry into the category grid.
  Widget _buildBrowseCategoryCard() {
    return Material(
      color: AppTheme.surfaceWhite,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        key: const Key('browse-category-entry'),
        borderRadius: BorderRadius.circular(20),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => CategoryGridScreen(
              user: widget.user,
              profileService: widget.profileService,
              locationService: widget.locationService,
              jobService: widget.jobService,
              reviewService: widget.reviewService,
              translationService: widget.translationService,
            ),
          ),
        ),
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
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppTheme.brandBlue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.grid_view_outlined,
                    size: 20, color: AppTheme.brandBlue),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Browse by category',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textDark,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Find the right worker for your problem',
                      style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, size: 20, color: AppTheme.textMuted),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPostedJobs() {
    return StreamBuilder<List<JobModel>>(
      stream: _jobService.watchUserJobs(widget.user.uid),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const _EmptyJobs(
            icon: Icons.error_outline,
            message: 'Could not load your jobs.',
          );
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const _EmptyJobs(
            icon: Icons.work_off_outlined,
            message: 'No jobs posted yet',
          );
        }
        final jobs = snapshot.data!;
        return Column(children: jobs.map((job) => _buildJobCard(job)).toList());
      },
    );
  }

  Widget _buildJobCard(JobModel job) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              ClientJobDetailScreen(
                job: job,
                currentUserId: widget.user.uid,
                reviewerLanguage: widget.user.preferredLanguage,
                jobService: _jobService,
                jobRequestService: widget.jobRequestService,
                profileService: widget.profileService,
                imageStore: widget.imageStore,
              ),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
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
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textDark,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    job.address,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textMuted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          'PKR ${_formatBudget(job.budgetMin)}-${_formatBudget(job.budgetMax)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textDark,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _statusChip(job.status),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(JobStatus status) {
    final (color, label) = switch (status) {
      JobStatus.open => (AppTheme.brandBlue, 'Open'),
      JobStatus.assigned => (AppTheme.ctaOrange, 'Assigned'),
      JobStatus.inProgress => (AppTheme.accentYellow, 'In Progress'),
      JobStatus.completed => (AppTheme.successGreen, 'Completed'),
      JobStatus.cancelled => (AppTheme.dangerRed, 'Cancelled'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
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

  IconData _categoryIcon(JobCategory cat) => jobCategoryIcon(cat);
}

class _EmptyJobs extends StatelessWidget {
  final IconData icon;
  final String message;

  const _EmptyJobs({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32),
      decoration: BoxDecoration(
        color: AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderGray),
      ),
      child: Column(
        children: [
          Icon(icon, size: 36, color: AppTheme.textMuted),
          const SizedBox(height: 10),
          Text(
            message,
            style: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
          ),
        ],
      ),
    );
  }
}
