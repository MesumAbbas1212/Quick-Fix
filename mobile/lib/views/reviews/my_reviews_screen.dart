import 'package:flutter/material.dart';
import 'package:quickfix/core/theme/app_theme.dart';
import 'package:quickfix/core/utils/content_direction.dart';
import 'package:quickfix/core/widgets/app_card.dart';
import 'package:quickfix/core/widgets/empty_state.dart';
import 'package:quickfix/core/widgets/error_state.dart';
import 'package:quickfix/core/widgets/loading_list.dart';
import 'package:quickfix/core/widgets/review_list_tile.dart';
import 'package:quickfix/core/widgets/user_avatar.dart';
import 'package:quickfix/models/review_model.dart';
import 'package:quickfix/models/user_model.dart';
import 'package:quickfix/models/worker_profile.dart';
import 'package:quickfix/services/profile_service.dart';
import 'package:quickfix/services/review_service.dart';
import 'package:quickfix/views/client/workers_screen.dart';

class MyReviewsScreen extends StatefulWidget {
  final UserModel user;
  final ReviewService? reviewService;
  final ProfileService? profileService;
  const MyReviewsScreen({super.key, required this.user, this.reviewService, this.profileService});
  @override
  State<MyReviewsScreen> createState() => _MyReviewsScreenState();
}
class _MyReviewsScreenState extends State<MyReviewsScreen> {
  late final ReviewService _reviews = widget.reviewService ?? ReviewService();
  late final ProfileService _profiles = widget.profileService ?? ProfileService();
  late Stream<List<Review>> _stream = _watch();
  final _workers = <String, Future<WorkerProfile?>>{};
  Stream<List<Review>> _watch() { try { return _reviews.watchReviewsByUser(widget.user.uid); } catch (error, stack) { return Stream.error(error, stack); } }
  void _retry() => setState(() { _workers.clear(); _stream = _watch(); });
  Future<WorkerProfile?> _worker(String uid) => _workers.putIfAbsent(uid, () => _profiles.getWorkerProfile(uid).timeout(const Duration(seconds: 8)));
  @override
  Widget build(BuildContext context) => Scaffold(backgroundColor: AppTheme.bgLight,
    appBar: AppBar(title: const Text('My reviews'), actions: [IconButton(key: const Key('my-reviews-refresh'), tooltip: 'Refresh written reviews', onPressed: _retry, icon: const Icon(Icons.refresh))]),
    body: SafeArea(child: StreamBuilder<List<Review>>(stream: _stream, builder: (context, snapshot) {
      if (snapshot.hasError) { return ErrorState(message: 'Could not load the reviews you wrote.', onRetry: _retry); }
      if (!snapshot.hasData) { return const LoadingList(); }
      final reviews = snapshot.data!;
      if (reviews.isEmpty) { return EmptyState(icon: Icons.rate_review_outlined, title: 'You haven’t reviewed anyone yet', message: 'Review a worker after completing a real job.',
        action: ElevatedButton(key: const Key('my-reviews-browse'), onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => WorkersScreen(user: widget.user, profileService: widget.profileService))), child: const Text('Browse workers'))); }
      final summary = ReviewService.writtenSummary(reviews);
      return ListView.builder(padding: const EdgeInsets.all(16), itemCount: reviews.length + 1, itemBuilder: (context, index) {
        if (index == 0) { return Padding(padding: const EdgeInsets.only(bottom: 14), child: AppCard(child: Text('${summary.count} reviews written • Average given: ${summary.average?.toStringAsFixed(1) ?? 'Not rated'}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)))); }
        final review = reviews[index - 1];
        return Padding(padding: const EdgeInsets.only(bottom: 14), child: AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          FutureBuilder<WorkerProfile?>(future: _worker(review.workerId), builder: (context, worker) {
            if (worker.hasError) { return TextButton(onPressed: () => setState(() { _workers.remove(review.workerId); }), child: const Text('Worker name unavailable — retry')); }
            final name = worker.connectionState == ConnectionState.waiting ? 'Loading worker…' : worker.data?.fullName ?? 'Former worker';
            return Row(children: [UserAvatar(fullName: name, avatarUrl: worker.data?.avatarUrl), const SizedBox(width: 12), Expanded(child: Text(name, textDirection: contentDirection(name), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)))]);
          }), const SizedBox(height: 12), ReviewListTile(review: review, onTranslate: null, viewerLanguage: widget.user.preferredLanguage),
        ])));
      });
    })),
  );
}
