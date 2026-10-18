import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart' as intl;
import 'package:quickfix/core/theme/app_theme.dart';
import 'package:quickfix/core/utils/content_direction.dart';
import 'package:quickfix/core/widgets/empty_state.dart';
import 'package:quickfix/core/widgets/error_state.dart';
import 'package:quickfix/core/widgets/job_category_icons.dart';
import 'package:quickfix/core/widgets/loading_list.dart';
import 'package:quickfix/core/widgets/rank_badge.dart';
import 'package:quickfix/core/widgets/user_avatar.dart';
import 'package:quickfix/models/job_model.dart';
import 'package:quickfix/models/job_request.dart';
import 'package:quickfix/models/worker_profile.dart';
import 'package:quickfix/models/worker_rank.dart';
import 'package:quickfix/services/job_request_service.dart';
import 'package:quickfix/services/job_service.dart';
import 'package:quickfix/services/profile_service.dart';

/// Owner-only applicant selection. Distances are measured to the job's
/// address, not the client's GPS (the client may be posting for someone else).
class JobApplicantsScreen extends StatefulWidget {
  final String jobId;
  final String myId;
  final JobRequestService? jobRequestService;
  final ProfileService? profileService;
  final JobService? jobService;

  const JobApplicantsScreen({
    super.key,
    required this.jobId,
    required this.myId,
    this.jobRequestService,
    this.profileService,
    this.jobService,
  });

  @override
  State<JobApplicantsScreen> createState() => _JobApplicantsScreenState();
}

class _JobApplicantsScreenState extends State<JobApplicantsScreen> {
  late final JobRequestService _jobRequestService =
      widget.jobRequestService ?? JobRequestService();
  late final ProfileService _profileService =
      widget.profileService ?? ProfileService();
  late final JobService _jobService = widget.jobService ?? JobService();

  StreamSubscription<JobModel?>? _jobSub;
  StreamSubscription<List<JobRequest>>? _requestsSub;
  final _profiles = <String, WorkerProfile?>{};
  final _rankStreams = <String, Stream<List<JobModel>>>{};
  List<JobRequest> _requests = [];
  JobModel? _job;
  WorkerProfile? _acceptedWorker;
  String? _confirmedWorkerId;
  String? _acceptedLoadingId;
  String? _acceptedError;
  bool _jobLoading = true;
  bool _requestsLoading = true;
  String? _jobError;
  String? _requestsError;
  String? _busyRequestId;
  int _generation = 0;
  int _requestVersion = 0;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  void _subscribe() {
    final generation = ++_generation;
    _jobSub?.cancel();
    _requestsSub?.cancel();
    try {
      _jobSub = _jobService.watchJob(widget.jobId).listen((job) {
        if (!mounted || generation != _generation) return;
        setState(() {
          _job = job;
          if (job != null && job.status != JobStatus.open) _confirmedWorkerId = null;
          _jobLoading = false;
          _jobError = null;
        });
        final workerId = _assignedWorkerId;
        if (workerId != null &&
            _acceptedWorker?.uid != workerId &&
            _acceptedLoadingId != workerId) {
          _loadAcceptedWorker(workerId, generation);
        }
      }, onError: (Object _) {
        if (!mounted || generation != _generation) return;
        setState(() {
          _jobLoading = false;
          _jobError = 'Could not load this job. Check your connection.';
        });
      });
    } catch (_) {
      _jobLoading = false;
      _jobError = 'Could not load this job. Check your connection.';
    }
    try {
      _requestsSub = _jobRequestService.watchUserRequests(widget.myId).listen(
        (all) => _loadProfiles(
          all
              .where((r) => r.jobId == widget.jobId && r.userId == widget.myId)
              .toList(),
          generation,
        ),
        onError: (Object _) {
          if (!mounted || generation != _generation) return;
          _requestVersion++;
          setState(() {
            _requestsLoading = false;
            _requestsError = 'Could not load applicants. Check your connection.';
          });
        },
      );
    } catch (_) {
      _requestsLoading = false;
      _requestsError = 'Could not load applicants. Check your connection.';
    }
  }

  void _retry() {
    setState(() {
      _jobLoading = true;
      _requestsLoading = true;
      _jobError = null;
      _requestsError = null;
      _acceptedError = null;
      _acceptedLoadingId = null;
      _acceptedWorker = null;
      _profiles.clear();
      _rankStreams.clear();
      _subscribe();
    });
  }

  @override
  void dispose() {
    _generation++;
    _jobSub?.cancel();
    _requestsSub?.cancel();
    super.dispose();
  }

  Future<WorkerProfile?> _profileFor(String uid) async {
    if (_profiles.containsKey(uid)) return _profiles[uid];
    final profile = await _profileService
        .getWorkerProfile(uid)
        .timeout(const Duration(seconds: 10));
    _profiles[uid] = profile;
    return profile;
  }

  Future<void> _loadProfiles(List<JobRequest> requests, int generation) async {
    final version = ++_requestVersion;
    try {
      final pending = requests.where((r) => r.status == JobRequestStatus.pending);
      await Future.wait(pending.map((r) => _profileFor(r.workerId)));
      if (!mounted || generation != _generation || version != _requestVersion) {
        return;
      }
      setState(() {
        _requests = requests;
        _requestsLoading = false;
        _requestsError = null;
      });
    } catch (_) {
      if (!mounted || generation != _generation || version != _requestVersion) {
        return;
      }
      setState(() {
        _requestsLoading = false;
        _requestsError = 'Could not load worker profiles. Please retry.';
      });
    }
  }

  String? get _assignedWorkerId {
    final job = _job;
    if (job != null &&
        (job.status == JobStatus.assigned ||
            job.status == JobStatus.inProgress ||
            job.status == JobStatus.completed)) {
      return job.workerId;
    }
    return _confirmedWorkerId;
  }

  Future<void> _loadAcceptedWorker(String uid, int generation) async {
    setState(() {
      _acceptedLoadingId = uid;
      _acceptedError = null;
    });
    try {
      final profile = await _profileFor(uid);
      if (!mounted || generation != _generation || uid != _assignedWorkerId) {
        return;
      }
      setState(() {
        _acceptedWorker = profile;
        _acceptedLoadingId = null;
      });
    } catch (_) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _acceptedLoadingId = null;
        _acceptedError = 'The job is assigned, but the worker profile could not load.';
      });
    }
  }

  double? _distance(JobRequest request) {
    final origin = _job?.location;
    final destination = _profiles[request.workerId]?.location;
    if (origin == null || destination == null) return null;
    return Geolocator.distanceBetween(
          origin.latitude,
          origin.longitude,
          destination.latitude,
          destination.longitude,
        ) /
        1000;
  }

  List<JobRequest> get _sortedApplicants {
    final pending = _requests
        .where((r) => r.status == JobRequestStatus.pending)
        .toList();
    pending.sort((a, b) {
      final rating = (_profiles[b.workerId]?.rating ?? 0)
          .compareTo(_profiles[a.workerId]?.rating ?? 0);
      if (rating != 0) return rating;
      final distance =
          (_distance(a) ?? double.infinity).compareTo(_distance(b) ?? double.infinity);
      if (distance != 0) return distance;
      final date = a.createdAt.compareTo(b.createdAt);
      return date != 0 ? date : a.id.compareTo(b.id);
    });
    return pending;
  }

  Future<void> _accept(JobRequest request) async {
    if (_busyRequestId != null || _job?.status != JobStatus.open) return;
    setState(() => _busyRequestId = request.id);
    try {
      await _jobRequestService
          .acceptApplicant(
            jobId: widget.jobId,
            requestId: request.id,
            ownerId: widget.myId,
            jobService: _jobService,
          )
          .timeout(const Duration(seconds: 15));
      if (!mounted) return;
      // Only change the presentation after the transaction is acknowledged.
      setState(() {
        _confirmedWorkerId = request.workerId;
        _acceptedWorker = _profiles[request.workerId];
      });
      _showSnack('Worker confirmed. Other pending applicants were declined.');
    } catch (_) {
      if (!mounted) return;
      _showSnack('Could not confirm this applicant. Refresh to check the latest job status.');
    } finally {
      if (mounted) setState(() => _busyRequestId = null);
    }
  }

  Future<void> _promptDecline(JobRequest request) async {
    if (_busyRequestId != null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Decline this applicant?',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: const Text(
          'This application will be declined. You can still choose another '
          'worker while the job is open.',
          style: TextStyle(fontSize: 14, color: AppTheme.textDark),
        ),
        actions: [
          TextButton(
            key: const Key('cancel-decline-button'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            key: const Key('confirm-decline-button'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.dangerRed),
            child: const Text('Decline'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || _busyRequestId != null) return;
    if (_job?.status != JobStatus.open || _assignedWorkerId != null) return;
    setState(() => _busyRequestId = request.id);
    try {
      await _jobRequestService
          .respondToRequest(requestId: request.id, status: JobRequestStatus.declined)
          .timeout(const Duration(seconds: 15));
      if (!mounted) return;
      setState(() => _requests.removeWhere((r) => r.id == request.id));
      _showSnack('Applicant declined.');
    } catch (_) {
      if (mounted) _showSnack('Could not decline this applicant. Please retry.');
    } finally {
      if (mounted) setState(() => _busyRequestId = null);
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(
        backgroundColor: AppTheme.brandBlue,
        foregroundColor: AppTheme.surfaceWhite,
        title: const Text('Applicants',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            key: const Key('refresh-applicants-button'),
            tooltip: 'Refresh applicants',
            onPressed: _busyRequestId == null ? _retry : null,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(child: _body()),
    );
  }

  Widget _body() {
    if (_jobError != null) return ErrorState(message: _jobError!, onRetry: _retry);
    if (_jobLoading) return const LoadingList(rows: 3);
    final job = _job;
    if (job == null || job.userId != widget.myId) {
      return EmptyState(
        icon: Icons.work_off_outlined,
        title: 'Job unavailable',
        message: 'Only the job owner can view and choose applicants.',
        action: TextButton(
          onPressed: () => Navigator.of(context).maybePop(),
          child: const Text('Go back'),
        ),
      );
    }
    return Column(
      children: [
        Padding(padding: const EdgeInsets.all(14), child: _jobStrip(job)),
        Expanded(child: _applicantsBody(job)),
      ],
    );
  }

  Widget _jobStrip(JobModel job) {
    final money = intl.NumberFormat('#,##0', 'en_PK');
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(job.title,
              textDirection: contentDirection(job.title),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(
            'PKR ${money.format(job.budgetMin)}–${money.format(job.budgetMax)}',
            style: const TextStyle(fontSize: 12, color: AppTheme.brandBlue),
          ),
          const SizedBox(height: 6),
          Text(
            '${jobCategoryLabel(job.category)} · '
            '${intl.DateFormat('d MMM yyyy', 'en').format(job.preferredDate)}',
            style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _applicantsBody(JobModel job) {
    if (_assignedWorkerId != null) return _acceptedCard();
    if (job.status != JobStatus.open) {
      return EmptyState(
        icon: Icons.work_off_outlined,
        title: 'This job is closed',
        message: 'Applications cannot be accepted or declined for a closed job.',
        action: TextButton(
          onPressed: () => Navigator.of(context).maybePop(),
          child: const Text('Back to job'),
        ),
      );
    }
    if (_requestsError != null) {
      return ErrorState(message: _requestsError!, onRetry: _retry);
    }
    if (_requestsLoading) return const LoadingList(rows: 3);
    final applicants = _sortedApplicants;
    if (applicants.isEmpty) {
      return EmptyState(
        icon: Icons.groups_outlined,
        title: 'No applicants yet',
        message: 'Try raising your budget or adding more detail to attract '
            'workers. New applications appear here automatically.',
        action: OutlinedButton(
          key: const Key('empty-applicants-refresh'),
          onPressed: _retry,
          child: const Text('Refresh applicants'),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      itemCount: applicants.length,
      separatorBuilder: (_, _) => const SizedBox(height: 14),
      itemBuilder: (_, index) => _applicantCard(applicants[index]),
    );
  }

  Widget _acceptedCard() {
    if (_acceptedLoadingId != null) return const LoadingList(rows: 1);
    if (_acceptedError != null) {
      return ErrorState(
        message: _acceptedError!,
        onRetry: () => _loadAcceptedWorker(_assignedWorkerId!, _generation),
      );
    }
    final worker = _acceptedWorker;
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      children: [
        _card(
          child: Column(
            children: [
              const Icon(Icons.check_circle_outline,
                  size: 44, color: AppTheme.successGreen),
              const SizedBox(height: 14),
              const Text('Worker confirmed',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              if (worker != null) ...[
                UserAvatar(fullName: worker.fullName, avatarUrl: worker.avatarUrl),
                const SizedBox(height: 10),
                Text(worker.fullName,
                    textDirection: contentDirection(worker.fullName),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text('${worker.rating.toStringAsFixed(1)} rating · '
                    '${worker.completedJobs} jobs done',
                    style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
              ] else
                const Text('The worker profile is no longer available.',
                    style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
              const SizedBox(height: 10),
              const Text('This worker is now handling your job.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
              TextButton(
                key: const Key('confirmed-back-button'),
                onPressed: () => Navigator.of(context).maybePop(true),
                child: const Text('Back to job'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _applicantCard(JobRequest request) {
    final worker = _profiles[request.workerId];
    final distance = _distance(request);
    final busy = _busyRequestId != null;
    return _card(
      key: Key('applicant-card-${request.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              UserAvatar(
                fullName: worker?.fullName ?? 'Worker',
                avatarUrl: worker?.avatarUrl,
                size: 44,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  worker?.fullName ?? 'Worker profile unavailable',
                  textDirection: contentDirection(worker?.fullName ?? ''),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          if (worker != null) ...[
            const SizedBox(height: 10),
            _rankBadge(worker),
            const SizedBox(height: 10),
            Wrap(
              spacing: 14,
              runSpacing: 6,
              children: [
                Text('${worker.rating.toStringAsFixed(1)} rating'),
                Text('${worker.completedJobs} jobs done'),
                Text(distance == null
                    ? 'Distance unavailable'
                    : '${distance.toStringAsFixed(1)} km from job'),
              ],
            ),
          ],
          if (request.message?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 10),
            Text(
              request.message!,
              textDirection: contentDirection(request.message!),
              style: const TextStyle(fontSize: 14, color: AppTheme.textDark),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  key: Key('applicant-accept-${request.id}'),
                  onPressed: busy || worker == null ? null : () => _accept(request),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(44, 44),
                    backgroundColor: AppTheme.successGreen,
                    foregroundColor: AppTheme.surfaceWhite,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _busyRequestId == request.id
                      ? const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Accept',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: OutlinedButton(
                  key: Key('applicant-decline-${request.id}'),
                  onPressed: busy ? null : () => _promptDecline(request),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(44, 44),
                    foregroundColor: AppTheme.dangerRed,
                    side: const BorderSide(color: AppTheme.borderGray),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Decline',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _rankBadge(WorkerProfile worker) {
    final stream = _rankStreams.putIfAbsent(
      worker.uid, () => _jobService.watchCompletedJobsForWorker(worker.uid),
    );
    return StreamBuilder<List<JobModel>>(
      stream: stream,
      builder: (_, snapshot) {
        if (snapshot.hasError || !snapshot.hasData) {
          return Text(snapshot.hasError ? 'Rank unavailable' : 'Loading rank…',
              style: const TextStyle(fontSize: 12, color: AppTheme.textMuted));
        }
        final count = WorkerRank.countCompletedInYear(
          snapshot.data!
              .where((job) => job.status == JobStatus.completed)
              .map((job) => job.completedAt ?? job.updatedAt),
          now: DateTime.now(),
        );
        return RankBadge(
          rank: WorkerRank.forCompletedInYear(count), completedInYear: count,
        );
      },
    );
  }

  Widget _card({Key? key, required Widget child}) => Container(
        key: key,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surfaceWhite,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.borderGray),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: DefaultTextStyle.merge(
          style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
          child: child,
        ),
      );
}
