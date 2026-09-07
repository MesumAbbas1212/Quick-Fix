import 'dart:async';

import 'package:flutter/material.dart';
import 'package:quickfix/controllers/auth_controller.dart';
import 'package:quickfix/core/theme/app_theme.dart';
import 'package:quickfix/core/widgets/review_list_tile.dart';
import 'package:quickfix/core/widgets/user_avatar.dart';
import 'package:quickfix/models/review_model.dart';
import 'package:quickfix/models/user_model.dart';
import 'package:quickfix/models/worker_profile.dart';
import 'package:quickfix/services/auth_service.dart';
import 'package:quickfix/services/job_service.dart';
import 'package:quickfix/services/profile_service.dart';
import 'package:quickfix/services/review_service.dart';
import 'package:quickfix/services/translation_service.dart';
import 'package:quickfix/views/auth/login_screen.dart';
import 'package:quickfix/views/client/client_home_screen.dart';
import 'package:quickfix/views/jobs/my_jobs_screen.dart';
import 'package:quickfix/views/profile/edit_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  final UserModel user;
  final WorkerProfile? workerProfile;
  final AuthService? authService;
  final AuthController? authController;
  final ReviewService? reviewService;
  final TranslationService? translationService;
  final ProfileService? profileService;
  final JobService? jobService;

  const ProfileScreen({
    super.key,
    required this.user,
    this.workerProfile,
    this.authService,
    this.authController,
    this.reviewService,
    this.translationService,
    this.profileService,
    this.jobService,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late UserModel _user;
  WorkerProfile? _workerProfile;
  bool _isAvailable = false;
  StreamSubscription<WorkerProfile?>? _workerProfileSub;

  bool get _isWorker => _user.role == UserRole.worker;

  AuthService get _auth => widget.authService ?? AuthService();
  AuthController get _authController =>
      widget.authController ?? AuthController();
  ReviewService get _reviewService => widget.reviewService ?? ReviewService();
  TranslationService get _translationService =>
      widget.translationService ?? TranslationService();
  ProfileService get _profileService =>
      widget.profileService ?? ProfileService();

  @override
  void initState() {
    super.initState();
    _user = widget.user;
    _workerProfile = widget.workerProfile;
    _isAvailable = widget.workerProfile?.isAvailable ?? false;
    if (_isWorker && widget.profileService != null) {
      _workerProfileSub = _profileService
          .watchWorkerProfile(_user.uid)
          .listen((profile) {
        if (!mounted) return;
        setState(() {
          _workerProfile = profile;
          _isAvailable = profile?.isAvailable ?? false;
        });
      });
    }
  }

  @override
  void didUpdateWidget(covariant ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Always pick up the latest user (name/avatar/phone) from the parent so
    // edits in EditProfileScreen show up without a logout/re-login.
    _user = widget.user;
    if (oldWidget.workerProfile?.uid != widget.workerProfile?.uid &&
        widget.workerProfile != null) {
      _workerProfile = widget.workerProfile;
      _isAvailable = widget.workerProfile?.isAvailable ?? false;
    }
  }

  @override
  void dispose() {
    _workerProfileSub?.cancel();
    super.dispose();
  }

  Future<void> _openEditProfile() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EditProfileScreen(
          user: _user,
          authService: widget.authService,
          profileService: widget.profileService,
        ),
      ),
    );
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Log Out',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        content: const Text(
          'Are you sure you want to log out?',
          style: TextStyle(fontSize: 13, color: AppTheme.textDark),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text(
              'Cancel',
              style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(
              'Yes, Log Out',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppTheme.dangerRed,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    await _auth.signOut();
    _authController.clearSession();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(
        backgroundColor: AppTheme.brandBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Profile',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            key: const Key('edit-profile-button'),
            icon: const Icon(Icons.edit, color: Colors.white, size: 20),
            onPressed: _openEditProfile,
            tooltip: 'Edit Profile',
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildProfileCard(),
              const SizedBox(height: 14),
              if (_isWorker) _buildWorkerCard(),
              if (_isWorker) const SizedBox(height: 14),
              _buildStatsCard(),
              const SizedBox(height: 14),
              if (_isWorker) _buildReviewsCard(),
              if (_isWorker) const SizedBox(height: 14),
              _buildMenuCard(),
              const SizedBox(height: 14),
              _buildLogoutButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileCard() {
    final name = _workerProfile?.fullName ?? _user.fullName;
    return Container(
      padding: const EdgeInsets.all(20),
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
        children: [
          UserAvatar(
            fullName: name,
            avatarUrl: _user.avatarUrl,
            size: 72,
            online: _isWorker && (_workerProfile?.isAvailable ?? true),
            borderColor: AppTheme.accentYellow,
          ),
          const SizedBox(height: 12),
          Text(
            name,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _isWorker ? 'Worker' : 'Customer',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.phone, size: 12, color: AppTheme.textMuted),
              const SizedBox(width: 4),
              Text(
                _user.phone,
                style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWorkerCard() {
    final wp = _workerProfile;
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
          const Text(
            'Professional Info',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 10),
          if (wp?.about != null) ...[
            Text(
              wp!.about!,
              style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 10),
          ],
          const Text(
            'Services:',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.textMuted,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: (wp?.professions ?? []).map((prof) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.ctaOrange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  prof.name[0].toUpperCase() +
                      prof.name.substring(1).replaceAll('_', ' '),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.ctaOrange,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            }).toList(),
          ),
          if ((wp?.languages ?? []).isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Languages: ${wp!.languages.join(', ')}',
              style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatsCard() {
    final stats = <(IconData, String, String)>[
      (
        Icons.star,
        'Rating',
        (_workerProfile?.rating ?? _user.rating).toStringAsFixed(1),
      ),
      (
        Icons.work_history,
        'Jobs',
        '${_workerProfile?.completedJobs ?? _user.completedJobs}',
      ),
      (
        Icons.currency_exchange,
        'Rate',
        _isWorker && _workerProfile != null
            ? 'PKR ${_workerProfile!.minBudget.toStringAsFixed(0)}'
            : '-',
      ),
    ];

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
      child: Row(
        children: stats.map((s) {
          return Expanded(
            child: Column(
              children: [
                Icon(s.$1, color: AppTheme.brandBlue, size: 18),
                const SizedBox(height: 6),
                Text(
                  s.$3,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textDark,
                  ),
                ),
                Text(
                  s.$2,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textMuted,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildReviewsCard() {
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
          const Text(
            'Reviews',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 10),
          StreamBuilder<List<Review>>(
            stream: _reviewService.watchReviewsForWorker(
              _workerProfile?.uid ?? _user.uid,
            ),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Text(
                  'Could not load reviews.',
                  style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                );
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'No reviews yet',
                    style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                  ),
                );
              }
              return Column(
                children: snapshot.data!
                    .map(
                      (review) => ReviewListTile(
                        review: review,
                        onTranslate: (text) =>
                            _translationService.translate(text, 'en'),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMenuCard() {
    final items = <(IconData, String, VoidCallback)>[
      if (_isWorker)
        (Icons.history, 'My Job History', () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => MyJobsScreen(
                workerId: _user.uid,
                jobService: widget.jobService,
              ),
            ),
          );
        })
      else
        (Icons.work_outline, 'My Posted Jobs', () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ClientHomeScreen(
                user: _user,
                jobService: widget.jobService,
              ),
            ),
          );
        }),
      (Icons.help_outline, 'Help & Support', () {}),
      (Icons.privacy_tip_outlined, 'Privacy & Security', () {}),
    ];

    final children = <Widget>[
      ...items.asMap().entries.map((entry) {
        final idx = entry.key;
        final item = entry.value;
        final isLast = idx == items.length - 1;
        return InkWell(
          onTap: item.$3,
          borderRadius: isLast
              ? const BorderRadius.vertical(bottom: Radius.circular(20))
              : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(item.$1, size: 20, color: AppTheme.brandBlue),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.$2,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textDark,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: AppTheme.textMuted,
                ),
              ],
            ),
          ),
        );
      }),
    ];
    if (_isWorker) {
      children
        ..add(const Divider(height: 1, color: AppTheme.borderGray))
        ..add(
          Material(
            color: AppTheme.surfaceWhite,
            child: SwitchListTile(
              secondary: const Icon(
                Icons.toggle_on,
                size: 20,
                color: AppTheme.brandBlue,
              ),
              title: const Text(
                'Availability',
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.textDark,
                  fontWeight: FontWeight.w500,
                ),
              ),
              subtitle: Text(
                _isAvailable ? 'Available for new jobs' : 'Unavailable',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.textMuted,
                ),
              ),
              value: _isAvailable,
              onChanged: _toggleAvailability,
            ),
          ),
        );
    }

    return Container(
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
      child: Column(children: children),
    );
  }

  Future<void> _toggleAvailability(bool value) async {
    setState(() => _isAvailable = value);
    await _profileService.setAvailability(_user.uid, value);
  }

  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      height: 46,
      child: ElevatedButton(
        onPressed: _confirmLogout,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: AppTheme.dangerRed,
          side: BorderSide(color: AppTheme.dangerRed),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 0,
        ),
        child: const Text(
          'Log Out',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
