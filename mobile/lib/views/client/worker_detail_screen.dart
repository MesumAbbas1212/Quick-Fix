import 'package:flutter/material.dart';
import 'package:quickfix/core/theme/app_theme.dart';
import 'package:quickfix/core/widgets/rank_badge.dart';
import 'package:quickfix/core/widgets/review_list_tile.dart';
import 'package:quickfix/core/widgets/user_avatar.dart';
import 'package:quickfix/models/job_model.dart';
import 'package:quickfix/models/review_model.dart';
import 'package:quickfix/models/worker_profile.dart';
import 'package:quickfix/models/worker_rank.dart';
import 'package:quickfix/services/job_service.dart';
import 'package:quickfix/services/review_service.dart';
import 'package:quickfix/services/summary_service.dart';
import 'package:quickfix/services/translation_service.dart';
import 'package:quickfix/views/chat/chat_screen.dart';

/// Full worker profile for clients: info with rank badge, stats, the
/// worker's completed work history, live reviews with translation into
/// the viewer's app language, and a direct chat entry point.
class WorkerDetailScreen extends StatefulWidget {
  final WorkerProfile worker;
  final String myId;
  final ReviewService? reviewService;
  final TranslationService? translationService;
  final JobService? jobService;
  final SummaryService? summaryService;

  /// Language code the viewer is using the app in. Reviews are translated
  /// into this language when the user taps Translate, and the overall
  /// review summary is written in this language too.
  final String userLanguage;

  const WorkerDetailScreen({
    super.key,
    required this.worker,
    required this.myId,
    this.reviewService,
    this.translationService,
    this.jobService,
    this.summaryService,
    this.userLanguage = 'en',
  });

  @override
  State<WorkerDetailScreen> createState() => _WorkerDetailScreenState();
}

class _WorkerDetailScreenState extends State<WorkerDetailScreen> {
  late final ReviewService _reviewService =
      widget.reviewService ?? ReviewService();
  late final TranslationService _translationService =
      widget.translationService ?? TranslationService();
  late final SummaryService _summaryService =
      widget.summaryService ?? SummaryService();

  /// Work history shows the 10 most recent jobs first; Grandmasters have
  /// 600+, so the rest stays collapsed behind "Show all".
  bool _showAllJobs = false;

  Future<String> _translate(String text) =>
      _translationService.translate(text, widget.userLanguage);

  @override
  Widget build(BuildContext context) {
    final worker = widget.worker;
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(
        backgroundColor: AppTheme.brandBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Worker Profile',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(14),
          children: [
            _buildProfileCard(worker),
            const SizedBox(height: 14),
            _buildStatsCard(worker),
            const SizedBox(height: 14),
            _buildAboutCard(worker),
            if (widget.jobService != null) ...[
              const SizedBox(height: 14),
              _buildWorkHistoryCard(worker),
            ],
            const SizedBox(height: 14),
            _buildSummaryCard(),
            const SizedBox(height: 14),
            _buildReviewsCard(),
            const SizedBox(height: 18),
            _buildChatButton(worker),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileCard(WorkerProfile worker) {
    return Container(
      padding: const EdgeInsets.all(18),
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
          UserAvatar(
            fullName: worker.fullName,
            avatarUrl: worker.avatarUrl,
            size: 72,
            online: worker.isAvailable,
            borderColor: AppTheme.accentYellow,
          ),
          const SizedBox(height: 12),
          Text(
            worker.fullName,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            worker.isAvailable ? 'Available' : 'Currently Busy',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: worker.isAvailable
                  ? AppTheme.successGreen
                  : AppTheme.textMuted,
            ),
          ),
          const SizedBox(height: 10),
          _buildRankBadge(worker),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: worker.professions.map((prof) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppTheme.ctaOrange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  _professionLabel(prof),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.ctaOrange,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          if (worker.languages.isNotEmpty)
            Text(
              'Speaks ${worker.languages.join(', ')}',
              style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
            ),
        ],
      ),
    );
  }

  /// Rank badge based on jobs completed within the trailing 12 months.
  /// Without a live jobs stream (tests / degraded mode) it falls back to
  /// the worker's lifetime completed-jobs count so a badge is always shown.
  Widget _buildRankBadge(WorkerProfile worker) {
    final jobService = widget.jobService;
    if (jobService == null) {
      final rank = WorkerRank.forCompletedInYear(worker.completedJobs);
      return RankBadge(rank: rank);
    }
    return StreamBuilder<List<JobModel>>(
      stream: jobService.watchCompletedJobsForWorker(worker.uid),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return RankBadge(
            rank: WorkerRank.forCompletedInYear(worker.completedJobs),
          );
        }
        final completed = snapshot.data ?? const <JobModel>[];
        final inYear = WorkerRank.countCompletedInYear(
          completed.map((job) => job.completedAt ?? job.updatedAt),
          now: DateTime.now(),
        );
        return RankBadge(
          rank: WorkerRank.forCompletedInYear(inYear),
          completedInYear: inYear,
        );
      },
    );
  }

  Widget _buildStatsCard(WorkerProfile worker) {
    final stats = [
      ('Rating', worker.rating.toStringAsFixed(1), Icons.star),
      ('Jobs Done', '${worker.completedJobs}', Icons.work_history),
      ('Reviews', '${worker.reviews}', Icons.reviews_outlined),
    ];
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
        children: stats.map((s) {
          return Expanded(
            child: Column(
              children: [
                Icon(s.$3, color: AppTheme.brandBlue, size: 18),
                const SizedBox(height: 6),
                Text(
                  s.$2,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textDark,
                  ),
                ),
                Text(
                  s.$1,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textMuted,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAboutCard(WorkerProfile worker) {
    if (worker.about == null || worker.about!.isEmpty) {
      return const SizedBox.shrink();
    }
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
            'About',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            worker.about!,
            style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
          ),
        ],
      ),
    );
  }

  /// All jobs the worker has completed, live from Firestore.
  Widget _buildWorkHistoryCard(WorkerProfile worker) {
    final jobService = widget.jobService;
    if (jobService == null) return const SizedBox.shrink();
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Work History',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 10),
          StreamBuilder<List<JobModel>>(
            stream: jobService.watchCompletedJobsForWorker(worker.uid),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Text(
                  'Could not load work history.',
                  style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                );
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'No completed jobs yet',
                    style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                  ),
                );
              }
              final jobs = snapshot.data!;
              final shown = _showAllJobs ? jobs : jobs.take(10).toList();
              return Column(
                children: [
                  ...shown.map((job) => _CompletedJobTile(job: job)),
                  if (jobs.length > 10)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Align(
                        alignment: Alignment.center,
                        child: TextButton(
                          onPressed: () =>
                              setState(() => _showAllJobs = !_showAllJobs),
                          child: Text(
                            _showAllJobs
                                ? 'Show less'
                                : 'Show all ${jobs.length} jobs',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.brandBlue,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  /// ML "Overall summary": all of the worker's reviews distilled into
  /// 1-2 paragraphs, written in the viewer's app language. Hidden when
  /// the worker has no reviews yet.
  Widget _buildSummaryCard() {
    return StreamBuilder<List<Review>>(
      stream: _reviewService.watchReviewsForWorker(widget.worker.uid),
      builder: (context, snapshot) {
        final reviews = snapshot.data ?? const <Review>[];
        if (!snapshot.hasData || reviews.isEmpty) {
          return const SizedBox.shrink();
        }
        return FutureBuilder<List<String>>(
          future: _summaryService.summarize(
            workerName: widget.worker.fullName,
            reviews: [
              for (final r in reviews)
                (
                  text: r.originalText,
                  lang: r.originalLang,
                  rating: r.rating,
                ),
            ],
            target: widget.userLanguage,
          ),
          builder: (context, summary) {
            final paragraphs = summary.data ?? const <String>[];
            if (summary.hasError || paragraphs.isEmpty) {
              return const SizedBox.shrink();
            }
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.auto_awesome,
                        size: 15,
                        color: AppTheme.brandBlue,
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'Overall summary',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textDark,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.brandBlue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'ML',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.brandBlue,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  for (var i = 0; i < paragraphs.length; i++) ...[
                    if (i > 0) const SizedBox(height: 8),
                    Text(
                      paragraphs[i],
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.55,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildReviewsCard() {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Reviews',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 10),
          StreamBuilder<List<Review>>(
            stream: _reviewService.watchReviewsForWorker(widget.worker.uid),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Text(
                  'Could not load reviews.',
                  style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                );
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'No reviews yet',
                    style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                  ),
                );
              }
              return Column(
                children: snapshot.data!
                    .map((review) => ReviewListTile(
                          review: review,
                          onTranslate: _translate,
                          viewerLanguage: widget.userLanguage,
                        ))
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildChatButton(WorkerProfile worker) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        key: const Key('chat-worker-button'),
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              peerName: worker.fullName,
              peerId: worker.uid,
              myId: widget.myId,
            ),
          ),
        ),
        icon: const Icon(Icons.chat_bubble_outline, size: 18),
        label: const Text(
          'Chat with Worker',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.brandBlue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
    );
  }

  String _professionLabel(JobCategory cat) {
    return cat.name[0].toUpperCase() +
        cat.name.substring(1).replaceAll(RegExp(r'(?<=[a-z])([A-Z])'), r' $1');
  }
}

/// One completed job in the worker's public work history.
class _CompletedJobTile extends StatelessWidget {
  final JobModel job;

  const _CompletedJobTile({required this.job});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.bgLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderGray),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.check_circle,
                size: 14,
                color: AppTheme.successGreen,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  job.title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textDark,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (job.rating != null) ...[
                const Icon(Icons.star, size: 13, color: AppTheme.accentYellow),
                const SizedBox(width: 2),
                Text(
                  job.rating!.toStringAsFixed(1),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textDark,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  _categoryLabel(job.category) +
                      ' · ' +
                      _dateLabel(job.completedAt ?? job.updatedAt),
                  style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'PKR ${job.budgetMin.toStringAsFixed(0)}-${job.budgetMax.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _categoryLabel(JobCategory cat) {
    return cat.name[0].toUpperCase() +
        cat.name.substring(1).replaceAll(RegExp(r'(?<=[a-z])([A-Z])'), r' $1');
  }

  String _dateLabel(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}
