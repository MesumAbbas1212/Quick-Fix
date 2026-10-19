import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quickfix/models/performance_report.dart';
import 'package:quickfix/services/job_service.dart';
import 'package:quickfix/services/job_request_service.dart';
import 'package:quickfix/services/review_service.dart';

class PerformanceService {
  final JobService? _injectedJobs;
  final JobRequestService? _injectedRequests;
  final ReviewService? _injectedReviews;
  PerformanceService({JobService? jobService, JobRequestService? requestService, ReviewService? reviewService})
    : _injectedJobs = jobService, _injectedRequests = requestService, _injectedReviews = reviewService;
  late final JobService _jobs = _injectedJobs ?? JobService();
  late final JobRequestService _requests = _injectedRequests ?? JobRequestService();
  late final ReviewService _reviews = _injectedReviews ?? ReviewService();
  Stream<PerformanceReport> watch(String uid) => Stream.multi((sink) {
    List<Map<String, dynamic>>? jobs, requests, reviews; var closed = false;
    final subscriptions = <StreamSubscription<dynamic>>[];
    void emit() { if (!closed && jobs != null && requests != null && reviews != null) sink.add(compute(uid, jobs!, requests!, reviews!)); }
    try {
      subscriptions.add(_jobs.watchWorkerJobs(uid).listen((value) { jobs = value.map((job) => {'id': job.id, ...job.toMap()}).toList(); emit(); }, onError: sink.addError));
      subscriptions.add(_requests.watchWorkerRequests(uid).listen((value) { requests = value.map((request) => request.toMap()).toList(); emit(); }, onError: sink.addError));
      subscriptions.add(_reviews.watchReviewsForWorker(uid).listen((value) { reviews = value.map((review) => review.toMap()).toList(); emit(); }, onError: sink.addError));
    } catch (error, stack) { sink.addError(error, stack); }
    sink.onCancel = () async { closed = true; for (final subscription in subscriptions) { await subscription.cancel(); } };
  });
  static DateTime? _date(Object? value) => value is Timestamp ? value.toDate() : value is DateTime ? value : null;
  static PerformanceReport compute(String uid, Iterable<Map<String, dynamic>> jobData, Iterable<Map<String, dynamic>> requestData, Iterable<Map<String, dynamic>> reviewData) {
    final jobs = jobData.where((job) => job['workerId'] == uid).toList();
    final completed = jobs.where((job) => job['status'] == 'completed').toList(); final cancelled = jobs.where((job) => job['status'] == 'cancelled').length;
    final requests = requestData.where((request) => request['workerId'] == uid && const {'pending', 'accepted', 'declined'}.contains(request['status'])).toList();
    final decided = requests.where((request) => request['status'] != 'pending').toList(); final accepted = decided.where((request) => request['status'] == 'accepted').length;
    double? ratio(int numerator, int denominator) => denominator == 0 ? null : numerator / denominator;
    final scores = <double>[]; final reviewedJobs = <String>{};
    for (final review in reviewData) {
      final score = review['rating'];
      if (review['workerId'] == uid && score is num && score.isFinite && score >= 1 && score <= 5) { scores.add(score.toDouble()); if (review['jobId'] is String) reviewedJobs.add(review['jobId'] as String); }
    }
    for (final job in completed) { final score = job['rating']; if (!reviewedJobs.contains(job['id']) && score is num && score.isFinite && score >= 1 && score <= 5) scores.add(score.toDouble()); }
    var measured = 0, onSchedule = 0;
    for (final job in completed) {
      final end = _date(job['completedAt']); final day = _date(job['preferredDate']); final time = _date(job['preferredTime']);
      if (end == null || day == null) continue;
      measured++;
      final deadline = time == null ? (day.isUtc ? DateTime.utc(day.year, day.month, day.day + 1) : DateTime(day.year, day.month, day.day + 1))
        : (day.isUtc ? DateTime.utc(day.year, day.month, day.day, time.hour, time.minute) : DateTime(day.year, day.month, day.day, time.hour, time.minute));
      if (time == null ? end.isBefore(deadline) : !end.isAfter(deadline)) onSchedule++;
    }
    final reply = ratio(decided.length, requests.length); final acceptance = ratio(accepted, decided.length);
    final completion = ratio(completed.length, completed.length + cancelled); final schedule = ratio(onSchedule, measured);
    final opportunities = <(double?, String)>[
      (reply, 'The reply metric measures clients’ decisions, not your response speed. Clear applications may help them decide.'),
      (acceptance, 'Apply where your skills, price and service area fit the posted work.'),
      (completion, 'Keep availability and agreed schedules current to reduce cancelled bookings.'),
      (schedule, 'Agree completion timing in Chat. This date/time proxy is not an arrival-punctuality or GPS measure.'),
    ].where((item) => item.$1 != null).toList()..sort((a, b) => a.$1!.compareTo(b.$1!));
    final activities = jobs.where((job) => const {'completed', 'cancelled', 'assigned', 'inProgress'}.contains(job['status'])).map((job) => PerformanceActivity(
      title: job['title'] as String? ?? 'Job activity', status: job['status'] as String, jobId: job['id'] as String?, date: _date(job['completedAt']) ?? _date(job['updatedAt']))).toList()
      ..sort((a, b) => (b.date ?? DateTime(1970)).compareTo(a.date ?? DateTime(1970)));
    return PerformanceReport(completedJobs: completed.length, replyRate: reply, acceptanceRate: acceptance, completionRate: completion, scheduleProxy: schedule,
      averageRating: scores.isEmpty ? null : scores.reduce((a, b) => a + b) / scores.length,
      suggestion: opportunities.isEmpty ? 'More decided applications and completed work will make insights useful.' : opportunities.first.$2, activity: activities.take(10).toList());
  }
}
