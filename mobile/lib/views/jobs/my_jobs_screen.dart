import 'package:flutter/material.dart';
import 'package:quickfix/core/theme/app_theme.dart';
import 'package:quickfix/models/job_model.dart';
import 'package:quickfix/services/job_service.dart';

class MyJobsScreen extends StatefulWidget {
  final String? workerId;
  final JobService? jobService;

  const MyJobsScreen({super.key, this.workerId, this.jobService});

  @override
  State<MyJobsScreen> createState() => _MyJobsScreenState();
}

class _MyJobsScreenState extends State<MyJobsScreen> {
  int _selectedFilter = 0;

  static const _filters = ['All', 'Active', 'Pending', 'Completed'];

  late final JobService _jobService = widget.jobService ?? JobService();

  List<JobModel> _applyFilter(List<JobModel> jobs) {
    switch (_selectedFilter) {
      case 1: // Active
        return jobs
            .where(
              (j) =>
                  j.status == JobStatus.inProgress ||
                  j.status == JobStatus.assigned,
            )
            .toList();
      case 2: // Pending
        return jobs.where((j) => j.status == JobStatus.open).toList();
      case 3: // Completed
        return jobs.where((j) => j.status == JobStatus.completed).toList();
      default:
        return jobs;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      body: _buildPhoneScreen(),
    );
  }

  Widget _buildPhoneScreen() {
    return SafeArea(
      child: Column(
        children: [
          _buildHeader(),
          _buildFilters(),
          Expanded(
            child: StreamBuilder<List<JobModel>>(
              stream: _jobService.watchWorkerJobs(widget.workerId ?? ''),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(
                    child: Text(
                      'Could not load your jobs',
                      style:
                          TextStyle(color: AppTheme.textMuted, fontSize: 13),
                    ),
                  );
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(
                    child: Text(
                      'No jobs found',
                      style:
                          TextStyle(color: AppTheme.textMuted, fontSize: 13),
                    ),
                  );
                }
                final jobs = _applyFilter(snapshot.data!);
                if (jobs.isEmpty) {
                  return const Center(
                    child: Text(
                      'No jobs found',
                      style:
                          TextStyle(color: AppTheme.textMuted, fontSize: 13),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(14),
                  itemCount: jobs.length,
                  itemBuilder: (context, index) {
                    final job = jobs[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildJobCard(job),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: AppTheme.brandBlue,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: const Row(
        children: [
          Icon(Icons.arrow_back, color: Colors.white, size: 20),
          SizedBox(width: 12),
          Text(
            'My Jobs',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      color: AppTheme.bgLight,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
      child: Row(
        children: List.generate(_filters.length, (index) {
          final isSelected = _selectedFilter == index;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _selectedFilter = index),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.ctaOrange
                      : AppTheme.surfaceWhite,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? AppTheme.ctaOrange
                        : AppTheme.borderGray,
                  ),
                ),
                child: Text(
                  _filters[index],
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : AppTheme.textDark,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildJobCard(JobModel job) {
    final statusColor = _statusColor(job.status);
    return Container(
      padding: const EdgeInsets.all(14),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _categoryIcon(job.category),
                  color: statusColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  job.title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textDark,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _statusLabel(job.status),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            job.address,
            style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildTimeline(
                  step1:
                      job.status != JobStatus.cancelled &&
                      job.status != JobStatus.open,
                  step2:
                      job.status == JobStatus.inProgress ||
                      job.status == JobStatus.completed,
                  step3: job.status == JobStatus.completed,
                ),
              ),
              Text(
                'PKR ${_formatBudget(job.budgetMax)}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textRed,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimeline({
    required bool step1,
    required bool step2,
    required bool step3,
  }) {
    return Row(
      children: List.generate(3, (index) {
        final done = [step1, step2, step3][index];
        return Expanded(
          child: Row(
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: done ? AppTheme.ctaOrange : AppTheme.borderGray,
                  shape: BoxShape.circle,
                ),
                child: done
                    ? const Icon(Icons.check, size: 10, color: Colors.white)
                    : null,
              ),
              if (index < 2)
                Container(
                  height: 2,
                  color: [step1, step2][index]
                      ? AppTheme.ctaOrange
                      : AppTheme.borderGray,
                ),
            ],
          ),
        );
      }),
    );
  }

  Color _statusColor(JobStatus status) {
    switch (status) {
      case JobStatus.open:
        return AppTheme.brandBlue;
      case JobStatus.assigned:
        return AppTheme.accentYellow;
      case JobStatus.inProgress:
        return AppTheme.ctaOrange;
      case JobStatus.completed:
        return const Color(0xFF10B981);
      case JobStatus.cancelled:
        return AppTheme.textRed;
    }
  }

  String _statusLabel(JobStatus status) {
    switch (status) {
      case JobStatus.open:
        return 'OPEN';
      case JobStatus.assigned:
        return 'ASSIGNED';
      case JobStatus.inProgress:
        return 'IN PROGRESS';
      case JobStatus.completed:
        return 'COMPLETED';
      case JobStatus.cancelled:
        return 'CANCELLED';
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
      case JobCategory.painting:
        return Icons.format_paint;
      default:
        return Icons.handyman;
    }
  }

  String _formatBudget(double budget) {
    if (budget >= 1000) {
      final k = budget / 1000;
      return '${k == k.roundToDouble() ? k.toStringAsFixed(0) : k.toStringAsFixed(1)}k';
    }
    return budget.toStringAsFixed(0);
  }
}