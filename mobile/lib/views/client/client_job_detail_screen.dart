import 'package:quickfix/core/widgets/job_dispute_link.dart';
import 'package:quickfix/views/jobs/reschedule_job_screen.dart';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:quickfix/core/theme/app_theme.dart';
import 'package:quickfix/core/utils/content_direction.dart';
import 'package:quickfix/core/widgets/job_category_icons.dart';
import 'package:quickfix/models/job_model.dart';
import 'package:quickfix/models/payment_model.dart';
import 'package:quickfix/services/job_request_service.dart';
import 'package:quickfix/services/job_service.dart';
import 'package:quickfix/services/auth_service.dart';
import 'package:quickfix/services/chat_service.dart';
import 'package:quickfix/services/map_launcher.dart';
import 'package:quickfix/services/review_service.dart';
import 'package:quickfix/views/jobs/job_tracking_screen.dart';
import 'package:quickfix/services/profile_service.dart';
import 'package:quickfix/services/local_image_store.dart';
import 'package:quickfix/services/payment_service.dart';
import 'package:quickfix/views/admin/report_screen.dart';
import 'package:quickfix/views/jobs/job_applicants_screen.dart';
import 'package:quickfix/views/payments/payment_screen.dart';
import 'package:quickfix/views/reviews/review_screen.dart';

/// Client-facing job detail: status, description, images and the
/// Rate Worker flow for completed jobs.
class ClientJobDetailScreen extends StatefulWidget {
  final JobModel job;
  final String currentUserId;
  final LocalImageStore? imageStore;
  final PaymentService? paymentService;
  final JobRequestService? jobRequestService;
  final JobService? jobService;
  final ProfileService? profileService;
  final AuthService? authService;
  final ChatService? chatService;
  final UrlLauncher? urlLauncher;
  final ReviewService? reviewService;

  /// Language the reviewer is using the app in; used to tag the review's
  /// original language in the Rate Worker flow.
  final String reviewerLanguage;

  const ClientJobDetailScreen({
    super.key,
    required this.job,
    required this.currentUserId,
    this.imageStore,
    this.paymentService,
    this.jobRequestService,
    this.jobService,
    this.profileService,
    this.authService,
    this.chatService,
    this.urlLauncher,
    this.reviewService,
    this.reviewerLanguage = 'en',
  });

  @override
  State<ClientJobDetailScreen> createState() => _ClientJobDetailScreenState();
}

class _ClientJobDetailScreenState extends State<ClientJobDetailScreen> {
  late final LocalImageStore _imageStore =
      widget.imageStore ?? LocalImageStore();
  late final JobRequestService _jobRequestService =
      widget.jobRequestService ?? JobRequestService();
  late final JobService _jobService = widget.jobService ?? JobService();
  late JobModel _job = widget.job;
  late Stream<int>? _applicantCount = _job.status == JobStatus.open &&
          _job.userId == widget.currentUserId
      ? _watchApplicantCount()
      : null;

  @override
  void didUpdateWidget(covariant ClientJobDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.job != widget.job) {
      _job = widget.job;
      _applicantCount = _job.status == JobStatus.open && _job.userId == widget.currentUserId
          ? _watchApplicantCount() : null;
    }
  }

  Stream<int> _watchApplicantCount() {
    try {
      return _jobRequestService.watchPendingCountForJob(_job.id);
    } catch (error, stack) {
      return Stream<int>.error(error, stack);
    }
  }

  Future<void> _openApplicants() async {
    await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => JobApplicantsScreen(
        jobId: _job.id,
        myId: widget.currentUserId,
        jobRequestService: widget.jobRequestService,
        jobService: widget.jobService,
        profileService: widget.profileService,
      ),
    ));
    if (!mounted) { return; }
    try {
      final latest = await _jobService.getJob(_job.id);
      if (!mounted || latest == null) { return; }
      setState(() {
        _job = latest;
        _applicantCount = latest.status == JobStatus.open ? _watchApplicantCount() : null;
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not refresh the job. Reopen it to see the latest status.'),
        ));
      }
    }
  }

  Future<void> _openTracking() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => JobTrackingScreen(
      jobId: _job.id, myId: widget.currentUserId, jobService: widget.jobService,
      profileService: widget.profileService, authService: widget.authService,
      chatService: widget.chatService, urlLauncher: widget.urlLauncher,
      paymentService: widget.paymentService, reviewService: widget.reviewService,
      reviewerLanguage: widget.reviewerLanguage,
    )));
    if (!mounted) { return; }
    try {
      final latest = await _jobService.getJob(_job.id).timeout(const Duration(seconds: 10));
      if (mounted && latest != null) { setState(() { _job = latest; }); }
    } catch (_) {
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Could not refresh the job. Reopen it to see the latest status.'))); }
    }
  }

  void _openReview() {
    final workerId = _job.workerId;
    if (workerId == null) { return; }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReviewScreen(
          jobId: _job.id,
          workerId: workerId,
          reviewerId: widget.currentUserId,
          reviewerLanguage: widget.reviewerLanguage,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final job = _job;
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(
        backgroundColor: AppTheme.brandBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Job Details',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        actions: [
          if (!job.anonymized) PopupMenuButton<String>(
            key: const Key('report-menu-button'),
            tooltip: 'More options',
            icon: const Icon(Icons.more_vert, color: Colors.white, size: 20),
            onSelected: (value) {
              if (value == 'schedule') { Navigator.of(context).push(MaterialPageRoute(builder: (_) => RescheduleJobScreen(jobId: job.id, userId: widget.currentUserId, jobService: widget.jobService))); return; }
              if (value != 'report') { return; }
              final workerId = _job.workerId;
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ReportScreen(
                    myId: widget.currentUserId,
                    // With an assigned worker the report targets the worker;
                    // for open jobs it targets the job's poster.
                    reportedId: workerId ?? _job.userId,
                    reportedName:
                        workerId != null ? 'the assigned worker' : 'job poster',
                    jobId: _job.id,
                    jobTitle: _job.title,
                  ),
                ),
              );
            },
            itemBuilder: (context) => [
              if (job.userId == widget.currentUserId && (job.status == JobStatus.assigned || job.status == JobStatus.inProgress))
                const PopupMenuItem(value: 'schedule', child: Text('Reschedule or cancel')),
              const PopupMenuItem(
                value: 'report',
                child: Text('Report an issue with this job'),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(14),
          children: [
            _buildHeaderCard(job),
            if (job.workerId != null && job.userId == widget.currentUserId) ...[
              const SizedBox(height: 14),
              OutlinedButton.icon(key: const Key('client-job-tracking-button'),
                onPressed: _openTracking, icon: const Icon(Icons.route_outlined, size: 20),
                label: const Text('Track job')),
            ],
            if (_showsApplicants(job)) ...[
              const SizedBox(height: 14),
              _buildApplicantsCard(job),
            ],
            const SizedBox(height: 14),
            _buildDescriptionCard(job),
            if (job.images.isNotEmpty) ...[
              const SizedBox(height: 14),
              _buildImagesCard(),
            ],
            if (job.anonymized) const Padding(padding: EdgeInsets.only(top: 16), child: Text('Anonymized completed history. The other account and identifying job details were removed.',
              style: TextStyle(fontSize: 13, color: AppTheme.textMuted))),
            if (job.status == JobStatus.completed && !job.anonymized) ...[
              const SizedBox(height: 18),
              _buildPaymentButton(job),
              const SizedBox(height: 10),
              _buildRateButton(),
              if (job.userId == widget.currentUserId || job.workerId == widget.currentUserId) JobDisputeLink(jobId: job.id, userId: widget.currentUserId, jobService: widget.jobService, paymentService: widget.paymentService),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard(JobModel job) {
    return Container(
      padding: const EdgeInsets.all(16),
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
          Row(
            children: [
              Expanded(
                child: Text(
                  job.title,
                  textDirection: contentDirection(job.title),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textDark,
                  ),
                ),
              ),
              _statusChip(job.status),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(jobCategoryIcon(job.category),
                  size: 13, color: AppTheme.textMuted),
              const SizedBox(width: 4),
              Text(
                _categoryLabel(job.category),
                style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
              ),
              const Spacer(),
              const Icon(Icons.location_on_outlined,
                  size: 13, color: AppTheme.textMuted),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  job.address,
                  textDirection: contentDirection(job.address),
                  style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Text(
                'Budget',
                style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.brandBlue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'PKR ${_formatBudget(job.budgetMin)}-${_formatBudget(job.budgetMax)}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.brandBlue,
                  ),
                ),
              ),
              const Spacer(),
              const Icon(Icons.event, size: 13, color: AppTheme.textMuted),
              const SizedBox(width: 4),
              Text(
                _dateLabel(job.preferredDate),
                style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionCard(JobModel job) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderGray),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Description',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            job.description,
            style: const TextStyle(fontSize: 12, color: AppTheme.textDark),
          ),
        ],
      ),
    );
  }

  Widget _buildImagesCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderGray),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Photos',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 120,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _job.images.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final path = _job.images[index];
                return FutureBuilder<Uint8List?>(
                  future: _imageStore.readImage(path),
                  builder: (context, snapshot) {
                    if (snapshot.data == null) {
                      return const SizedBox.shrink();
                    }
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(
                        snapshot.data!,
                        width: 140,
                        height: 120,
                        fit: BoxFit.cover,
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Assigned jobs keep a route to the confirmed-worker card as well.
  bool _showsApplicants(JobModel job) =>
      job.userId == widget.currentUserId && job.status != JobStatus.cancelled;

  Widget _buildApplicantsCard(JobModel job) {
    return StreamBuilder<int>(
      stream: job.status == JobStatus.open ? _applicantCount : null,
      builder: (context, snapshot) {
        final label = job.status != JobStatus.open
            ? 'View confirmed worker'
            : snapshot.hasData
                ? 'View ${snapshot.data} applicants'
                : 'View applicants';
        return Material(
          color: AppTheme.surfaceWhite,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            key: const Key('view-applicants-button'),
            borderRadius: BorderRadius.circular(20),
            onTap: _openApplicants,
            child: Container(
              constraints: const BoxConstraints(minHeight: 44),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
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
              child: Row(
                children: [
                  const Icon(Icons.groups_outlined, color: AppTheme.brandBlue),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label,
                            style: const TextStyle(fontSize: 13,
                                fontWeight: FontWeight.w700, color: AppTheme.textDark)),
                        if (job.status == JobStatus.open && snapshot.hasError)
                          const Text('Count unavailable — tap to retry on the applicants page',
                              style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: AppTheme.textMuted),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Pay CTA for completed jobs; already-paid records never charge twice.
  Widget _buildPaymentButton(JobModel job) {
    final workerId = job.workerId;
    if (workerId == null) { return const SizedBox.shrink(); }

    // Resolve the service without crashing in environments where Firestore
    // is unavailable (widget tests); fall back to "unpaid" in that case.
    late final Future<List<Payment>> payments;
    try {
      final service = widget.paymentService ?? PaymentService();
      payments = service.getPaymentsForJob(job.id);
    } catch (_) {
      payments = Future.value(const <Payment>[]);
    }

    return FutureBuilder<List<Payment>>(
      future: payments,
      builder: (context, snapshot) {
        if (snapshot.hasError || !snapshot.hasData) {
          return const SizedBox.shrink();
        }
        final paid = snapshot.data!.any((p) => p.status == 'paid');
        if (paid) {
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.successGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.successGreen),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle, size: 18, color: AppTheme.successGreen),
                SizedBox(width: 8),
                Text(
                  'Paid',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.successGreen,
                  ),
                ),
              ],
            ),
          );
        }
        return SizedBox(
          key: const Key('pay-job-button'),
          height: 52,
          child: ElevatedButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => PaymentScreen(
                  jobId: job.id,
                  myId: widget.currentUserId,
                  jobService: widget.jobService,
                  paymentService: widget.paymentService,
                  reviewService: null,
                  reviewerLanguage: widget.reviewerLanguage,
                ),
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.ctaOrange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.payment_outlined, size: 18),
            label: Text(
              'Pay · PKR ${job.budgetMax.toStringAsFixed(0)}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRateButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        onPressed: _openReview,
        icon: const Icon(Icons.star, size: 18),
        label: const Text(
          'Rate Worker',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.successGreen,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
    );
  }

  Widget _statusChip(JobStatus status) {
    final (color, label) = switch (status) {
      JobStatus.open => (AppTheme.brandBlue, 'Open'),
      JobStatus.assigned => (AppTheme.ctaOrange, 'Assigned'),
      JobStatus.inProgress => (AppTheme.accentYellow, 'In Progress'),
      JobStatus.completed => (AppTheme.successGreen, 'Completed'),
      JobStatus.cancelled => (AppTheme.dangerRed, 'Cancelled'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  String _categoryLabel(JobCategory cat) => jobCategoryLabel(cat);

  String _formatBudget(double budget) {
    if (budget >= 1000) {
      final k = budget / 1000;
      return '${k == k.roundToDouble() ? k.toStringAsFixed(0) : k.toStringAsFixed(1)}k';
    }
    return budget.toStringAsFixed(0);
  }

  String _dateLabel(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}
