import 'package:flutter/material.dart';
import 'package:quickfix/core/theme/app_theme.dart';
import 'package:quickfix/models/user_model.dart';
import 'package:quickfix/models/worker_profile.dart';
import 'package:quickfix/services/auth_service.dart';
import 'package:quickfix/services/job_service.dart';
import 'package:quickfix/services/profile_service.dart';
import 'package:quickfix/services/review_service.dart';
import 'package:quickfix/services/translation_service.dart';
import 'package:quickfix/views/chat/chat_screen.dart';
import 'package:quickfix/views/jobs/my_jobs_screen.dart';
import 'package:quickfix/views/jobs/worker_dashboard_screen.dart';
import 'package:quickfix/views/profile/profile_screen.dart';

/// Worker shell: bottom navigation across Jobs / My Jobs / Messages / Profile.
class WorkerShell extends StatefulWidget {
  final UserModel user;
  final WorkerProfile? workerProfile;
  final ReviewService? reviewService;
  final TranslationService? translationService;
  final AuthService? authService;
  final ProfileService? profileService;
  final JobService? jobService;

  const WorkerShell({
    super.key,
    required this.user,
    this.workerProfile,
    this.reviewService,
    this.translationService,
    this.authService,
    this.profileService,
    this.jobService,
  });

  @override
  State<WorkerShell> createState() => _WorkerShellState();
}

class _WorkerShellState extends State<WorkerShell> {
  int _currentTab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      body: Column(
        children: [
          Expanded(
            child: IndexedStack(
              index: _currentTab,
              children: [
                WorkerDashboardScreen(
                  user: widget.user,
                  workerProfile: widget.workerProfile,
                  jobService: widget.jobService,
                ),
                MyJobsScreen(
                  workerId: widget.user.uid,
                  jobService: widget.jobService,
                ),
                ChatScreen(
                  peerName: 'Sarah Ahmed',
                  peerId: 'user2',
                  myId: widget.user.uid,
                ),
                ProfileScreen(
                  user: widget.user,
                  workerProfile: widget.workerProfile,
                  reviewService: widget.reviewService,
                  translationService: widget.translationService,
                  authService: widget.authService,
                  profileService: widget.profileService,
                ),
              ],
            ),
          ),
          _buildBottomNav(),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    final items = [
      (Icons.home, 'Jobs'),
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
        top: false,
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
                          fontSize: 12,
                          fontWeight: isSelected
                              ? FontWeight.w700
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
}
