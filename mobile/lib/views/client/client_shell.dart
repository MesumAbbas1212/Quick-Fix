import 'package:flutter/material.dart';
import 'package:quickfix/core/theme/app_theme.dart';
import 'package:quickfix/models/user_model.dart';
import 'package:quickfix/services/auth_service.dart';
import 'package:quickfix/services/chat_service.dart';
import 'package:quickfix/services/job_service.dart';
import 'package:quickfix/services/profile_service.dart';
import 'package:quickfix/services/review_service.dart';
import 'package:quickfix/services/translation_service.dart';
import 'package:quickfix/views/chat/conversations_screen.dart';
import 'package:quickfix/views/client/client_home_screen.dart';
import 'package:quickfix/views/client/workers_screen.dart';
import 'package:quickfix/views/profile/profile_screen.dart';

/// Client shell: bottom navigation across Home / Workers / Messages / Profile.
/// Tabs are navigable by tapping the bottom bar OR swiping horizontally.
class ClientShell extends StatefulWidget {
  final UserModel user;
  final JobService? jobService;
  final ReviewService? reviewService;
  final TranslationService? translationService;
  final AuthService? authService;
  final ProfileService? profileService;
  final ChatService? chatService;

  const ClientShell({
    super.key,
    required this.user,
    this.jobService,
    this.reviewService,
    this.translationService,
    this.authService,
    this.profileService,
    this.chatService,
  });

  @override
  State<ClientShell> createState() => _ClientShellState();
}

class _ClientShellState extends State<ClientShell> {
  final _pageController = PageController();
  int _currentTab = 0;

  static const _tabCount = 4;

  @override
  void dispose() {
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
                  ClientHomeScreen(
                    user: widget.user,
                    jobService: widget.jobService,
                  ),
                ),
                _KeepAlive(
                  WorkersScreen(
                    user: widget.user,
                    profileService: widget.profileService,
                    reviewService: widget.reviewService,
                    translationService: widget.translationService,
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
