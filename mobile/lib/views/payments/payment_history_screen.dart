import 'package:flutter/material.dart';
import 'package:quickfix/core/theme/app_theme.dart';
import 'package:quickfix/core/widgets/empty_state.dart';
import 'package:quickfix/core/widgets/error_state.dart';
import 'package:quickfix/core/widgets/loading_list.dart';
import 'package:quickfix/core/widgets/section_header.dart';
import 'package:quickfix/models/job_model.dart';
import 'package:quickfix/models/payment_model.dart';
import 'package:quickfix/models/user_model.dart';
import 'package:quickfix/services/auth_service.dart';
import 'package:quickfix/services/job_service.dart';
import 'package:quickfix/services/payment_service.dart';
import 'package:quickfix/services/profile_service.dart';
import 'package:quickfix/views/jobs/post_job_screen.dart';

/// Receipts for clients (payments they made) and income evidence for
/// workers (payments made to them). Month-grouped, with a summary card
/// (this month + lifetime) and a tap-through receipt sheet.
class PaymentHistoryScreen extends StatefulWidget {
  final UserModel user;

  final PaymentService? paymentService;
  final JobService? jobService;
  final ProfileService? profileService;
  final AuthService? authService;

  const PaymentHistoryScreen({
    super.key,
    required this.user,
    this.paymentService,
    this.jobService,
    this.profileService,
    this.authService,
  });

  @override
  State<PaymentHistoryScreen> createState() => _PaymentHistoryScreenState();
}

class _PaymentHistoryScreenState extends State<PaymentHistoryScreen> {
  late final PaymentService _paymentService =
      widget.paymentService ?? PaymentService();
  late final JobService _jobService = widget.jobService ?? JobService();
  late final ProfileService _profileService =
      widget.profileService ?? ProfileService();
  late final AuthService _authService = widget.authService ?? AuthService();

  /// Job-title and counterparty-name lookups, cached so repeated stream
  /// emissions don't re-fetch the same documents.
  final Map<String, JobModel?> _jobCache = {};
  final Map<String, String?> _nameCache = {};
  bool _isRefreshing = false;

  bool get _isWorker => widget.user.role == UserRole.worker;

  Stream<List<Payment>> get _paymentsStream => _isWorker
      ? _paymentService.watchPaymentsByWorker(widget.user.uid)
      : _paymentService.watchPaymentsByPayer(widget.user.uid);

  static const List<String> _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  String _monthKey(DateTime d) => '${d.year}-${d.month}';

  String _monthLabel(DateTime d) => '${_months[d.month - 1]} ${d.year}';

  String _dateLabel(DateTime d) {
    final short = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${d.day} ${short[d.month - 1]} ${d.year}';
  }

  String _pk(double value) {
    final n = value.toStringAsFixed(0);
    final buffer = StringBuffer();
    for (var i = 0; i < n.length; i++) {
      if (i > 0 && (n.length - i) % 3 == 0) buffer.write(',');
      buffer.write(n[i]);
    }
    return 'PKR $buffer';
  }

  /// Fetches the job + counterparty name for payments missing from the
  /// caches; resolves to the (possibly enriched) payment list.
  Future<List<Payment>> _enrich(List<Payment> payments) async {
    for (final payment in payments) {
      if (!_jobCache.containsKey(payment.jobId)) {
        try {
          _jobCache[payment.jobId] = await _jobService.getJob(payment.jobId);
        } catch (_) {
          _jobCache[payment.jobId] = null;
        }
      }
      final counterId =
          _isWorker ? payment.payerId : payment.workerId;
      if (counterId.isNotEmpty &&
          !_nameCache.containsKey(counterId)) {
        try {
          if (_isWorker) {
            final client = await _authService.getUserProfile(counterId);
            _nameCache[counterId] = client?.fullName;
          } else {
            final worker = await _profileService.getWorkerProfile(counterId);
            _nameCache[counterId] = worker?.fullName;
          }
        } catch (_) {
          _nameCache[counterId] = null;
        }
      }
    }
    return payments;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(
        backgroundColor: AppTheme.brandBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          _isWorker ? 'Earnings' : 'Payments',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            key: const Key('payments-refresh-button'),
            icon: const Icon(Icons.refresh, size: 20),
            tooltip: 'Refresh',
            onPressed: _isRefreshing
                ? null
                : () {
                    _jobCache.clear();
                    _nameCache.clear();
                    setState(() => _isRefreshing = true);
                    Future.delayed(const Duration(milliseconds: 300), () {
                      if (mounted) setState(() => _isRefreshing = false);
                    });
                  },
          ),
        ],
      ),
      body: SafeArea(
        child: StreamBuilder<List<Payment>>(
          stream: _paymentsStream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return ErrorState(
                message: 'Could not load payments. Check your connection.',
                onRetry: () => setState(() {}),
              );
            }
            if (!snapshot.hasData) {
              return const LoadingList();
            }
            final payments = snapshot.data!;
            if (payments.isEmpty) {
              return _buildEmpty();
            }
            return FutureBuilder<List<Payment>>(
              future: _enrich(payments),
              builder: (context, enriched) {
                if (!enriched.hasData) return const LoadingList();
                return ListView(
                  padding: const EdgeInsets.all(14),
                  children: [
                    _buildSummaryCard(enriched.data!),
                    const SizedBox(height: 14),
                    ..._buildMonthSections(enriched.data!),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    if (_isWorker) {
      return EmptyState(
        icon: Icons.work_outline,
        title: 'No earnings yet',
        message: 'Complete your first job to see payments here. Job requests '
            'arrive on your dashboard — accept one to get started.',
        action: TextButton(
          key: const Key('go-dashboard-cta'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            'Go to dashboard',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.brandBlue,
            ),
          ),
        ),
      );
    }
    return EmptyState(
      icon: Icons.receipt_long_outlined,
      title: 'No payments yet',
      message: 'When you pay for a completed job, the receipt appears here.',
      action: TextButton(
        key: const Key('post-job-cta'),
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PostJobScreen(userId: widget.user.uid),
          ),
        ),
        child: const Text(
          'Post a job',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppTheme.brandBlue,
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(List<Payment> payments) {
    final now = DateTime.now();
    final thisMonth = payments
        .where((p) => _monthKey(p.createdAt) == _monthKey(now))
        .fold(0.0, (sum, p) => sum + p.amount);
    final lifetime = payments.fold(0.0, (sum, p) => sum + p.amount);
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
        children: [
          Expanded(
            child: Column(
              children: [
                const Text(
                  'This month',
                  style:
                      TextStyle(fontSize: 12, color: AppTheme.textMuted),
                ),
                const SizedBox(height: 4),
                Text(
                  _pk(thisMonth),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textDark,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          const Divider(
            height: 32,
            color: AppTheme.borderGray,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              children: [
                Text(
                  _isWorker ? 'Total earned' : 'Total paid',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textMuted,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _pk(lifetime),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textDark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Groups the (newest-first) payments by month, preserving order.
  List<(String, List<Payment>)> _grouped(List<Payment> payments) {
    final labels = <String, String>{};
    final groups = <String, List<Payment>>{};
    final order = <String>[];
    for (final p in payments) {
      final key = _monthKey(p.createdAt);
      if (!groups.containsKey(key)) {
        groups[key] = [];
        labels[key] = _monthLabel(p.createdAt);
        order.add(key);
      }
      groups[key]!.add(p);
    }
    return [for (final key in order) (labels[key]!, groups[key]!)];
  }

  List<Widget> _buildMonthSections(List<Payment> payments) {
    final sections = <Widget>[];
    for (final (label, monthPayments) in _grouped(payments)) {
      sections.add(
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.only(left: 4, top: 10, bottom: 8),
            child: SectionHeader(title: label),
          ),
        ),
      );
      sections.add(
        Container(
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
              for (var i = 0; i < monthPayments.length; i++) ...[
                if (i > 0)
                  const Divider(
                    height: 1,
                    indent: 14,
                    endIndent: 14,
                    color: AppTheme.borderGray,
                  ),
                _ReceiptRow(
                  payment: monthPayments[i],
                  job: _jobCache[monthPayments[i].jobId],
                  counterName: _nameCache[
                      _isWorker
                          ? monthPayments[i].payerId
                          : monthPayments[i].workerId],
                  isWorker: _isWorker,
                  dateLabel: _dateLabel(monthPayments[i].createdAt),
                  amountLabel: _pk(monthPayments[i].amount),
                  onTap: () => _showReceipt(monthPayments[i]),
                ),
              ],
            ],
          ),
        ),
      );
    }
    return sections;
  }

  void _showReceipt(Payment payment) {
    final job = _jobCache[payment.jobId];
    final counter = _nameCache[_isWorker ? payment.payerId : payment.workerId];
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                color: AppTheme.borderGray,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Receipt',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 12),
            _receiptRow('Job', job?.title ?? '—'),
            const SizedBox(height: 8),
            _receiptRow(
              _isWorker ? 'Client' : 'Worker',
              counter ?? '—',
            ),
            const SizedBox(height: 8),
            _receiptRow('Date', _dateLabel(payment.createdAt)),
            const SizedBox(height: 8),
            _receiptRow('Amount', _pk(payment.amount)),
            const SizedBox(height: 8),
            _receiptRow('Platform fee', 'PKR 0 (0%)'),
            const SizedBox(height: 8),
            _receiptRow('Method', 'Cash on completion'),
            const SizedBox(height: 8),
            _receiptRow('Reference', 'MOCK-${payment.id}'),
            const SizedBox(height: 16),
            Text(
              'Status: ${payment.status.toUpperCase()}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppTheme.successGreen,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _receiptRow(String label, String value) {
    return Row(
      children: [
        SizedBox(
          width: 100,
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
          ),
        ),
      ],
    );
  }
}

/// One receipt row in the month-grouped list.
class _ReceiptRow extends StatelessWidget {
  final Payment payment;
  final JobModel? job;
  final String? counterName;
  final bool isWorker;
  final String dateLabel;
  final String amountLabel;
  final VoidCallback onTap;

  const _ReceiptRow({
    required this.payment,
    required this.job,
    required this.counterName,
    required this.isWorker,
    required this.dateLabel,
    required this.amountLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppTheme.brandBlue.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.receipt_long,
                  size: 18, color: AppTheme.brandBlue),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    job?.title ?? 'Job',
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
                    '${isWorker ? 'Client' : 'Worker'}: $counterName · $dateLabel',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textMuted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  amountLabel,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.successGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    payment.status.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.successGreen,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
