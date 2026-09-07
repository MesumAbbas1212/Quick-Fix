import 'dart:async';

import 'package:flutter/material.dart';
import 'package:quickfix/core/theme/app_theme.dart';
import 'package:quickfix/models/user_model.dart';
import 'package:quickfix/models/worker_profile.dart';
import 'package:quickfix/services/auth_service.dart';
import 'package:quickfix/services/chat_service.dart';
import 'package:quickfix/services/job_service.dart';
import 'package:quickfix/services/local_image_store.dart';
import 'package:quickfix/services/profile_service.dart';
import 'package:quickfix/services/review_service.dart';
import 'package:quickfix/services/translation_service.dart';
import 'package:quickfix/views/chat/conversations_screen.dart';
import 'package:quickfix/views/jobs/my_jobs_screen.dart';
import 'package:quickfix/views/jobs/worker_dashboard_screen.dart';
import 'package:quickfix/views/profile/profile_screen.dart';

/// Worker shell: bottom navigation across Jobs / My Jobs / Messages / Profile.
/// Tabs are navigable by tapping the bottom bar OR swiping horizontally.
/// The worker profile is streamed live so availability edits persist and
/// propagate without re-login.
class WorkerShell extends StatefulWidget {
  final UserModel user;
  final WorkerProfile? workerProfile;
  final ReviewService? reviewService;
  final TranslationService? translationService;
  final AuthService? authService;
  final ProfileService? profileService;
  final JobService? jobService;
  final ChatService? chatService;

  const WorkerShell({
    super.key,
    required this.user,
    this.workerProfile,
    this.reviewService,
    this.translationService,
    this.authService,
    this.profileService,
    this.jobService,
    this.chatService,
  });

  @override
  State<WorkerShell> createState() => _WorkerShellState();
}

class _WorkerShellState extends State<WorkerShell> {
  final _pageController = PageController();
  int _currentTab = 0;
  StreamSubscription<WorkerProfile?>? _workerProfileSub;
  WorkerProfile? _workerProfile;

  static const _tabCount = 4;

  @override
  void initState() {
    super.initState();
    _workerProfile = widget.workerProfile;
    final profileService = widget.profileService;
    if (profileService != null) {
      _workerProfileSub =
          profileService.watchWorkerProfile(widget.user.uid).listen((profile) {
        if (!mounted) return;
        setState(() => _workerProfile = profile);
      });
    }
  }

  @override
  void dispose() {
    _workerProfileSub?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _onTap(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  void _onPageChanged(int index) {
    setState(() => _currentTab = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      body: Column(
        children: [
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: _onPageChanged,
              physics: const PageScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              children: [
                _KeepAlive(
                  WorkerDashboardScreen(
                    user: widget.user,
                    workerProfile: _workerProfile,
                    jobService: widget.jobService,
                    profileService: widget.profileService,
                    authService: widget.authService,
                    imageStore: const LocalImageStore(),
                  ),
                ),
                _KeepAlive(
                  MyJobsScreen(
                    workerId: widget.user.uid,
                    jobService: widget.jobService,
                    imageStore: const LocalImageStore(),
                  ),
                ),
                _KeepAlive(
                  ConversationsScreen(
                    user: widget.user,
                    chatService: widget.chatService,
                    authService: widget.authService,
                    profileService: widget.profileService,
                  ),
                ),
                _KeepAlive(
                  ProfileScreen(
                    user: widget.user,
                    workerProfile: _workerProfile,
                    reviewService: widget.reviewService,
                    translationService: widget.translationService,
                    authService: widget.authService,
                    profileService: widget.profileService,
                    jobService: widget.jobService,
                  ),
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
          children: List.generate(_tabCount, (index) {
            final isSelected = _currentTab == index;
            return Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _onTap(index),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
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

/// Keeps tab state alive inside the PageView so each screen keeps its
/// scroll position and streams when swiping between tabs.
class _KeepAlive extends StatefulWidget {
  final Widget child;

  const _KeepAlive(this.child);

  @override
  State<_KeepAlive> createState() => _KeepAliveState();
}

class _KeepAliveState extends State<_KeepAlive>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
