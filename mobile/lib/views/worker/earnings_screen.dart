import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:quickfix/core/theme/app_theme.dart';
import 'package:quickfix/core/utils/content_direction.dart';
import 'package:quickfix/core/widgets/app_card.dart';
import 'package:quickfix/core/widgets/empty_state.dart';
import 'package:quickfix/core/widgets/error_state.dart';
import 'package:quickfix/core/widgets/loading_list.dart';
import 'package:quickfix/core/widgets/weekly_earnings_chart.dart';
import 'package:quickfix/models/earnings_summary.dart';
import 'package:quickfix/models/job_model.dart';
import 'package:quickfix/models/payment_model.dart';
import 'package:quickfix/services/earnings_service.dart';
import 'package:quickfix/services/job_service.dart';
import 'package:quickfix/services/payment_service.dart';
import 'package:quickfix/views/jobs/my_jobs_screen.dart';

class EarningsScreen extends StatefulWidget {
  final String workerId;
  final JobService? jobService;
  final PaymentService? paymentService;
  final EarningsService? earningsService;
  final DateTime Function()? clock;

  const EarningsScreen({
    super.key,
    required this.workerId,
    this.jobService,
    this.paymentService,
    this.earningsService,
    this.clock,
  });

  @override
  State<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends State<EarningsScreen> {
  late final JobService _jobService = widget.jobService ?? JobService();
  late final PaymentService _paymentService = widget.paymentService ?? PaymentService();
  late final EarningsService _earningsService = widget.earningsService ?? const EarningsService();
  StreamSubscription<List<JobModel>>? _jobsSub;
  StreamSubscription<List<Payment>>? _paymentsSub;
  List<JobModel>? _jobs;
  List<Payment>? _payments;
  String? _jobError;
  String? _paymentError;
  int _generation = 0;
  EarningsPeriod _period = EarningsPeriod.month;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  void _subscribe() {
    final generation = ++_generation;
    _jobsSub?.cancel();
    _paymentsSub?.cancel();
    try {
      _jobsSub = _jobService.watchCompletedJobsForWorker(widget.workerId).listen((jobs) {
        if (!mounted || generation != _generation) return;
        setState(() { _jobs = jobs; _jobError = null; });
      }, onError: (Object _) {
        if (!mounted || generation != _generation) return;
        setState(() => _jobError = 'Could not load completed jobs. Please retry.');
      });
    } catch (_) {
      _jobError = 'Could not load completed jobs. Please retry.';
    }
    try {
      _paymentsSub = _paymentService.watchPaymentsByWorker(widget.workerId).listen((payments) {
        if (!mounted || generation != _generation) return;
        setState(() { _payments = payments; _paymentError = null; });
      }, onError: (Object _) {
        if (!mounted || generation != _generation) return;
        setState(() => _paymentError = 'Could not load payments. Please retry.');
      });
    } catch (_) {
      _paymentError = 'Could not load payments. Please retry.';
    }
  }

  void _retry() {
    setState(() {
      _jobs = null;
      _payments = null;
      _jobError = null;
      _paymentError = null;
      _subscribe();
    });
  }

  @override
  void dispose() {
    _generation++;
    _jobsSub?.cancel();
    _paymentsSub?.cancel();
    super.dispose();
  }

  void _openJobs() => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => MyJobsScreen(workerId: widget.workerId, jobService: _jobService,
            paymentService: _paymentService),
      ));

  String _money(double amount) => 'PKR ${intl.NumberFormat('#,##0', 'en_PK').format(amount)}';

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppTheme.bgLight,
        appBar: AppBar(
          backgroundColor: AppTheme.brandBlue,
          foregroundColor: AppTheme.surfaceWhite,
          title: const Text('Earnings', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          centerTitle: true,
          elevation: 0,
          actions: [IconButton(
            key: const Key('earnings-refresh-button'),
            tooltip: 'Refresh earnings', onPressed: _retry, icon: const Icon(Icons.refresh),
          )],
        ),
        body: SafeArea(child: _body()),
      );

  Widget _body() {
    final error = _paymentError ?? _jobError;
    if (error != null) return ErrorState(message: error, onRetry: _retry);
    if (_jobs == null || _payments == null) return const LoadingList(rows: 3);
    if (_jobs!.isEmpty && _payments!.isEmpty) {
      return EmptyState(
        icon: Icons.account_balance_wallet_outlined,
        title: 'Complete your first job to see earnings',
        message: 'Paid receipts appear here. Completing a job alone does not count as received income.',
        action: OutlinedButton(
          key: const Key('earnings-view-jobs'), onPressed: _openJobs,
          child: const Text('View my jobs'),
        ),
      );
    }
    final summary = _earningsService.summarize(
      workerId: widget.workerId, payments: _payments!, jobs: _jobs!,
      period: _period, now: widget.clock?.call() ?? DateTime.now(),
    );
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Row(children: [
          for (final period in EarningsPeriod.values)
            Expanded(child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: TextButton(
                key: Key('earnings-period-${period.name}'),
                onPressed: () => setState(() => _period = period),
                style: TextButton.styleFrom(
                  minimumSize: const Size(44, 44),
                  backgroundColor: _period == period ? AppTheme.brandBlue : AppTheme.surfaceWhite,
                  foregroundColor: _period == period ? AppTheme.surfaceWhite : AppTheme.brandBlue,
                ),
                child: Text(switch (period) {
                  EarningsPeriod.week => 'This week',
                  EarningsPeriod.month => 'This month',
                  EarningsPeriod.year => 'This year',
                }, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            )),
        ]),
        const SizedBox(height: 14),
        AppCard(padding: 18, child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Received this period', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(_money(summary.received), key: const Key('earnings-total'),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.brandBlue)),
            const SizedBox(height: 8),
            Text('${summary.paidJobCount} paid job${summary.paidJobCount == 1 ? '' : 's'} · '
                '${summary.completedJobCount} completed job${summary.completedJobCount == 1 ? '' : 's'}',
                style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
          ],
        )),
        const SizedBox(height: 14),
        AppCard(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Last 8 weeks', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            WeeklyEarningsChart(weeks: summary.weeks),
          ],
        )),
        const SizedBox(height: 14),
        const Text('Per-job earnings', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        if (summary.rows.isEmpty)
          EmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'No earnings in this period',
            message: 'Choose a wider period or view your jobs to check pending work.',
            action: TextButton(key: const Key('earnings-empty-period-jobs'),
                onPressed: _openJobs, child: const Text('View my jobs')),
          ),
        for (final row in summary.rows) ...[
          AppCard(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(row.title, textDirection: contentDirection(row.title),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textDark)),
              const SizedBox(height: 6),
              Text(intl.DateFormat('d MMM yyyy', 'en').format(row.date),
                  style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
              const SizedBox(height: 8),
              Text(row.status, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                  color: row.status == 'Paid' ? AppTheme.successGreen : AppTheme.textMuted)),
              const SizedBox(height: 6),
              Text(row.receiptCount > 0 ? _money(row.received) : '${_money(row.estimate)} estimated — not received',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              if (row.receiptCount > 1)
                Text('${row.receiptCount} paid receipts',
                    style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
            ],
          )),
          const SizedBox(height: 14),
        ],
        const Text('Simulated payments only. No real money is transferred.',
            style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
      ],
    );
  }
}
