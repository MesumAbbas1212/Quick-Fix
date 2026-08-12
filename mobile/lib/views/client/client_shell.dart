import 'package:flutter/material.dart';
import 'package:quickfix/core/theme/app_theme.dart';
import 'package:quickfix/models/user_model.dart';
import 'package:quickfix/services/auth_service.dart';
import 'package:quickfix/services/job_service.dart';
import 'package:quickfix/services/profile_service.dart';
import 'package:quickfix/services/review_service.dart';
import 'package:quickfix/services/translation_service.dart';
import 'package:quickfix/views/chat/chat_screen.dart';
import 'package:quickfix/views/client/client_home_screen.dart';
import 'package:quickfix/views/client/workers_screen.dart';
import 'package:quickfix/views/profile/profile_screen.dart';

/// Client shell: bottom navigation across Home / Workers / Messages / Profile.
class ClientShell extends StatefulWidget {
  final UserModel user;
  final JobService? jobService;
  final ReviewService? reviewService;
  final TranslationService? translationService;
  final AuthService? authService;
  final ProfileService? profileService;

  const ClientShell({
    super.key,
    required this.user,
    this.jobService,
    this.reviewService,
    this.translationService,
    this.authService,
    this.profileService,
  });

  @override
  State<ClientShell> createState() => _ClientShellState();
}

class _ClientShellState extends State<ClientShell> {
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
                ClientHomeScreen(user: widget.user, jobService: widget.jobService),
                WorkersScreen(
                  user: widget.user,
                  profileService: widget.profileService,
                  reviewService: widget.reviewService,
                  translationService: widget.translationService,
                ),
                ChatScreen(
                  peerName: 'Sarah Ahmed',
                  peerId: 'worker2',
                  myId: widget.user.uid,
                ),
                ProfileScreen(
                  user: widget.user,
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
      (Icons.home, 'Home'),
      (Icons.group_outlined, 'Workers'),
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
                            ? AppTheme.brandBlue
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
                              ? AppTheme.brandBlue
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