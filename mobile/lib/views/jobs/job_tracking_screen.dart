import 'package:quickfix/views/worker/client_profile_screen.dart';
import 'package:quickfix/views/jobs/reschedule_job_screen.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:quickfix/core/theme/app_theme.dart';
import 'package:quickfix/core/utils/content_direction.dart';
import 'package:quickfix/core/widgets/app_card.dart';
import 'package:quickfix/core/widgets/empty_state.dart';
import 'package:quickfix/core/widgets/error_state.dart';
import 'package:quickfix/core/widgets/job_category_icons.dart';
import 'package:quickfix/core/widgets/loading_list.dart';
import 'package:quickfix/core/widgets/status_pill.dart';
import 'package:quickfix/core/widgets/user_avatar.dart';
import 'package:quickfix/models/job_model.dart';
import 'package:quickfix/models/shared_location.dart';
import 'package:quickfix/services/auth_service.dart';
import 'package:quickfix/services/chat_service.dart';
import 'package:quickfix/services/job_service.dart';
import 'package:quickfix/services/map_launcher.dart';
import 'package:quickfix/services/payment_service.dart';
import 'package:quickfix/services/profile_service.dart';
import 'package:quickfix/services/review_service.dart';
import 'package:quickfix/views/chat/chat_screen.dart';
import 'package:quickfix/views/payments/payment_screen.dart';

/// Live job state plus the other party's explicitly shared chat position.
/// Never polls or requests location permission. "On the way" is a display
/// stage, not a new Firestore status or a claim that somebody is travelling.
class JobTrackingScreen extends StatefulWidget {
  final String jobId;
  final String myId;
  final JobService? jobService;
  final ProfileService? profileService;
  final AuthService? authService;
  final ChatService? chatService;
  final UrlLauncher? urlLauncher;
  final PaymentService? paymentService;
  final ReviewService? reviewService;
  final String reviewerLanguage;

  const JobTrackingScreen({super.key, required this.jobId, required this.myId,
    this.jobService, this.profileService, this.authService, this.chatService,
    this.urlLauncher, this.paymentService, this.reviewService,
    this.reviewerLanguage = 'en'});

  @override
  State<JobTrackingScreen> createState() => _JobTrackingScreenState();
}

class _JobTrackingScreenState extends State<JobTrackingScreen> {
  late final JobService _jobs = widget.jobService ?? JobService();
  late final ProfileService _profiles = widget.profileService ?? ProfileService();
  late final AuthService _auth = widget.authService ?? AuthService();
  late final ChatService _chat = widget.chatService ?? ChatService();
  late final UrlLauncher _launcher = widget.urlLauncher ?? const MapLauncher();
  late Stream<JobModel?> _jobStream = _watchJob();
  String? _contactId;
  Stream<_JobContact?>? _contactStream;
  String? _locationKey;
  Stream<SharedLocation?>? _locationStream;
  bool _busy = false;

  Stream<JobModel?> _watchJob() {
    try { return _jobs.watchJob(widget.jobId); }
    catch (error, stack) { return Stream<JobModel?>.error(error, stack); }
  }

  void _retry() => setState(() {
    _jobStream = _watchJob();
    _contactId = null;
    _contactStream = null;
    _locationKey = null;
    _locationStream = null;
  });

  String? _peerId(JobModel job) => job.userId == widget.myId ? job.workerId : job.userId;

  Stream<_JobContact?> _watchContact(JobModel job) {
    try {
      if (job.userId == widget.myId) {
        return _profiles.watchWorkerProfile(job.workerId!).map((worker) => worker == null
          ? null : _JobContact(worker.fullName, worker.phone, worker.avatarUrl));
      }
      return _auth.watchUser(job.userId).map((client) => client == null
        ? null : _JobContact(client.fullName, client.phone, client.avatarUrl));
    } catch (error, stack) { return Stream<_JobContact?>.error(error, stack); }
  }

  Stream<SharedLocation?> _watchLocation(JobModel job, String peerId) {
    try {
      return _chat.watchLatestSharedLocation(widget.myId, peerId, senderId: peerId,
        since: job.assignedAt ?? job.createdAt);
    } catch (error, stack) { return Stream<SharedLocation?>.error(error, stack); }
  }

  void _snack(String message) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openLocation(double latitude, double longitude) async {
    try {
      if (!await _launcher.openLocation(latitude, longitude)) _snack('Could not open Maps.');
    } catch (_) { _snack('Could not open Maps.'); }
  }

  Future<void> _call(String phone) async {
    final number = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    try {
      if (number.isEmpty || !await _launcher.open('tel:$number')) _snack('Could not open the phone app.');
    } catch (_) { _snack('Could not open the phone app.'); }
  }

  Future<bool> _confirm(String title, String message, String action, {bool destructive = false}) async =>
    await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(
      title: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
      content: Text(message, style: const TextStyle(fontSize: 13, color: AppTheme.textMuted)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Not now')),
        TextButton(key: const Key('tracking-confirm-action'),
          style: TextButton.styleFrom(foregroundColor: destructive ? AppTheme.dangerRed : AppTheme.brandBlue),
          onPressed: () => Navigator.pop(dialogContext, true), child: Text(action)),
      ],
    )) ?? false;

  Future<void> _advance(JobModel job) async {
    if (_busy || job.workerId != widget.myId) return;
    final completing = job.status == JobStatus.inProgress;
    if (job.status != JobStatus.assigned && !completing) return;
    if (completing && !await _confirm('Complete this job?',
      'Only mark the job complete after the work is finished. The client can then pay and review.',
      'Mark complete')) return;
    if (!mounted || _busy) return;
    setState(() => _busy = true);
    try {
      await _jobs.advanceJobStatus(jobId: job.id, workerId: widget.myId,
        status: completing ? JobStatus.completed : JobStatus.inProgress)
          .timeout(const Duration(seconds: 15));
      _snack(completing ? 'Job marked complete.' : 'Job started.');
    } catch (_) { _snack('Could not update the job. Check your connection and latest status.'); }
    finally { if (mounted) setState(() => _busy = false); }
  }

  Future<void> _cancel(JobModel job) async {
    if (_busy || job.userId != widget.myId || job.status != JobStatus.assigned) return;
    if (!await _confirm('Cancel this job?',
      'This will mark the job cancelled. It cannot be undone from tracking.',
      'Cancel job', destructive: true)) return;
    if (!mounted || _busy) return;
    setState(() => _busy = true);
    try {
      await _jobs.cancelAssignedJob(job.id, widget.myId).timeout(const Duration(seconds: 15));
      _snack('Job cancelled.');
    } catch (_) { _snack('Could not cancel the job. It may already have started. Refresh and try again.'); }
    finally { if (mounted) setState(() => _busy = false); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppTheme.bgLight,
    appBar: AppBar(backgroundColor: AppTheme.surfaceWhite, elevation: 0,
      title: const Text('Job Tracking', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
      actions: [IconButton(tooltip: 'Refresh tracking', onPressed: _busy ? null : _retry,
        icon: const Icon(Icons.refresh, color: AppTheme.brandBlue))]),
    body: SafeArea(child: StreamBuilder<JobModel?>(stream: _jobStream, builder: (context, snapshot) {
      if (snapshot.hasError) return ErrorState(message: 'Could not load job tracking. Check your connection.', onRetry: _retry);
      if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) return const LoadingList(rows: 4);
      final job = snapshot.data;
      if (job == null) return EmptyState(icon: Icons.work_off_outlined, title: 'Job unavailable',
        message: 'This job may have been removed. Return to your jobs or retry.',
        action: OutlinedButton(onPressed: _retry, child: const Text('Reload job')));
      if (job.userId != widget.myId && job.workerId != widget.myId) {
        return const ErrorState(message: 'Tracking is only available to the client and assigned worker.');
      }
      return _content(job);
    })),
  );

  Widget _content(JobModel job) {
    if (job.anonymized) return ListView(padding: const EdgeInsets.all(16), children: [
      const AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Completed job — anonymized history', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        SizedBox(height: 10), Text('The other account was deleted. This record is kept for your history. Identifying details and location were removed; contact, payment and review actions are no longer available.',
          style: TextStyle(fontSize: 13, color: AppTheme.textMuted)),
      ])), const SizedBox(height: 16), _stepper(job, null),
    ]);
    final peerId = _peerId(job);
    if (peerId != null && peerId.isNotEmpty) {
      if (_contactId != peerId) {
        _contactId = peerId;
        _contactStream = _watchContact(job);
      }
      final key = '$peerId:${(job.assignedAt ?? job.createdAt).toIso8601String()}';
      if (_locationKey != key) {
        _locationKey = key;
        _locationStream = _watchLocation(job, peerId);
      }
    }
    return ListView(padding: const EdgeInsets.all(16), children: [
      AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(job.title, textDirection: contentDirection(job.title),
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppTheme.textDark)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          StatusPill(label: _statusLabel(job.status), color: _statusColor(job.status)),
          Text(jobCategoryLabel(job.category), style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
        ]),
        const SizedBox(height: 12),
        Text(job.address, textDirection: contentDirection(job.address),
          style: const TextStyle(fontSize: 13, color: AppTheme.textMuted)),
        TextButton.icon(key: const Key('tracking-job-maps'),
          onPressed: () => _openLocation(job.location.latitude, job.location.longitude),
          icon: const Icon(Icons.map_outlined, size: 20), label: const Text('Open job location in Maps')),
      ])),
      const SizedBox(height: 16),
      if (peerId != null && peerId.isNotEmpty) ...[
        _contactCard(job, peerId),
        const SizedBox(height: 16),
        StreamBuilder<SharedLocation?>(key: ValueKey(_locationKey), stream: _locationStream, builder: (context, locationSnapshot) => Column(
          children: [
            _stepper(job, locationSnapshot.data),
            const SizedBox(height: 16),
            _locationCard(job, peerId, locationSnapshot),
          ],
        )),
      ] else ...[
        AppCard(child: EmptyState(icon: Icons.person_search_outlined, title: 'Waiting for assignment',
          message: 'Tracking and contact details appear once a worker is assigned.',
          action: OutlinedButton(onPressed: _retry, child: const Text('Check assignment')))),
        const SizedBox(height: 16),
        _stepper(job, null),
      ],
      const SizedBox(height: 16),
      if (job.status == JobStatus.cancelled)
        const AppCard(child: Text('This job is cancelled. No further job actions are available.',
          style: TextStyle(fontSize: 13, color: AppTheme.textMuted))),
      if (job.workerId == widget.myId && (job.status == JobStatus.assigned || job.status == JobStatus.inProgress))
        ElevatedButton(key: const Key('tracking-worker-action'), onPressed: _busy ? null : () => _advance(job),
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.ctaOrange, foregroundColor: AppTheme.surfaceWhite,
            minimumSize: const Size.fromHeight(48)),
          child: _busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(
            strokeWidth: 2, color: AppTheme.surfaceWhite)) : Text(job.status == JobStatus.assigned ? 'Start job' : 'Complete job')),
      if (job.userId == widget.myId && (job.status == JobStatus.assigned || job.status == JobStatus.inProgress))
        OutlinedButton(key: const Key('tracking-reschedule'), onPressed: _busy ? null : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => RescheduleJobScreen(
          jobId: job.id, userId: widget.myId, jobService: _jobs))), child: const Text('Change schedule / cancellation reason')),
      if (job.userId == widget.myId && job.status == JobStatus.assigned)
        OutlinedButton(key: const Key('tracking-cancel-button'), onPressed: _busy ? null : () => _cancel(job),
          style: OutlinedButton.styleFrom(foregroundColor: AppTheme.dangerRed,
            side: const BorderSide(color: AppTheme.dangerRed), minimumSize: const Size.fromHeight(48)),
          child: Text(_busy ? 'Cancelling…' : 'Cancel job')),
      // Terminal states hide progression/cancel, not the explicitly requested
      // completed-client payment/review action (a separate post-job workflow).
      if (job.userId == widget.myId && job.workerId != null && job.status == JobStatus.completed)
        ElevatedButton(key: const Key('tracking-payment-button'),
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PaymentScreen(
            jobId: job.id, myId: widget.myId, jobService: _jobs,
            paymentService: widget.paymentService, profileService: widget.profileService,
            reviewService: widget.reviewService, reviewerLanguage: widget.reviewerLanguage))),
          child: const Text('Pay & review')),
    ]);
  }

  Widget _contactCard(JobModel job, String peerId) => AppCard(child: StreamBuilder<_JobContact?>(key: ValueKey(_contactId),
    stream: _contactStream, builder: (context, snapshot) {
      final contact = snapshot.data;
      final name = contact != null && contact.name.isNotEmpty ? contact.name : job.userId == widget.myId ? 'Assigned worker' : 'Client';
      final phone = contact?.phone;
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          UserAvatar(fullName: name, avatarUrl: contact?.avatarUrl, size: 48),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, textDirection: contentDirection(name), style: const TextStyle(fontSize: 14,
              fontWeight: FontWeight.w600, color: AppTheme.textDark)),
            Text(snapshot.connectionState == ConnectionState.waiting ? 'Loading contact…' :
              snapshot.hasError ? 'Could not load contact details.' :
              contact == null ? 'Profile unavailable. You can still chat.' :
              phone == null || phone.trim().isEmpty ? 'Phone number not provided' : phone,
              style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
          ])),
        ]),
        if (snapshot.hasError || (snapshot.connectionState != ConnectionState.waiting && contact == null))
          TextButton(key: const Key('tracking-contact-retry'), onPressed: () => setState(() {
            _contactStream = _watchContact(job);
          }), child: const Text('Retry contact')),
        if (job.workerId == widget.myId) TextButton(key: const Key('tracking-client-profile'), onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ClientProfileScreen(clientId: job.userId, viewerId: widget.myId, viewerLanguage: widget.reviewerLanguage, authService: widget.authService, jobService: widget.jobService, reviewService: widget.reviewService))), child: const Text('View client profile')),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: OutlinedButton.icon(key: const Key('tracking-chat-button'),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChatScreen(
              peerId: peerId, peerName: name, myId: widget.myId, chatService: _chat, urlLauncher: _launcher))),
            icon: const Icon(Icons.chat_bubble_outline, size: 18), label: const Text('Chat'))),
          const SizedBox(width: 10),
          Expanded(child: OutlinedButton.icon(key: const Key('tracking-call-button'),
            onPressed: phone == null || phone.trim().isEmpty ? null : () => _call(phone),
            icon: const Icon(Icons.call_outlined, size: 18), label: const Text('Call'))),
        ]),
      ]);
    },
  ));

  Widget _locationCard(JobModel job, String peerId, AsyncSnapshot<SharedLocation?> snapshot) {
    final location = snapshot.data;
    return AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Shared location', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textDark)),
      const SizedBox(height: 8),
      const Text('Only a location deliberately shared in your chat is shown. This is not live GPS or a travel update.',
        style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
      const SizedBox(height: 12),
      if (snapshot.hasError) ...[
        const Text('Could not load shared locations.', style: TextStyle(fontSize: 13, color: AppTheme.textMuted)),
        TextButton(key: const Key('tracking-location-retry'), onPressed: () => setState(() {
          _locationStream = _watchLocation(job, peerId);
        }), child: const Text('Retry location')),
      ] else if (snapshot.connectionState == ConnectionState.waiting && location == null)
        const LoadingList(rows: 1)
      else if (location == null)
        const Text('No location shared yet. Ask the other person to share one in Chat.',
          style: TextStyle(fontSize: 13, color: AppTheme.textMuted))
      else ...[
        Text('Shared ${_date(location.sharedAt)}', style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
        Text('${location.latitude.toStringAsFixed(5)}, ${location.longitude.toStringAsFixed(5)}',
          textDirection: TextDirection.ltr, style: const TextStyle(fontSize: 13, color: AppTheme.textDark)),
        const SizedBox(height: 10),
        OutlinedButton.icon(key: const Key('tracking-shared-maps'),
          onPressed: () => _openLocation(location.latitude, location.longitude),
          icon: const Icon(Icons.location_on_outlined, size: 18), label: const Text('Open shared location in Maps')),
      ],
    ]));
  }

  Widget _stepper(JobModel job, SharedLocation? location) {
    final accepted = job.assignedAt != null || job.status == JobStatus.assigned ||
        job.status == JobStatus.inProgress || job.status == JobStatus.completed;
    final started = job.status == JobStatus.inProgress || job.status == JobStatus.completed;
    return AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Job progress', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textDark)),
      const SizedBox(height: 12),
      _step('Accepted', accepted, job.assignedAt == null ? accepted ? 'Time not recorded' : 'Pending' : _date(job.assignedAt!)),
      _step('On the way', false, location == null ? 'Travel status is not tracked' : 'Location shared, not a travel confirmation'),
      _step('In progress', started, started ? 'Start time not recorded' : 'Pending'),
      _step('Completed', job.status == JobStatus.completed,
        job.completedAt == null ? job.status == JobStatus.completed ? 'Time not recorded' : 'Pending' : _date(job.completedAt!), last: true),
    ]));
  }

  Widget _step(String label, bool reached, String detail, {bool last = false}) => Padding(
    padding: EdgeInsets.only(bottom: last ? 0 : 16),
    child: Semantics(label: '$label: $detail', child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(reached ? Icons.check_circle : Icons.radio_button_unchecked,
        size: 22, color: reached ? AppTheme.successGreen : AppTheme.textMuted),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textDark)),
        Text(detail, style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
      ])),
    ])),
  );

  String _date(DateTime value) => intl.DateFormat('d MMM yyyy, HH:mm', 'en').format(value.toLocal());
  String _statusLabel(JobStatus status) => switch (status) {
    JobStatus.open => 'Awaiting assignment', JobStatus.assigned => 'Accepted',
    JobStatus.inProgress => 'In progress', JobStatus.completed => 'Completed', JobStatus.cancelled => 'Cancelled',
  };
  Color _statusColor(JobStatus status) => switch (status) {
    JobStatus.open || JobStatus.assigned => AppTheme.brandBlue,
    JobStatus.inProgress => AppTheme.ctaOrange, JobStatus.completed => AppTheme.successGreen,
    JobStatus.cancelled => AppTheme.dangerRed,
  };
}

class _JobContact {
  final String name;
  final String? phone;
  final String? avatarUrl;
  const _JobContact(this.name, this.phone, this.avatarUrl);
}
