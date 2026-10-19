import 'dart:async';
import 'package:quickfix/models/client_activity.dart';
import 'package:quickfix/models/job_model.dart';
import 'package:quickfix/models/review_model.dart';
import 'package:quickfix/models/user_model.dart';
import 'package:quickfix/services/auth_service.dart';
import 'package:quickfix/services/job_service.dart';
import 'package:quickfix/services/review_service.dart';
class ClientActivityService {
  final AuthService? _injectedAuth;
  final JobService? _injectedJobs;
  final ReviewService? _injectedReviews;
  ClientActivityService({AuthService? authService, JobService? jobService, ReviewService? reviewService}) : _injectedAuth = authService, _injectedJobs = jobService, _injectedReviews = reviewService;
  late final AuthService _auth = _injectedAuth ?? AuthService();
  late final JobService _jobs = _injectedJobs ?? JobService();
  late final ReviewService _reviews = _injectedReviews ?? ReviewService();
  static ClientActivity project(UserModel user, List<JobModel> rawJobs, List<Review> rawReviews) {
    final jobs = rawJobs.where((job) => job.userId == user.uid).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final reviews = rawReviews.where((review) => review.reviewerId == user.uid).toList();
    return ClientActivity(uid: user.uid, name: user.fullName, avatar: user.avatarUrl, since: user.createdAt, posted: jobs.length,
      completed: jobs.where((job) => job.status == JobStatus.completed).length, cancelled: jobs.where((job) => job.status == JobStatus.cancelled).length,
      averageGiven: ReviewService.writtenSummary(reviews).average,
      jobs: jobs.take(10).map((job) => ClientJobActivity(category: job.category, status: job.status, date: job.createdAt)).toList(), reviews: reviews);
  }
  Stream<ClientActivity?> watch(String uid) => Stream.multi((sink) {
    UserModel? user; List<JobModel>? jobs; List<Review>? reviews; var userLoaded = false, closed = false;
    final subscriptions = <StreamSubscription<dynamic>>[];
    void emit() { if (closed) return; if (userLoaded && user == null) { sink.add(null); return; } if (user != null && jobs != null && reviews != null) sink.add(project(user!, jobs!, reviews!)); }
    try {
      subscriptions.add(_auth.watchUser(uid).listen((value) { userLoaded = true; user = value; emit(); }, onError: sink.addError));
      subscriptions.add(_jobs.watchUserJobs(uid).listen((value) { jobs = value; emit(); }, onError: sink.addError));
      subscriptions.add(_reviews.watchReviewsByUser(uid).listen((value) { reviews = value; emit(); }, onError: sink.addError));
    } catch (error, stack) { sink.addError(error, stack); }
    sink.onCancel = () async { closed = true; for (final subscription in subscriptions) { await subscription.cancel(); } };
  });
}
