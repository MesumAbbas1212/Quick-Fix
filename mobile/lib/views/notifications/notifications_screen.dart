import 'package:quickfix/views/jobs/quote_request_screen.dart';
import 'package:quickfix/views/jobs/dispute_screen.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:quickfix/core/theme/app_theme.dart';
import 'package:quickfix/core/utils/content_direction.dart';
import 'package:quickfix/core/widgets/app_card.dart';
import 'package:quickfix/core/widgets/empty_state.dart';
import 'package:quickfix/core/widgets/error_state.dart';
import 'package:quickfix/core/widgets/loading_list.dart';
import 'package:quickfix/models/app_notification.dart';
import 'package:quickfix/models/user_model.dart';
import 'package:quickfix/services/auth_service.dart';
import 'package:quickfix/services/chat_service.dart';
import 'package:quickfix/services/job_request_service.dart';
import 'package:quickfix/services/job_service.dart';
import 'package:quickfix/services/notification_service.dart';
import 'package:quickfix/services/payment_service.dart';
import 'package:quickfix/services/profile_service.dart';
import 'package:quickfix/services/review_service.dart';
import 'package:quickfix/views/chat/chat_screen.dart';
import 'package:quickfix/views/client/client_job_detail_screen.dart';
import 'package:quickfix/views/client/worker_reviews_screen.dart';
import 'package:quickfix/views/jobs/job_tracking_screen.dart';
import 'package:quickfix/views/payments/payment_history_screen.dart';

class NotificationsScreen extends StatefulWidget {
  final UserModel user;
  final NotificationService? notificationService;
  final JobService? jobService;
  final ChatService? chatService;
  final AuthService? authService;
  final ProfileService? profileService;
  final JobRequestService? requestService;
  final PaymentService? paymentService;
  final ReviewService? reviewService;
  const NotificationsScreen({super.key, required this.user, this.notificationService, this.jobService, this.chatService,
    this.authService, this.profileService, this.requestService, this.paymentService, this.reviewService});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}
class _NotificationsScreenState extends State<NotificationsScreen> {
  late final NotificationService _service = widget.notificationService ?? NotificationService();
  late Stream<List<AppNotification>> _stream = _watch();
  bool _busy = false;
  String? _opening;
  Stream<List<AppNotification>> _watch() { try { return _service.watchItems(widget.user.uid); } catch (error, stack) { return Stream.error(error, stack); } }
  void _retry() => setState(() { _stream = _watch(); });
  void _message(String text) { if (mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text))); } }
  Future<void> _allRead() async {
    if (_busy) { return; } setState(() { _busy = true; });
    try { await _service.markAllRead(widget.user.uid); }
    catch (_) { _message('Could not confirm all updates as read. Some may be saved; retry for the rest.'); }
    finally { if (mounted) { setState(() { _busy = false; }); } }
  }
  Future<void> _open(AppNotification notification) async {
    if (_opening != null || _busy) { return; }
    setState(() { _opening = notification.id; });
    try {
      await _service.markRead(widget.user.uid, notification.id);
      final ref = notification.refId;
      if (ref.isEmpty || ref.contains('/')) { throw StateError('Missing reference'); }
      Widget? page;
      if (notification.type == 'quote') {
        page = QuoteRequestScreen(user: widget.user, requestId: ref, profileService: widget.profileService, jobService: widget.jobService);
      } else if (notification.type == 'dispute') {
        page = DisputeScreen(jobId: ref, userId: widget.user.uid, jobService: widget.jobService, paymentService: widget.paymentService);
      } else if (notification.type == 'chat') {
        final chat = widget.chatService ?? ChatService();
        final conversation = await chat.getConversation(ref).timeout(const Duration(seconds: 8));
        if (conversation == null || !conversation.participants.contains(widget.user.uid)) { throw StateError('Conversation removed'); }
        final peer = conversation.participants.firstWhere((id) => id != widget.user.uid);
        final profile = await (widget.authService ?? AuthService()).getUserProfile(peer).timeout(const Duration(seconds: 8));
        page = ChatScreen(myId: widget.user.uid, peerId: peer, peerName: profile?.fullName ?? 'Chat participant', chatService: chat);
      } else if (notification.type == 'payment') {
        final payment = await (widget.paymentService ?? PaymentService()).getPayment(ref).timeout(const Duration(seconds: 8));
        if (payment == null) { throw StateError('Receipt removed'); }
        page = PaymentHistoryScreen(user: widget.user, paymentService: widget.paymentService, jobService: widget.jobService, profileService: widget.profileService, authService: widget.authService);
      } else if (notification.type == 'review') {
        final worker = await (widget.profileService ?? ProfileService()).getWorkerProfile(widget.user.uid).timeout(const Duration(seconds: 8));
        if (worker == null) { throw StateError('Worker profile removed'); }
        page = WorkerReviewsScreen(workerUid: worker.uid, workerName: worker.fullName, rating: worker.rating, reviewCount: worker.reviews,
          userLanguage: widget.user.preferredLanguage, reviewService: widget.reviewService);
      } else if (notification.type == 'job' || notification.type == 'request') {
        var jobId = ref;
        if (notification.type == 'request') {
          final request = await (widget.requestService ?? JobRequestService()).getRequest(ref).timeout(const Duration(seconds: 8));
          if (request == null) { throw StateError('Application removed'); } jobId = request.jobId;
        }
        final job = await (widget.jobService ?? JobService()).getJob(jobId).timeout(const Duration(seconds: 8));
        if (job == null || (job.userId != widget.user.uid && job.workerId != widget.user.uid)) { throw StateError('Job unavailable'); }
        page = job.userId == widget.user.uid ? ClientJobDetailScreen(job: job, currentUserId: widget.user.uid, jobService: widget.jobService,
          profileService: widget.profileService, reviewerLanguage: widget.user.preferredLanguage) : JobTrackingScreen(jobId: job.id, myId: widget.user.uid,
          jobService: widget.jobService, profileService: widget.profileService, authService: widget.authService, reviewerLanguage: widget.user.preferredLanguage);
      }
      if (!mounted) { return; }
      if (page == null) { _message('This update has no available destination in this version.'); return; }
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page!));
    } catch (_) { _message('This update could not be opened. It may have been removed; check your connection and try again.'); }
    finally { if (mounted) { setState(() { _opening = null; }); } }
  }
  @override
  Widget build(BuildContext context) => Scaffold(backgroundColor: AppTheme.bgLight,
    appBar: AppBar(title: const Text('Notifications'), actions: [IconButton(key: const Key('notifications-refresh'), tooltip: 'Refresh notifications', onPressed: _retry, icon: const Icon(Icons.refresh))]),
    body: SafeArea(child: Column(children: [
      Padding(padding: const EdgeInsets.all(14), child: Row(children: [const Expanded(child: Text('Latest 200 in-app updates. No push notifications.', style: TextStyle(fontSize: 12, color: AppTheme.textMuted))),
        TextButton(key: const Key('notifications-all-read'), onPressed: _busy ? null : _allRead, child: Text(_busy ? 'Saving…' : 'Mark all read'))])),
      Expanded(child: StreamBuilder<List<AppNotification>>(stream: _stream, builder: (context, snapshot) {
        if (snapshot.hasError) { return ErrorState(message: 'Could not load your notifications.', onRetry: _retry); }
        if (!snapshot.hasData) { return const SingleChildScrollView(child: LoadingList()); }
        final prefs = widget.user.notificationPrefs;
        final items = snapshot.data!.where((item) => prefs.shows(item.type)).toList();
        if (items.isEmpty) { return SingleChildScrollView(child: EmptyState(icon: Icons.notifications_none_outlined, title: 'You’re all caught up',
          message: 'No updates match your in-app notification preferences.', action: OutlinedButton(onPressed: _retry, child: const Text('Check again')))); }
        final now = DateTime.now(); var previous = '';
        return ListView(padding: const EdgeInsets.all(14), children: [for (final item in items) ...[
          if (_group(item, now) != previous) Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(previous = _group(item, now), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
          Padding(padding: const EdgeInsets.only(bottom: 12), child: AppCard(padding: 0, child: ListTile(key: Key('notification-${item.id}'),
            leading: Icon(item.type == 'chat' ? Icons.chat_bubble_outline : item.type == 'payment' ? Icons.receipt_long_outlined : Icons.notifications_outlined, color: AppTheme.brandBlue),
            title: Text(item.title, textDirection: contentDirection(item.title), style: TextStyle(fontSize: 14, fontWeight: item.isRead ? FontWeight.w500 : FontWeight.w700)),
            subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(item.body, textDirection: contentDirection(item.body), style: const TextStyle(fontSize: 13)),
              Text(item.createdAt == null ? 'Date pending' : intl.DateFormat('d MMM, HH:mm', 'en').format(item.createdAt!.toLocal()), style: const TextStyle(fontSize: 12, color: AppTheme.textMuted))]),
            trailing: item.isRead ? null : Semantics(label: 'Unread', child: const Icon(Icons.circle, size: 10, color: AppTheme.brandBlue)),
            onTap: _opening == null && !_busy ? () => _open(item) : null))),
        ]]);
      })),
    ])),
  );
  String _group(AppNotification item, DateTime now) {
    final date = item.createdAt?.toLocal();
    return date == null ? 'Recent' : date.year == now.year && date.month == now.month && date.day == now.day ? 'Today' : 'Earlier';
  }
}
