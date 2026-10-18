import 'package:flutter/material.dart';
import 'package:quickfix/core/theme/app_theme.dart';
import 'package:quickfix/core/widgets/error_state.dart';
import 'package:quickfix/core/widgets/loading_list.dart';
import 'package:quickfix/core/widgets/rank_badge.dart';
import 'package:quickfix/models/job_model.dart';
import 'package:quickfix/models/worker_rank.dart';
import 'package:quickfix/services/job_service.dart';

/// Read-only rank history. Zero completions is valid data, not an absent
/// profile: the worker still sees the entire ladder and its first target.
class RankProgressScreen extends StatefulWidget {
  final String workerUid;
  final JobService? jobService;

  /// Allows deterministic rolling-window tests without changing the rank engine.
  final DateTime Function()? clock;

  const RankProgressScreen({
    super.key,
    required this.workerUid,
    this.jobService,
    this.clock,
  });

  @override
  State<RankProgressScreen> createState() => _RankProgressScreenState();
}

class _RankProgressScreenState extends State<RankProgressScreen> {
  late final JobService _jobService = widget.jobService ?? JobService();
  late Stream<List<JobModel>> _completedJobs;

  @override
  void initState() {
    super.initState();
    _completedJobs = _watchCompletions();
  }

  Stream<List<JobModel>> _watchCompletions() {
    try {
      return _jobService.watchCompletedJobsForWorker(widget.workerUid);
    } catch (error, stack) {
      return Stream<List<JobModel>>.error(error, stack);
    }
  }

  void _retry() => setState(() => _completedJobs = _watchCompletions());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(
        backgroundColor: AppTheme.brandBlue,
        foregroundColor: AppTheme.surfaceWhite,
        title: const Text(
          'Rank progress',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        elevation: 0,
        centerTitle: true,
      ),
      body: SafeArea(
        child: StreamBuilder<List<JobModel>>(
          stream: _completedJobs,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return ErrorState(
                message: 'Could not load rank progress. Check your connection.',
                onRetry: _retry,
              );
            }
            if (!snapshot.hasData) return const LoadingList(rows: 3);
            final count = WorkerRank.countCompletedInYear(
              snapshot.data!
                  .where((job) => job.status == JobStatus.completed)
                  .map((job) => job.completedAt ?? job.updatedAt),
              now: widget.clock?.call() ?? DateTime.now(),
            );
            return ListView(
              padding: const EdgeInsets.all(14),
              children: [
                _hero(count),
                const SizedBox(height: 14),
                _progress(count),
                const SizedBox(height: 14),
                _ladder(count),
                const SizedBox(height: 14),
                _explainer(),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _card({required Widget child}) => Container(
        padding: const EdgeInsets.all(18),
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
        child: child,
      );

  Widget _hero(int count) {
    final rank = WorkerRank.forCompletedInYear(count);
    return _card(
      child: Column(
        children: [
          RankEmblem(rank: rank, size: 64),
          const SizedBox(height: 14),
          Text(
            rank.name,
            key: const Key('current-rank-name'),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: rank.color,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$count job${count == 1 ? '' : 's'} completed in the last 12 months',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
          ),
          if (count == 0) ...[
            const SizedBox(height: 10),
            const Text(
              'Every completed job is a step up the ladder.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
            ),
            TextButton(
              key: const Key('rank-back-button'),
              onPressed: () => Navigator.of(context).maybePop(),
              child: const Text('Back to profile'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _progress(int count) {
    final rank = WorkerRank.forCompletedInYear(count);
    final next = rank.nextRank;
    if (next == null) {
      return _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Highest rank reached',
              key: const Key('rank-maxed-out'),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: rank.color,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'You are at the top of the ladder. Keep completing jobs to stay here.',
              style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
            ),
          ],
        ),
      );
    }
    final span = next.minJobsInYear - rank.minJobsInYear;
    final fraction = ((count - rank.minJobsInYear) / span).clamp(0.0, 1.0).toDouble();
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '+${rank.jobsUntilNext(count)} to ${next.name}',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'Threshold: ${next.minJobsInYear} jobs in the last 12 months',
            style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              key: const Key('rank-next-progress'),
              value: fraction,
              minHeight: 8,
              backgroundColor: AppTheme.borderGray,
              color: next.color,
              semanticsLabel: 'Progress from ${rank.name} to ${next.name}',
              semanticsValue: '${(fraction * 100).round()} percent',
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$count / ${next.minJobsInYear}',
            style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _ladder(int count) {
    final current = WorkerRank.forCompletedInYear(count);
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'The ladder',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          for (final tier in WorkerRank.tiers) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                RankEmblem(rank: tier, size: 32),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tier.name,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: count >= tier.minJobsInYear
                              ? tier.color
                              : AppTheme.textMuted,
                        ),
                      ),
                      Text(
                        '${tier.minJobsInYear} jobs / year',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  tier.name == current.name
                      ? 'Current'
                      : count >= tier.minJobsInYear
                          ? 'Achieved'
                          : 'Locked',
                  key: Key('rank-state-${tier.name}'),
                  style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _explainer() {
    final step =
        WorkerRank.tiers[1].minJobsInYear - WorkerRank.tiers.first.minJobsInYear;
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'How ranks work',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text(
            'Your rank counts jobs completed in the trailing 365 days — '
            'a rolling 12-month window, not a lifetime total. Reaching a '
            'tier\'s threshold moves you up automatically.',
            style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 8),
          Text(
            'A rank can also be lost as older completions fall outside that '
            'window. Every rank step requires $step completions per year.',
            style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
          ),
        ],
      ),
    );
  }
}
