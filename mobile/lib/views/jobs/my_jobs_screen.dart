import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:quickfix/core/theme/app_theme.dart';
import 'package:quickfix/models/job_model.dart';

class MyJobsScreen extends StatefulWidget {
  final bool isWorker;

  const MyJobsScreen({super.key, this.isWorker = true});

  @override
  State<MyJobsScreen> createState() => _MyJobsScreenState();
}

class _MyJobsScreenState extends State<MyJobsScreen> {
  int _selectedFilter = 0;

  static const _filters = ['All', 'Active', 'Pending', 'Completed'];

  // Sample jobs for status tracking UI
  final List<JobModel> _jobs = [
    JobModel(
      id: 'j1',
      userId: 'u1',
      workerId: 'w1',
      title: 'AC Repair',
      description: 'Split AC not cooling daily due to gas leak',
      category: JobCategory.applianceRepair,
      address: 'Model Town, Lahore',
      location: const GeoPoint(31.5204, 74.3587),
      budgetMin: 2000,
      budgetMax: 3500,
      preferredDate: DateTime.now(),
      status: JobStatus.inProgress,
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
      updatedAt: DateTime.now(),
      assignedAt: DateTime.now().subtract(const Duration(days: 2)),
    ),
    JobModel(
      id: 'j2',
      userId: 'u2',
      workerId: 'w1',
      title: 'Fan Install',
      description: 'Ceiling fan installation',
      category: JobCategory.electrical,
      address: 'Gulberg, Lahore',
      location: const GeoPoint(31.5204, 74.3587),
      budgetMin: 1000,
      budgetMax: 2000,
      preferredDate: DateTime.now().add(const Duration(days: 2)),
      status: JobStatus.assigned,
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      updatedAt: DateTime.now(),
      assignedAt: DateTime.now(),
    ),
    JobModel(
      id: 'j3',
      userId: 'u3',
      workerId: 'w1',
      title: 'Sink Pipe',
      description: 'Kitchen sink pipe leak',
      category: JobCategory.plumbing,
      address: 'DHA Phase 5, Lahore',
      location: const GeoPoint(31.5204, 74.3587),
      budgetMin: 1500,
      budgetMax: 2800,
      preferredDate: DateTime.now().subtract(const Duration(days: 10)),
      status: JobStatus.completed,
      rating: 4.8,
      createdAt: DateTime.now().subtract(const Duration(days: 15)),
      updatedAt: DateTime.now(),
      completedAt: DateTime.now().subtract(const Duration(days: 8)),
    ),
  ];

  List<JobModel> get _filteredJobs {
    switch (_selectedFilter) {
      case 1: // Active
        return _jobs
            .where(
              (j) =>
                  j.status == JobStatus.inProgress ||
                  j.status == JobStatus.assigned,
            )
            .toList();
      case 2: // Pending
        return _jobs.where((j) => j.status == JobStatus.open).toList();
      case 3: // Completed
        return _jobs.where((j) => j.status == JobStatus.completed).toList();
      default:
        return _jobs;
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
            child: _filteredJobs.isEmpty
                ? const Center(
                    child: Text(
                      'No jobs found',
                      style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(14),
                    itemCount: _filteredJobs.length,
                    itemBuilder: (context, index) {
                      final job = _filteredJobs[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildJobCard(job),
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
