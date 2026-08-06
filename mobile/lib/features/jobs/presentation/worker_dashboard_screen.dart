import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quickfix/core/theme/app_theme.dart';
import 'package:quickfix/features/chat/presentation/chat_screen.dart';
import 'package:quickfix/features/jobs/presentation/job_request_screen.dart';
import 'package:quickfix/features/jobs/presentation/my_jobs_screen.dart';
import 'package:quickfix/features/profile/presentation/profile_screen.dart';
import 'package:quickfix/shared/models/job_model.dart';
import 'package:quickfix/shared/models/user_model.dart';

class WorkerDashboardScreen extends StatefulWidget {
  final UserModel user;

  const WorkerDashboardScreen({super.key, required this.user});

  @override
  State<WorkerDashboardScreen> createState() => _WorkerDashboardScreenState();
}

class _WorkerDashboardScreenState extends State<WorkerDashboardScreen> {
  int _currentTab = 0;
  bool _isAvailable = true;

  // Sample suggested jobs for worker
  final List<JobModel> _suggestedJobs = [
    JobModel(
      id: 'wj1',
      userId: 'u1',
      title: 'AC Not Cooling',
      description: 'Split AC stopped cooling, needs service at home',
      category: JobCategory.applianceRepair,
      address: 'Model Town, Lahore',
      location: GeoPoint(31.5204, 74.3587),
      budgetMin: 2000,
      budgetMax: 3500,
      preferredDate: DateTime.now().add(const Duration(days: 1)),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
    JobModel(
      id: 'wj2',
      userId: 'u2',
      title: 'Ceiling Fan Install',
      description: 'New ceiling fan installation in bedroom',
      category: JobCategory.electrical,
      address: 'Gulberg, Lahore',
      location: GeoPoint(31.5204, 74.3587),
      budgetMin: 1000,
      budgetMax: 2000,
      preferredDate: DateTime.now().add(const Duration(days: 1)),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
    JobModel(
      id: 'wj3',
      userId: 'u3',
      title: 'Kitchen Sink Pipe',
      description: 'Kitchen sink pipe leaking under counter',
      category: JobCategory.plumbing,
      address: 'DHA Phase 5, Lahore',
      location: GeoPoint(31.5204, 74.3587),
      budgetMin: 1500,
      budgetMax: 2800,
      preferredDate: DateTime.now().add(const Duration(days: 2)),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      body: _PhoneFrame(child: _buildPhoneScreen()),
    );
  }

  Widget _buildPhoneScreen() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bgLight,
        borderRadius: BorderRadius.circular(38),
      ),
      child: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: IndexedStack(
                index: _currentTab,
                children: [
                  _buildJobs(),
                  const MyJobsScreen(),
                  ChatScreen(
                    peerName: 'Sarah Ahmed',
                    peerId: 'user2',
                    myId: widget.user.uid,
                  ),
                  ProfileScreen(user: widget.user),
                ],
              ),
            ),
            _buildBottomNav(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: AppTheme.brandBlue,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          const Text(
            'Hi, John!',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _isAvailable
                  ? const Color(0xFF10B981)
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
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
              GestureDetector(
                onTap: () => setState(() => _isAvailable = !_isAvailable),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _isAvailable
                        ? AppTheme.ctaOrange.withValues(alpha: 0.1)
                        : AppTheme.borderGray.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isAvailable
                            ? Icons.toggle_on
                            : Icons.toggle_off,
                        size: 16,
                        color: _isAvailable
                            ? AppTheme.ctaOrange
                            : AppTheme.textMuted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Availability',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: _isAvailable
                              ? AppTheme.ctaOrange
                              : AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(14),
            itemCount: _suggestedJobs.length,
            itemBuilder: (context, index) {
              final job = _suggestedJobs[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildSuggestionCard(job, index),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSuggestionCard(JobModel job, int index) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => JobRequestScreen(
            job: job,
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
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _categoryColor(job.category).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _categoryIcon(job.category),
                color: _categoryColor(job.category),
                size: 22,
              ),
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
                    style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          'PKR ${_formatBudget(job.budgetMax)}'
                          ' • ${index == 0 ? 3 : index == 1 ? 8 : 5} km away',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 10),
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
                          '${90 - index * 5}% match',
                          style: const TextStyle(
                            fontSize: 9,
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

  Widget _buildBottomNav() {
    final items = [
      (Icons.home, 'Home'),
      (Icons.work_outline, 'My Jobs'),
      (Icons.message_outlined, 'Messages'),
      (Icons.person_outline, 'Profile'),
    ];
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceWhite,
        border: Border(top: BorderSide(color: AppTheme.borderGray)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: List.generate(items.length, (index) {
            final isSelected = _currentTab == index;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _currentTab = index),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Column(
                    children: [
                      Icon(
                        items[index].$1,
                        size: 20,
                        color: isSelected
                            ? AppTheme.ctaOrange
                            : AppTheme.textMuted,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        items[index].$2,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: isSelected
                              ? AppTheme.ctaOrange
                              : AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
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

class _PhoneFrame extends StatelessWidget {
  final Widget child;

  const _PhoneFrame({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 340,
      height: 680,
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(48),
        border: Border.all(color: const Color(0xFF1E293B), width: 4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 40,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: 16,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: 112,
                height: 16,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF334155), width: 1),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF334155), width: 1),
                      ),
                    ),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFF1E1B4B),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 3,
            right: 3,
            bottom: 3,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(38),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}