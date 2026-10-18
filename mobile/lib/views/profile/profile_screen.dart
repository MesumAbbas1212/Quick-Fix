import 'package:quickfix/views/worker/verification_screen.dart';
import 'package:quickfix/services/verification_service.dart';
import 'package:quickfix/services/local_image_store.dart';
import 'package:quickfix/views/settings/language_picker_screen.dart';
import 'package:quickfix/views/settings/settings_screen.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:quickfix/controllers/auth_controller.dart';
import 'package:quickfix/core/theme/app_theme.dart';
import 'package:quickfix/core/widgets/rank_badge.dart';
import 'package:quickfix/core/widgets/review_list_tile.dart';
import 'package:quickfix/core/widgets/user_avatar.dart';
import 'package:quickfix/models/app_language.dart';
import 'package:quickfix/models/job_model.dart';
import 'package:quickfix/models/review_model.dart';
import 'package:quickfix/models/user_model.dart';
import 'package:quickfix/models/worker_profile.dart';
import 'package:quickfix/models/worker_rank.dart';
import 'package:quickfix/services/auth_service.dart';
import 'package:quickfix/services/job_service.dart';
import 'package:quickfix/services/payment_service.dart';
import 'package:quickfix/services/language_service.dart';
import 'package:quickfix/services/profile_service.dart';
import 'package:quickfix/services/review_service.dart';
import 'package:quickfix/services/translation_service.dart';
import 'package:quickfix/views/auth/login_screen.dart';
import 'package:quickfix/views/client/client_home_screen.dart';
import 'package:quickfix/views/jobs/my_jobs_screen.dart';
import 'package:quickfix/views/payments/payment_history_screen.dart';
import 'package:quickfix/views/profile/edit_profile_screen.dart';
import 'package:quickfix/views/worker/rank_progress_screen.dart';
import 'package:quickfix/views/worker/earnings_screen.dart';

class ProfileScreen extends StatefulWidget {
  final UserModel user;
  final WorkerProfile? workerProfile;
  final AuthService? authService;
  final AuthController? authController;
  final ReviewService? reviewService;
  final TranslationService? translationService;
  final ProfileService? profileService;
  final JobService? jobService;
  final LanguageService? languageService;
  final PaymentService? paymentService;
  final VerificationService? verificationService;
  final LocalImageStore? imageStore;

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
    this.languageService,
    this.paymentService,
    this.verificationService,
    this.imageStore,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late UserModel _user;
  WorkerProfile? _workerProfile;
  Stream<List<JobModel>>? _rankJobs;
  bool _isAvailable = false;
  StreamSubscription<WorkerProfile?>? _workerProfileSub;

  /// My Reviews preview length before the "Show all" toggle expands.
  static const int _myReviewsPreviewCount = 5;
  bool _showAllMyReviews = false;

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
    if (_isWorker && widget.jobService != null) {
      _rankJobs = widget.jobService!.watchWorkerJobs(_user.uid);
    }
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
              if (_isWorker) ...[
                _buildWorkerCard(),
                const SizedBox(height: 14),
              ],
              if (_isWorker)
                _buildWorkerStatsCard()
              else
                _buildClientActivityCard(),
              const SizedBox(height: 14),
              if (_isWorker)
                _buildReviewsCard()
              else
                _buildMyReviewsCard(),
              const SizedBox(height: 14),
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
          if (_isWorker) ...[
            const SizedBox(height: 10),
            TextButton(
              key: const Key('rank-progress-entry'),
              style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => RankProgressScreen(
                    workerUid: _user.uid,
                    jobService: widget.jobService,
                  ),
                ),
              ),
              child: _buildProfileRankBadge(),
            ),
          ],
          const SizedBox(height: 8),
          if (_user.email.isNotEmpty)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.email_outlined,
                    size: 12, color: AppTheme.textMuted),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    _user.email,
                    style:
                        const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          const SizedBox(height: 6),
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

  Widget _buildWorkerStatsCard() {
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
        _workerProfile != null
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

  Widget _buildProfileRankBadge() {
    final stream = _rankJobs;
    // Keep the pre-existing fallback for standalone profiles without a jobs
    // service. The production worker shell supplies the live service.
    final fallback = RankBadge(
      rank: WorkerRank.forCompletedInYear(
        _workerProfile?.completedJobs ?? _user.completedJobs,
      ),
    );
    if (stream == null) return fallback;
    return StreamBuilder<List<JobModel>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Text('Rank unavailable',
              style: TextStyle(fontSize: 12, color: AppTheme.textMuted));
        }
        if (!snapshot.hasData) {
          return const Text('Loading rank…',
              style: TextStyle(fontSize: 12, color: AppTheme.textMuted));
        }
        final count = WorkerRank.countCompletedInYear(
          snapshot.data!
              .where((job) => job.status == JobStatus.completed)
              .map((job) => job.completedAt ?? job.updatedAt),
          now: DateTime.now(),
        );
        return RankBadge(
          rank: WorkerRank.forCompletedInYear(count),
          completedInYear: count,
        );
      },
    );
  }

  /// Client-facing stats: activity on the user's own posted jobs, instead
  /// of the worker-style rating/jobs/rate row which doesn't apply to
  /// customers.
  Widget _buildClientActivityCard() {
    final jobService = widget.jobService;
    if (jobService == null) return const SizedBox.shrink();
    return StreamBuilder<List<JobModel>>(
      stream: jobService.watchUserJobs(_user.uid),
      builder: (context, snapshot) {
        final jobs = snapshot.data ?? const <JobModel>[];
        final inProgress = jobs
            .where((j) =>
                j.status == JobStatus.assigned ||
                j.status == JobStatus.inProgress)
            .length;
        final completed =
            jobs.where((j) => j.status == JobStatus.completed).length;
        final stats = <(IconData, String, String)>[
          (Icons.work_outline, 'Posted', '${jobs.length}'),
          (Icons.schedule, 'In Progress', '$inProgress'),
          (Icons.check_circle, 'Completed', '$completed'),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'My Activity',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 10),
              Row(
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
            ],
          ),
        );
      },
    );
  }

  /// Reviews this client has written, shown on their own profile.
  Widget _buildMyReviewsCard() {
    final reviewService = widget.reviewService;
    if (reviewService == null) return const SizedBox.shrink();
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
            'My Reviews',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 10),
          StreamBuilder<List<Review>>(
            stream: reviewService.watchReviewsByUser(_user.uid),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Text(
                  'Could not load your reviews.',
                  style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                );
              }
              final reviews = snapshot.data ?? const <Review>[];
              if (!snapshot.hasData || reviews.isEmpty) {
                return const Text(
                  "You haven't written any reviews yet.",
                  style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                );
              }
              final shown = _showAllMyReviews
                  ? reviews
                  : reviews.take(_myReviewsPreviewCount).toList();
              return Column(
                children: [
                  ...shown.map((review) => ReviewListTile(
                        review: review,
                        onTranslate: (text) => _translationService.translate(
                            text, _user.preferredLanguage),
                        viewerLanguage: _user.preferredLanguage,
                      )),
                  if (reviews.length > _myReviewsPreviewCount)
                    Align(
                      alignment: Alignment.center,
                      child: TextButton(
                        key: const Key('show-all-my-reviews-button'),
                        onPressed: () => setState(
                            () => _showAllMyReviews = !_showAllMyReviews),
                        child: Text(
                          _showAllMyReviews
                              ? 'Show less'
                              : 'Show all ${reviews.length} reviews',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.brandBlue,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
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
                        onTranslate: (text) => _translationService.translate(
                            text, _user.preferredLanguage),
                        viewerLanguage: _user.preferredLanguage,
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

  Future<void> _openLanguageDialog() async {
    final selection = await Navigator.of(context).push<AppLanguage>(MaterialPageRoute(builder: (_) => LanguagePickerScreen(
      user: _user, languageService: widget.languageService, authService: widget.authService, translationService: widget.translationService)));
    if (mounted && selection != null) setState(() { _user = _user.copyWith(preferredLanguage: selection.code); });
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
                paymentService: widget.paymentService,
                profileService: widget.profileService,
                authService: widget.authService,
                reviewService: widget.reviewService,
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
      if (_isWorker)
        (Icons.account_balance_wallet_outlined, 'Earnings', () {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => EarningsScreen(
              workerId: _user.uid, jobService: widget.jobService,
              paymentService: widget.paymentService,
            ),
          ));
        }),
      (Icons.payment_outlined, 'Payments', () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PaymentHistoryScreen(
              user: _user,
              jobService: widget.jobService,
              profileService: widget.profileService,
              authService: widget.authService,
              paymentService: widget.paymentService,
            ),
          ),
        );
      }),
      if (_isWorker) (Icons.verified_user_outlined, 'Verification', () {
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => VerificationScreen(user: _user,
          verificationService: widget.verificationService, imageStore: widget.imageStore)));
      }),
      (Icons.translate, 'App Language', _openLanguageDialog),
      (Icons.settings_outlined, 'Settings', () {
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => SettingsScreen(user: _user,
          authService: widget.authService, languageService: widget.languageService, translationService: widget.translationService)));
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
