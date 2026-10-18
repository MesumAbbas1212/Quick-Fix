import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:quickfix/core/theme/app_theme.dart';
import 'package:quickfix/models/job_model.dart';
import 'package:quickfix/models/payment_model.dart';
import 'package:quickfix/services/local_image_store.dart';
import 'package:quickfix/services/payment_service.dart';
import 'package:quickfix/views/admin/report_screen.dart';
import 'package:quickfix/views/payments/payment_screen.dart';
import 'package:quickfix/views/reviews/review_screen.dart';

/// Client-facing job detail: status, description, images and the
/// Rate Worker flow for completed jobs.
class ClientJobDetailScreen extends StatefulWidget {
  final JobModel job;
  final String currentUserId;
  final LocalImageStore? imageStore;
  final PaymentService? paymentService;

  /// Language the reviewer is using the app in; used to tag the review's
  /// original language in the Rate Worker flow.
  final String reviewerLanguage;

  const ClientJobDetailScreen({
    super.key,
    required this.job,
    required this.currentUserId,
    this.imageStore,
    this.paymentService,
    this.reviewerLanguage = 'en',
  });

  @override
  State<ClientJobDetailScreen> createState() => _ClientJobDetailScreenState();
}

class _ClientJobDetailScreenState extends State<ClientJobDetailScreen> {
  late final LocalImageStore _imageStore =
      widget.imageStore ?? LocalImageStore();

  void _openReview() {
    final workerId = widget.job.workerId;
    if (workerId == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReviewScreen(
          jobId: widget.job.id,
          workerId: workerId,
          reviewerId: widget.currentUserId,
          reviewerLanguage: widget.reviewerLanguage,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final job = widget.job;
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
          PopupMenuButton<String>(
            key: const Key('report-menu-button'),
            tooltip: 'More options',
            icon: const Icon(Icons.more_vert, color: Colors.white, size: 20),
            onSelected: (value) {
              if (value != 'report') return;
              final workerId = widget.job.workerId;
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ReportScreen(
                    myId: widget.currentUserId,
                    // With an assigned worker the report targets the worker;
                    // for open jobs it targets the job's poster.
                    reportedId: workerId ?? widget.job.userId,
                    reportedName:
                        workerId != null ? 'the assigned worker' : 'job poster',
                    jobId: widget.job.id,
                    jobTitle: widget.job.title,
                  ),
                ),
              );
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
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
            const SizedBox(height: 14),
            _buildDescriptionCard(job),
            if (job.images.isNotEmpty) ...[
              const SizedBox(height: 14),
              _buildImagesCard(),
            ],
            if (job.status == JobStatus.completed) ...[
              const SizedBox(height: 18),
              _buildPaymentButton(job),
              const SizedBox(height: 10),
              _buildRateButton(),
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
              const Icon(Icons.category_outlined,
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
              itemCount: widget.job.images.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final path = widget.job.images[index];
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

  /// Pay CTA for completed jobs. Shows a "Paid" chip when a paid record
  /// already exists (never charge twice), otherwise a Pay button that opens
  /// [PaymentScreen].
  Widget _buildPaymentButton(JobModel job) {
    final workerId = job.workerId;
    if (workerId == null) return const SizedBox.shrink();

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
                  jobService: null,
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

  String _categoryLabel(JobCategory cat) {
    return cat.name[0].toUpperCase() +
        cat.name.substring(1).replaceAll(RegExp(r'(?<=[a-z])([A-Z])'), r' $1');
  }

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
