import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quickfix/core/theme/app_theme.dart';
import 'package:quickfix/features/jobs/presentation/job_request_screen.dart';
import 'package:quickfix/shared/models/job_model.dart';

class FindJobsScreen extends StatefulWidget {
  final String? initialCategory;

  const FindJobsScreen({super.key, this.initialCategory});

  @override
  State<FindJobsScreen> createState() => _FindJobsScreenState();
}

class _FindJobsScreenState extends State<FindJobsScreen> {
  int _currentTab = 0;
  JobCategory? _selectedCategory;

  // Sample data for UI preview
  final List<JobModel> _sampleJobs = [
    JobModel(
      id: '1',
      userId: 'u1',
      title: 'Leaky Faucet Repair',
      description: 'Kitchen faucet is leaking constantly',
      category: JobCategory.plumbing,
      address: 'Model Town, Lahore',
      location: const GeoPoint(31.5204, 74.3587),
      budgetMin: 1500,
      budgetMax: 2000,
      preferredDate: DateTime.now().add(const Duration(days: 1)),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
    JobModel(
      id: '2',
      userId: 'u2',
      title: 'Broken Sofa Fix',
      description: 'Sofa leg broken and cushion needs repair',
      category: JobCategory.carpentry,
      address: 'Gulberg, Lahore',
      location: GeoPoint(31.5204, 74.3587),
      budgetMin: 2500,
      budgetMax: 3500,
      preferredDate: DateTime.now().add(const Duration(days: 2)),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
    JobModel(
      id: '3',
      userId: 'u3',
      title: 'Wall Crack Repair',
      description: 'Wall has cracks that need filling',
      category: JobCategory.painting,
      address: 'DHA Phase 5, Lahore',
      location: GeoPoint(31.5204, 74.3587),
      budgetMin: 1500,
      budgetMax: 2100,
      preferredDate: DateTime.now().add(const Duration(days: 3)),
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
                  _buildFindJobs(),
                  const Center(child: Text('My Jobs')),
                  const Center(child: Text('Messages')),
                  const Center(child: Text('Profile')),
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
          const Icon(
            Icons.arrow_back,
            color: Colors.white,
            size: 20,
            weight: 900,
          ),
          const SizedBox(width: 12),
          const Text(
            'Find Jobs',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white, size: 22),
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildFindJobs() {
    return Column(
      children: [
        _buildCategoryChips(),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(14),
            itemCount: _sampleJobs.length,
            itemBuilder: (context, index) {
              final job = _sampleJobs[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildJobCard(job, index),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryChips() {
    final categories = <JobCategory?>[
      null, ...JobCategory.values,
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: categories.map((cat) {
          final label = cat == null ? 'All' : _formatCategory(cat);
          final isSelected = _selectedCategory == cat;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _selectedCategory = cat),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.ctaOrange : AppTheme.surfaceWhite,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? AppTheme.ctaOrange : AppTheme.borderGray,
                  ),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isSelected ? Colors.white : AppTheme.textDark,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildJobCard(JobModel job, int index) {
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
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: _categoryColor(job.category).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.borderGray),
              ),
              child: Icon(
                _categoryIcon(job.category),
                color: _categoryColor(job.category),
                size: 32,
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
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        size: 12,
                        color: AppTheme.textRed,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        'PKR ${_formatBudget(job.budgetMax)}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textRed,
                        ),
                      ),
                      Text(
                        ' - ${index == 1 ? 2 : index == 2 ? 12 : 15} km away',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.textMuted,
                        ),
                      ),
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

  Widget _buildBottomNav() {
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
          children: [
            _buildNavItem(0, Icons.home, 'Home'),
            _buildNavItem(1, Icons.work_outline, 'My Jobs'),
            _buildNavItem(2, Icons.message_outlined, 'Messages'),
            _buildNavItem(3, Icons.person_outline, 'Profile'),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _currentTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _currentTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected ? AppTheme.ctaOrange : AppTheme.textMuted,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? AppTheme.ctaOrange : AppTheme.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatCategory(JobCategory cat) {
    return cat.name[0].toUpperCase() + cat.name.substring(1).replaceAll('_', ' ');
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
      case JobCategory.carpentry:
        return const Color(0xFF8B5CF6);
      case JobCategory.painting:
        return AppTheme.ctaOrange;
      case JobCategory.cleaning:
        return const Color(0xFF10B981);
      case JobCategory.applianceRepair:
        return const Color(0xFFEC4899);
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
      case JobCategory.carpentry:
        return Icons.chair;
      case JobCategory.painting:
        return Icons.format_paint;
      case JobCategory.cleaning:
        return Icons.cleaning_services;
      case JobCategory.applianceRepair:
        return Icons.settings;
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