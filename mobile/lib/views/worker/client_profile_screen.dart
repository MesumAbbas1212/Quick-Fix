import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:quickfix/core/theme/app_theme.dart';
import 'package:quickfix/core/utils/content_direction.dart';
import 'package:quickfix/core/widgets/app_card.dart';
import 'package:quickfix/core/widgets/empty_state.dart';
import 'package:quickfix/core/widgets/error_state.dart';
import 'package:quickfix/core/widgets/job_category_icons.dart';
import 'package:quickfix/core/widgets/loading_list.dart';
import 'package:quickfix/core/widgets/review_list_tile.dart';
import 'package:quickfix/core/widgets/user_avatar.dart';
import 'package:quickfix/models/client_activity.dart';
import 'package:quickfix/services/auth_service.dart';
import 'package:quickfix/services/client_activity_service.dart';
import 'package:quickfix/services/job_service.dart';
import 'package:quickfix/services/review_service.dart';
import 'package:quickfix/views/admin/report_screen.dart';
class ClientProfileScreen extends StatefulWidget {
  final String clientId, viewerId, viewerLanguage;
  final ClientActivityService? activityService;
  final AuthService? authService;
  final JobService? jobService;
  final ReviewService? reviewService;
  const ClientProfileScreen({super.key, required this.clientId, required this.viewerId, this.viewerLanguage = 'en', this.activityService, this.authService, this.jobService, this.reviewService});
  @override
  State<ClientProfileScreen> createState() => _ClientProfileScreenState();
}
class _ClientProfileScreenState extends State<ClientProfileScreen> {
  late final ClientActivityService _service = widget.activityService ?? ClientActivityService(authService: widget.authService, jobService: widget.jobService, reviewService: widget.reviewService);
  late Stream<ClientActivity?> _stream = _watch();
  Stream<ClientActivity?> _watch() { try { return _service.watch(widget.clientId); } catch (error, stack) { return Stream.error(error, stack); } }
  void _retry() => setState(() { _stream = _watch(); });
  @override
  Widget build(BuildContext context) => Scaffold(backgroundColor: AppTheme.bgLight,
    appBar: AppBar(title: const Text('Client profile'), actions: [IconButton(tooltip: 'Refresh client profile', onPressed: _retry, icon: const Icon(Icons.refresh))]),
    body: SafeArea(child: StreamBuilder<ClientActivity?>(stream: _stream, builder: (context, snapshot) {
      if (snapshot.hasError) return ErrorState(message: 'Could not load the client profile.', onRetry: _retry);
      if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) return const LoadingList();
      final client = snapshot.data;
      if (client == null) return EmptyState(icon: Icons.person_off_outlined, title: 'Client unavailable', message: 'This account may have been removed.', action: OutlinedButton(onPressed: _retry, child: const Text('Refresh profile')));
      return ListView(padding: const EdgeInsets.all(16), children: [
        AppCard(child: Column(children: [UserAvatar(fullName: client.name, avatarUrl: client.avatar, size: 72), const SizedBox(height: 12),
          Text(client.name, textDirection: contentDirection(client.name), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          Text('Customer since ${intl.DateFormat('MMM yyyy', 'en').format(client.since)}', style: const TextStyle(fontSize: 13, color: AppTheme.textMuted)),
          const SizedBox(height: 8), Text('Average rating given: ${client.averageGiven?.toStringAsFixed(1) ?? 'No reviews yet'}', style: const TextStyle(fontSize: 13)),
        ])), const SizedBox(height: 14),
        AppCard(child: Wrap(spacing: 24, runSpacing: 12, children: [Text('${client.posted} posted'), Text('${client.completed} completed'), Text('${client.cancelled} cancelled')])),
        const SizedBox(height: 12), const Text('Job addresses, coordinates, descriptions, contact details and free-text titles are withheld on this profile. Open an assigned job’s tracking page for authorized contact/location information.', style: TextStyle(fontSize: 13, color: AppTheme.textMuted)),
        if (client.jobs.isEmpty && client.reviews.isEmpty) EmptyState(icon: Icons.history, title: 'No activity shared yet', message: 'A new client may not have job or review history.',
          action: OutlinedButton(onPressed: () => Navigator.of(context).maybePop(), child: const Text('Back to job'))),
        if (client.jobs.isNotEmpty) ...[const SizedBox(height: 16), const Text('Recent job activity', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          for (final job in client.jobs) ListTile(leading: Icon(jobCategoryIcon(job.category), color: AppTheme.brandBlue), title: Text(jobCategoryLabel(job.category)), subtitle: Text('${job.status.name} • ${intl.DateFormat('d MMM yyyy', 'en').format(job.date)}'))],
        if (client.reviews.isNotEmpty) ...[const SizedBox(height: 16), const Text('Reviews written (public content)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          for (final review in client.reviews) ReviewListTile(review: review, viewerLanguage: widget.viewerLanguage, onTranslate: null)],
        if (widget.viewerId != client.uid) OutlinedButton.icon(key: const Key('client-profile-report'), onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ReportScreen(myId: widget.viewerId, reportedId: client.uid, reportedName: client.name))),
          icon: const Icon(Icons.flag_outlined, color: AppTheme.dangerRed), label: const Text('Report this client')),
      ]);
    })),
  );
}
