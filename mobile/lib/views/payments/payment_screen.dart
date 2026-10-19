import 'package:quickfix/core/widgets/job_dispute_link.dart';
import 'package:flutter/material.dart';
import 'package:quickfix/core/theme/app_theme.dart';
import 'package:quickfix/core/widgets/error_state.dart';
import 'package:quickfix/core/widgets/empty_state.dart';
import 'package:quickfix/core/widgets/user_avatar.dart';
import 'package:quickfix/models/job_model.dart';
import 'package:quickfix/models/payment_model.dart';
import 'package:quickfix/models/worker_profile.dart';
import 'package:quickfix/services/job_service.dart';
import 'package:quickfix/services/payment_service.dart';
import 'package:quickfix/services/profile_service.dart';
import 'package:quickfix/services/review_service.dart';
import 'package:quickfix/views/reviews/review_screen.dart';

/// Simulated payment for a completed job: the real entry point for the
/// payments loop. Shows the agreed amount with a 0 % platform fee, a
/// "Cash on completion" method plus a disabled card row, and a clear
/// simulation disclaimer. Never charges twice: an existing paid record
/// renders the receipt state instead of the form.
class PaymentScreen extends StatefulWidget {
  final String jobId;

  /// The paying client.
  final String myId;

  final JobService? jobService;
  final PaymentService? paymentService;
  final ProfileService? profileService;
  final ReviewService? reviewService;

  /// Language code of the paying client, forwarded to the review flow.
  final String reviewerLanguage;

  const PaymentScreen({
    super.key,
    required this.jobId,
    required this.myId,
    this.jobService,
    this.paymentService,
    this.profileService,
    this.reviewService,
    this.reviewerLanguage = 'en',
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  late final JobService _jobService = widget.jobService ?? JobService();
  late final PaymentService _paymentService =
      widget.paymentService ?? PaymentService();
  late final ProfileService _profileService =
      widget.profileService ?? ProfileService();
  late final ReviewService? _reviewService = widget.reviewService;
  late Stream<JobModel?> _jobStream = _watchJob();

  Future<Payment?>? _existingPayment;
  bool _paying = false;

  Stream<JobModel?> _watchJob() {
    try { return _jobService.watchJob(widget.jobId); }
    catch (error, stack) { return Stream<JobModel?>.error(error, stack); }
  }

  Future<Payment?> _loadPayment() async => _paymentService
      .getPaidPaymentForJob(widget.jobId).timeout(const Duration(seconds: 10));

  Future<void> _confirmPayment(JobModel job) async {
    final workerId = job.workerId;
    if (workerId == null || _paying) { return; }
    setState(() => _paying = true);
    try {
      final payment = await _paymentService.simulatePayment(
        jobId: job.id,
        payerId: widget.myId,
        workerId: workerId,
        amount: job.budgetMax,
      );
      if (!mounted) { return; }
      setState(() {
        _paying = false;
        _existingPayment = Future.value(payment);
      });
    } catch (_) {
      if (!mounted) { return; }
      setState(() {
        _paying = false;
        // A receipt may have committed before the job-status write failed.
        // Re-read before presenting another confirmation action.
        _existingPayment = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment could not be processed. Please try again.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  String _pk(double value) {
    final n = value.toStringAsFixed(0);
    final buffer = StringBuffer();
    for (var i = 0; i < n.length; i++) {
      if (i > 0 && (n.length - i) % 3 == 0) { buffer.write(','); }
      buffer.write(n[i]);
    }
    return 'PKR $buffer';
  }

  String _dateLabel(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
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
          'Payment',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: StreamBuilder<JobModel?>(
          stream: _jobStream,
          builder: (context, jobSnapshot) {
            if (jobSnapshot.hasError) {
              return ErrorState(
                message: 'Could not load the job. Check your connection.',
                onRetry: () => setState(() { _jobStream = _watchJob(); }),
              );
            }
            if (jobSnapshot.connectionState == ConnectionState.waiting && !jobSnapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.brandBlue,
                ),
              );
            }
            final job = jobSnapshot.data;
            if (job == null) { return EmptyState(icon: Icons.work_off_outlined,
              title: 'Job unavailable', message: 'This job may have been removed. Retry or go back to your jobs.',
              action: OutlinedButton(onPressed: () => setState(() { _jobStream = _watchJob(); }), child: const Text('Reload job'))); }
            if (job.userId != widget.myId) { return const ErrorState(message: 'Only the client who posted this job can pay.'); }
            return FutureBuilder<Payment?>(
              // Start only once a valid job renders this builder; its listener
              // is attached immediately, including for synchronous read errors.
              future: _existingPayment ??= _loadPayment(),
              builder: (context, paymentSnapshot) {
                if (paymentSnapshot.hasError) {
                  return ErrorState(
                    message: 'Could not load payment status.',
                    onRetry: () => setState(() {
                      _existingPayment = null;
                    }),
                  );
                }
                if (paymentSnapshot.connectionState != ConnectionState.done) {
                  return const Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.brandBlue,
                    ),
                  );
                }
                final paid = paymentSnapshot.data;
                if (paid != null) {
                  return _buildReceipt(job, paid);
                }
                if (job.status != JobStatus.completed) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text(
                        'Payment becomes available once the job is '
                        'completed.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ),
                  );
                }
                return _buildForm(job);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _card(Widget child) {
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
      child: child,
    );
  }

  Widget _jobSummary(JobModel job) {
    final workerId = job.workerId;
    return _card(
      StreamBuilder<WorkerProfile?>(
        stream: workerId == null
            ? const Stream<WorkerProfile?>.empty()
            : _profileService.watchWorkerProfile(workerId),
        builder: (context, snapshot) {
          final worker = snapshot.data;
          return Row(
            children: [
              UserAvatar(
                fullName: worker?.fullName ?? 'Worker',
                avatarUrl: worker?.avatarUrl,
                size: 48,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      job.title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textDark,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${worker?.fullName ?? 'Worker'} · '
                      '${_dateLabel(job.completedAt ?? job.updatedAt)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.successGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Completed',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.successGreen,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _breakdown(JobModel job) {
    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Amount',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 10),
          _breakdownRow('Labour (agreed amount)', _pk(job.budgetMax)),
          const SizedBox(height: 6),
          _breakdownRow('Platform fee', 'PKR 0 (0% — for now)'),
          const Divider(height: 18, color: AppTheme.borderGray),
          Row(
            children: [
              const Text(
                'Total',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textDark,
                ),
              ),
              const Spacer(),
              Text(
                _pk(job.budgetMax),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _breakdownRow(String label, String value) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppTheme.textDark,
          ),
        ),
      ],
    );
  }

  Widget _methods() {
    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Payment method',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 10),
          Material(type: MaterialType.transparency, child: RadioGroup<String>(groupValue: 'cash', onChanged: (_) {}, child: RadioListTile<String>(
            key: const Key('method-cash'),
            dense: true,
            contentPadding: EdgeInsets.zero,
            value: 'cash',
            title: const Text(
              'Cash on completion',
              style: TextStyle(fontSize: 13, color: AppTheme.textDark),
            ),
          ))),
          const Divider(height: 1, color: AppTheme.borderGray),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                const Icon(Icons.credit_card,
                    size: 18, color: AppTheme.textMuted),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Card / JazzCash — coming soon',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.textMuted.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm(JobModel job) {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        _jobSummary(job),
        const SizedBox(height: 14),
        _breakdown(job),
        const SizedBox(height: 14),
        _methods(),
        const SizedBox(height: 14),
        _card(
          const Row(
            children: [
              Icon(Icons.info_outline, size: 18, color: AppTheme.ctaOrange),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'This is a simulated payment for the FYP demo — no real '
                  'money moves.',
                  style: TextStyle(fontSize: 12, color: AppTheme.textDark),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        SizedBox(
          height: 52,
          child: ElevatedButton(
            key: const Key('confirm-payment-button'),
            onPressed:
                _paying || job.workerId == null ? null : () => _confirmPayment(job),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.ctaOrange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _paying
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    'Confirm payment · ${_pk(job.budgetMax)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildReceipt(JobModel job, Payment payment) {
    final workerId = job.workerId;
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        _card(
          Column(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppTheme.successGreen.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check,
                    size: 28, color: AppTheme.successGreen),
              ),
              const SizedBox(height: 14),
              const Text(
                'Payment complete',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${_pk(payment.amount)} · ${_dateLabel(payment.createdAt)}',
                style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.bgLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.borderGray),
                ),
                child: Column(
                  children: [
                    _receiptRow('Job', job.title),
                    const SizedBox(height: 6),
                    _receiptRow('Amount', _pk(payment.amount)),
                    const SizedBox(height: 6),
                    _receiptRow('Platform fee', 'PKR 0 (0%)'),
                    const SizedBox(height: 6),
                    _receiptRow('Method', 'Cash on completion'),
                    const SizedBox(height: 6),
                    _receiptRow('Reference', 'MOCK-${payment.id}'),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (!job.anonymized) JobDisputeLink(jobId: job.id, userId: widget.myId, jobService: widget.jobService, paymentService: widget.paymentService),
        if (workerId != null) ...[
          const SizedBox(height: 18),
          SizedBox(
            key: const Key('rate-worker-button'),
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ReviewScreen(
                    jobId: job.id,
                    workerId: workerId,
                    reviewerId: widget.myId,
                    reviewService: _reviewService,
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
              icon: const Icon(Icons.star_outline, size: 18),
              label: const Text(
                'Rate this worker',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _receiptRow(String label, String value) {
    return Row(
      children: [
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.textMuted,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 12, color: AppTheme.textDark),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

