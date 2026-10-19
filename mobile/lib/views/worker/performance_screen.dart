import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:quickfix/core/theme/app_theme.dart';
import 'package:quickfix/core/utils/content_direction.dart';
import 'package:quickfix/core/widgets/app_card.dart';
import 'package:quickfix/core/widgets/empty_state.dart';
import 'package:quickfix/core/widgets/error_state.dart';
import 'package:quickfix/core/widgets/loading_list.dart';
import 'package:quickfix/models/performance_report.dart';
import 'package:quickfix/services/job_service.dart';
import 'package:quickfix/services/job_request_service.dart';
import 'package:quickfix/services/performance_service.dart';
import 'package:quickfix/services/review_service.dart';
import 'package:quickfix/views/jobs/job_tracking_screen.dart';
import 'package:quickfix/views/jobs/my_jobs_screen.dart';
class PerformanceScreen extends StatefulWidget {
  final String workerId;
  final PerformanceService? performanceService;
  final JobService? jobService;
  final JobRequestService? requestService;
  final ReviewService? reviewService;
  const PerformanceScreen({super.key, required this.workerId, this.performanceService, this.jobService, this.requestService, this.reviewService});
  @override
  State<PerformanceScreen> createState() => _PerformanceScreenState();
}
class _PerformanceScreenState extends State<PerformanceScreen> {
  late final PerformanceService _service = widget.performanceService ?? PerformanceService(jobService: widget.jobService, requestService: widget.requestService, reviewService: widget.reviewService);
  late Stream<PerformanceReport> _stream = _watch();
  Stream<PerformanceReport> _watch() { try { return _service.watch(widget.workerId); } catch (error, stack) { return Stream.error(error, stack); } }
  void _retry() => setState(() { _stream = _watch(); });
  String _percent(double? value) => value == null ? 'Not enough data' : '${(value * 100).toStringAsFixed(0)}%';
  @override
  Widget build(BuildContext context) => Scaffold(backgroundColor: AppTheme.bgLight,
    appBar: AppBar(title: const Text('Performance'), actions: [IconButton(key: const Key('performance-refresh'), tooltip: 'Refresh performance', onPressed: _retry, icon: const Icon(Icons.refresh))]),
    body: SafeArea(child: StreamBuilder<PerformanceReport>(stream: _stream, builder: (context, snapshot) {
      if (snapshot.hasError) { return ErrorState(message: 'Could not load performance insights.', onRetry: _retry); }
      if (!snapshot.hasData) { return const LoadingList(); }
      final report = snapshot.data!;
      if (!report.unlocked) { return EmptyState(icon: Icons.insights_outlined, title: 'Complete 3 jobs to unlock insights', message: '${report.completedJobs} completed jobs recorded. New workers are not shown misleading 0% scores.',
        action: OutlinedButton(key: const Key('performance-my-jobs'), onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => MyJobsScreen(workerId: widget.workerId, jobService: widget.jobService))), child: const Text('View my jobs'))); }
      final metrics = <(String, double?, String)>[('Clients replied', report.replyRate, 'Decided / pending or decided applications; withdrawn excluded.'),
        ('Selected by clients', report.acceptanceRate, 'Accepted / accepted or declined applications.'), ('Completion', report.completionRate, 'Completed / completed or cancelled bookings.'),
        ('Schedule proxy', report.scheduleProxy, 'Finished by requested day/time, not arrival punctuality.')];
      return ListView(padding: const EdgeInsets.all(16), children: [
        LayoutBuilder(builder: (context, constraints) { final single = constraints.maxWidth < 420 || MediaQuery.textScalerOf(context).scale(14) > 20;
          return Wrap(spacing: 12, runSpacing: 12, children: [for (final metric in metrics) SizedBox(width: single ? constraints.maxWidth : (constraints.maxWidth - 12) / 2,
            child: AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(metric.$1, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8), Text(_percent(metric.$2), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppTheme.brandBlue)),
              const SizedBox(height: 8), Text(metric.$3, style: const TextStyle(fontSize: 12, color: AppTheme.textMuted))])))]);
        }), const SizedBox(height: 14), AppCard(child: Text('Average rating received: ${report.averageRating?.toStringAsFixed(1) ?? 'Not rated'}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
        const SizedBox(height: 14), AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('What to improve', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)), const SizedBox(height: 8),
          Text(report.suggestion, style: const TextStyle(fontSize: 13, color: AppTheme.textMuted))])),
        const SizedBox(height: 16), const Text('Recent activity', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        for (final activity in report.activity) ListTile(title: Text(activity.title, textDirection: contentDirection(activity.title)), subtitle: Text('${activity.status} • ${activity.date == null ? 'Date unavailable' : intl.DateFormat('d MMM yyyy', 'en').format(activity.date!)}'),
          trailing: activity.jobId == null ? null : const Icon(Icons.chevron_right), onTap: activity.jobId == null ? null : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => JobTrackingScreen(jobId: activity.jobId!, myId: widget.workerId, jobService: widget.jobService)))),
      ]);
    })),
  );
}
