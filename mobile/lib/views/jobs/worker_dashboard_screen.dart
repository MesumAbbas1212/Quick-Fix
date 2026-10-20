import 'package:quickfix/core/widgets/quote_feature_entry.dart';
import 'package:quickfix/core/widgets/worker_applications_list.dart';
import 'package:quickfix/models/job_preferences.dart';
import 'package:quickfix/services/job_preference_service.dart';
import 'package:quickfix/views/worker/job_alert_preferences_screen.dart';
import 'package:quickfix/core/widgets/empty_state.dart';
import 'package:quickfix/core/widgets/error_state.dart';
import 'package:quickfix/core/widgets/loading_list.dart';
import 'package:quickfix/views/worker/availability_settings_screen.dart';
import 'package:quickfix/core/widgets/notification_bell.dart';
import 'package:quickfix/services/notification_service.dart';
import 'package:quickfix/services/job_request_service.dart';
import 'package:quickfix/core/widgets/app_card.dart';
import 'package:quickfix/models/worker_verification.dart';
import 'package:quickfix/services/verification_service.dart';
import 'package:quickfix/views/worker/verification_screen.dart';
import 'package:flutter/material.dart';
import 'package:quickfix/core/theme/app_theme.dart';
import 'package:quickfix/core/widgets/job_category_icons.dart';
import 'package:quickfix/core/widgets/job_image_thumb.dart';
import 'package:quickfix/models/job_model.dart';
import 'package:quickfix/models/user_model.dart';
import 'package:quickfix/models/worker_profile.dart';
import 'package:quickfix/services/auth_service.dart';
import 'package:quickfix/services/job_service.dart';
import 'package:quickfix/services/local_image_store.dart';
import 'package:quickfix/services/profile_service.dart';
import 'package:quickfix/views/jobs/job_request_screen.dart';
import 'package:quickfix/views/onboarding/worker_onboarding_screen.dart';

class WorkerDashboardScreen extends StatefulWidget {
  final UserModel user;
  final NotificationService? notificationService;
  final WorkerProfile? workerProfile;
  final JobService? jobService;
  final JobRequestService? requestService;
  final ProfileService? profileService;
  final AuthService? authService;
  final LocalImageStore? imageStore;
  final VerificationService? verificationService;

  const WorkerDashboardScreen({
    super.key,
    required this.user,
    this.notificationService,
    this.workerProfile,
    this.jobService,
    this.requestService,
    this.profileService,
    this.authService,
    this.imageStore,
    this.verificationService,
  });

  @override
  State<WorkerDashboardScreen> createState() => _WorkerDashboardScreenState();
}

class _WorkerDashboardScreenState extends State<WorkerDashboardScreen> {
  late bool _isAvailable = widget.workerProfile?.isAvailable ?? true;
  late final JobService _jobService = widget.jobService ?? JobService();
  late final ProfileService _profileService =
      widget.profileService ?? ProfileService();

  Future<void> _toggleAvailability() async {
    final next = !_isAvailable;
    setState(() => _isAvailable = next);
    try {
      await _profileService.setAvailability(widget.user.uid, next);
    } catch (_) {
      // Keep UI in sync even if the write fails quietly.
    }
  }

  /// Shown when the worker has no `workers/{uid}` document — without it the
  /// worker is invisible in Browse Workers, so this is the recovery path
  /// after a missed sign-up wizard.
  Widget _buildOnboardingBanner() {
    final compact = MediaQuery.textScalerOf(context).scale(12) > 20;
    return Container(
      margin: const EdgeInsets.all(14),
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
        border: Border.all(color: AppTheme.ctaOrange),
      ),
      child: Row(
        children: [
          const Icon(Icons.person_add_alt_1_outlined,
              size: 22, color: AppTheme.ctaOrange),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Complete your worker profile',
                  maxLines: 2,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textDark,
                  ),
                ),
                if (!compact) ...[
                  const SizedBox(height: 2),
                  const Text(
                    'Clients can only find you in Browse Workers once your '
                    'profile is set up.',
                    style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                  ),
                ],
              ],
            ),
          ),
          TextButton(
            key: const Key('complete-profile-button'),
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => WorkerOnboardingScreen(
                    user: widget.user,
                    profileService: widget.profileService,
                    imageStore: widget.imageStore,
                    returnToShell: false,
                  ),
                ),
              );
            },
            child: const Text(
              'Set up',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppTheme.ctaOrange,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            QuoteFeatureEntry(user: widget.user, profileService: widget.profileService, jobService: widget.jobService),
            if (widget.workerProfile == null) _buildOnboardingBanner(),
            if (widget.workerProfile != null && widget.workerProfile?.verification?.status != VerificationStatus.verified)
              Padding(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6), child: AppCard(padding: 8, child: Row(children: [
                const Icon(Icons.shield_outlined, color: AppTheme.brandBlue), const SizedBox(width: 8),
                Expanded(child: Text(widget.workerProfile?.verification?.status == VerificationStatus.pending ? 'Identity review pending' : 'Request a manual identity check',
                  maxLines: MediaQuery.textScalerOf(context).scale(12) > 20 ? 2 : null,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: AppTheme.textDark))),
                TextButton(key: const Key('dashboard-verification'), onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => VerificationScreen(
                  user: widget.user, verificationService: widget.verificationService, imageStore: widget.imageStore))), child: const Text('View')),
              ]))),
            Expanded(
              child: _buildJobs(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      color: AppTheme.brandBlue,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Jobs',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
              IconButton(key: const Key('dashboard-availability-settings'), tooltip: 'Availability and service area', onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AvailabilitySettingsScreen(
                workerId: widget.user.uid, profileService: widget.profileService))), icon: const Icon(Icons.event_available_outlined, color: AppTheme.surfaceWhite)),
              NotificationBell(user: widget.user, notificationService: widget.notificationService),
              Flexible(
                child: GestureDetector(
                onTap: _toggleAvailability,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _isAvailable
                        ? AppTheme.successGreen
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
                      Expanded(
                        child: Text(
                        _isAvailable ? 'Available' : 'Busy',
                        maxLines: 2,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'Hi, $_firstName!',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFFBFDBFE),
            ),
          ),
        ],
      ),
    );
  }

  late Stream<List<JobModel>> _board = _watchBoard();
  late final JobPreferenceService _preferences = JobPreferenceService(authService: widget.authService);
  List<JobModel>? _verifiedInput;
  String _verifiedKey = '';
  Future<List<JobModel>>? _verifiedJobs;
  Stream<List<JobModel>> _watchBoard() { try { return _jobService.watchOpenJobs(); } catch (error, stack) { return Stream.error(error, stack); } }
  void _reloadBoard() => setState(() { _board = _watchBoard(); _verifiedInput = null; });
  Future<void> _editPrefs() async { await Navigator.of(context).push(MaterialPageRoute(builder: (_) => JobAlertPreferencesScreen(workerId: widget.user.uid, profileService: widget.profileService))); if (mounted) { _reloadBoard(); } }

  String get _firstName {
    final name = (widget.workerProfile?.fullName ?? widget.user.fullName)
        .trim();
    if (name.isEmpty) { return 'there'; }
    return name.split(RegExp(r'\s+')).first;
  }

  Widget _buildJobs() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Padding(padding: const EdgeInsetsDirectional.fromSTEB(14, 8, 8, 4), child: Row(children: [
      Expanded(child: Text('Suggested Jobs For You', maxLines: MediaQuery.textScalerOf(context).scale(14) > 20 ? 2 : null, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textDark))),
      IconButton(key: const Key('dashboard-applications'), tooltip: 'My applications', onPressed: () => showModalBottomSheet<void>(context: context, isScrollControlled: true, showDragHandle: true, builder: (_) => SizedBox(height: MediaQuery.sizeOf(context).height * .75, child: WorkerApplicationsList(workerId: widget.user.uid, requestService: widget.requestService, jobService: widget.jobService))), icon: const Icon(Icons.assignment_outlined, color: AppTheme.brandBlue)),
      IconButton(key: const Key('dashboard-job-preferences'), tooltip: 'Job alert preferences', onPressed: _editPrefs, icon: const Icon(Icons.filter_list, color: AppTheme.brandBlue)),
      IconButton(key: const Key('dashboard-job-refresh'), tooltip: 'Refresh jobs', onPressed: _reloadBoard, icon: const Icon(Icons.refresh, color: AppTheme.brandBlue)),
    ])),
    Padding(padding: const EdgeInsets.symmetric(horizontal: 14), child: Text('Preferences filter the currently loaded board, not every job in the database.', maxLines: MediaQuery.textScalerOf(context).scale(12) > 20 ? 2 : null, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppTheme.textMuted))),
    Expanded(child: StreamBuilder<List<JobModel>>(stream: _board, builder: (context, snapshot) {
      if (snapshot.hasError) { return ErrorState(message: 'Could not load jobs', onRetry: _reloadBoard); }
      if (!snapshot.hasData) { return const SingleChildScrollView(child: LoadingList()); }
      final prefs = widget.workerProfile?.jobPrefs ?? const JobPreferences();
      final local = _preferences.applyLocal(snapshot.data!.where((job) => job.userId != widget.user.uid), prefs, widget.workerProfile?.location);
      if (!prefs.onlyVerifiedClients) { return _jobRows(local); }
      final key = '${prefs.toMap()}|${widget.workerProfile?.location}';
      if (!identical(_verifiedInput, snapshot.data) || _verifiedKey != key) { _verifiedInput = snapshot.data; _verifiedKey = key; _verifiedJobs = _preferences.filterVerified(local); }
      return FutureBuilder<List<JobModel>>(future: _verifiedJobs, builder: (context, verified) {
        if (verified.hasError) { return ErrorState(message: 'Could not check client flags. Retry or change job preferences.', onRetry: _reloadBoard); }
        if (!verified.hasData) { return const SingleChildScrollView(child: LoadingList()); }
        return _jobRows(verified.data!);
      });
    })),
  ]);
  Widget _jobRows(List<JobModel> jobs) {
    if (jobs.isEmpty) { return SingleChildScrollView(child: EmptyState(icon: Icons.work_off_outlined, title: 'No open jobs right now',
      message: 'No loaded jobs match your preferences. Try broader filters or check again.', action: OutlinedButton(key: const Key('dashboard-empty-preferences'), onPressed: _editPrefs, child: const Text('Change job preferences')))); }
    return ListView.builder(padding: const EdgeInsets.all(14), itemCount: jobs.length, itemBuilder: (context, index) => Padding(padding: const EdgeInsets.only(bottom: 12), child: _buildSuggestionCard(jobs[index])));
  }

  Widget _buildSuggestionCard(JobModel job) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => JobRequestScreen(
            job: job,
            client: null,
            workerId: widget.user.uid,
            jobService: _jobService,
            requestService: widget.requestService,
            authService: widget.authService,
            // Single pop only - JobRequestScreen no longer pops itself
            // when a callback is supplied (double-pop caused a black screen).
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
            JobImageThumb(
              image: job.images.firstOrNull,
              fallbackIcon: _categoryIcon(job.category),
              fallbackColor: _categoryColor(job.category),
              imageStore: widget.imageStore,
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
                    style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          'PKR ${_formatBudget(job.budgetMin)}-'
                          '${_formatBudget(job.budgetMax)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textDark,
                          ),
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
                          _categoryLabel(job.category),
                          style: const TextStyle(
                            fontSize: 12,
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

  String _formatBudget(double budget) {
    if (budget >= 1000) {
      final k = budget / 1000;
      return '${k == k.roundToDouble() ? k.toStringAsFixed(0) : k.toStringAsFixed(1)}k';
    }
    return budget.toStringAsFixed(0);
  }

  String _categoryLabel(JobCategory cat) => jobCategoryLabel(cat);

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

  IconData _categoryIcon(JobCategory cat) => jobCategoryIcon(cat);
}