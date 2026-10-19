import 'package:quickfix/models/user_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:quickfix/core/theme/app_theme.dart';
import 'package:quickfix/core/utils/content_direction.dart';
import 'package:quickfix/core/utils/location_access.dart';
import 'package:quickfix/core/widgets/app_card.dart';
import 'package:quickfix/core/widgets/empty_state.dart';
import 'package:quickfix/core/widgets/error_state.dart';
import 'package:quickfix/core/widgets/loading_list.dart';
import 'package:quickfix/core/widgets/rank_badge.dart';
import 'package:quickfix/core/widgets/user_avatar.dart';
import 'package:quickfix/models/saved_worker.dart';
import 'package:quickfix/models/worker_rank.dart';
import 'package:quickfix/services/chat_service.dart';
import 'package:quickfix/services/job_service.dart';
import 'package:quickfix/services/location_service.dart';
import 'package:quickfix/services/profile_service.dart';
import 'package:quickfix/services/worker_filter_service.dart';
import 'package:quickfix/views/chat/chat_screen.dart';
import 'package:quickfix/views/client/worker_detail_screen.dart';
import 'package:quickfix/views/client/workers_screen.dart';

class SavedWorkersScreen extends StatefulWidget {
  final UserModel user;
  String get userId => user.uid;
  String get userLanguage => user.preferredLanguage;
  final GeoPoint? fromLocation;
  final ProfileService? profileService;
  final JobService? jobService;
  final ChatService? chatService;
  final LocationService? locationService;
  final WorkerFilterService? workerFilterService;
  const SavedWorkersScreen({super.key, required this.user, this.fromLocation,
    this.profileService, this.jobService, this.chatService, this.locationService, this.workerFilterService});
  @override
  State<SavedWorkersScreen> createState() => _SavedWorkersScreenState();
}
class _SavedWorkersScreenState extends State<SavedWorkersScreen> {
  late final ProfileService _profiles = widget.profileService ?? ProfileService();
  late final LocationService _location = widget.locationService ?? LocationService();
  late final WorkerFilterService _filters = widget.workerFilterService ?? WorkerFilterService(jobService: widget.jobService);
  late Stream<List<SavedWorker>> _stream = _watch();
  late GeoPoint? _origin = widget.fromLocation;
  String _countKey = '';
  Future<Map<String, int>>? _counts;
  bool _finding = false;
  final _removing = <String>{};
  Stream<List<SavedWorker>> _watch() { try { return _profiles.watchSavedWorkers(widget.userId); } catch (error, stack) { return Stream.error(error, stack); } }
  void _retry() => setState(() { _stream = _watch(); _countKey = ''; _counts = null; });
  void _browse() => Navigator.of(context).push(MaterialPageRoute(builder: (_) => WorkersScreen(user: widget.user, profileService: widget.profileService, jobService: widget.jobService)));
  Future<bool> _remove(String id) async {
    if (_removing.contains(id)) { return false; }
    _removing.add(id);
    try {
      await _profiles.setWorkerSaved(uid: widget.userId, workerId: id, saved: false);
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Worker removed from saved'), action: SnackBarAction(label: 'Undo', onPressed: () async {
        try { await _profiles.setWorkerSaved(uid: widget.userId, workerId: id, saved: true); }
        catch (_) { if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not restore the saved worker. Retry from their profile.'))); } }
      }))); }
      return true;
    } catch (_) {
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not remove this saved worker. Please retry.'))); }
      return false;
    } finally { _removing.remove(id); }
  }
  Future<void> _locate() async {
    if (_finding) { return; }
    if (!await explainLocationAccess(context, locationService: _location, purpose: 'Show distances to your saved workers')) { return; }
    if (!mounted) { return; }
    setState(() { _finding = true; });
    try {
      final origin = await _location.getCurrentLocation().timeout(const Duration(seconds: 8));
      if (!mounted) { return; }
      if (origin == null) { throw StateError('Position unavailable'); }
      setState(() { _origin = origin; });
    } catch (_) { if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not get a position. Saved workers remain available. Try again.'))); } }
    finally { if (mounted) { setState(() { _finding = false; }); } }
  }
  @override
  Widget build(BuildContext context) => Scaffold(backgroundColor: AppTheme.bgLight,
    appBar: AppBar(title: const Text('Saved workers'), actions: [IconButton(key: const Key('saved-workers-refresh'), tooltip: 'Refresh saved workers', onPressed: _retry, icon: const Icon(Icons.refresh))]),
    body: SafeArea(child: StreamBuilder<List<SavedWorker>>(stream: _stream, builder: (context, snapshot) {
      if (snapshot.hasError) { return ErrorState(message: 'Could not load your saved workers.', onRetry: _retry); }
      if (!snapshot.hasData) { return const LoadingList(); }
      final entries = snapshot.data!;
      if (entries.isEmpty) { return EmptyState(icon: Icons.bookmarks_outlined, title: 'No saved workers yet', message: 'Bookmark a worker’s profile to find them here again.',
        action: ElevatedButton(key: const Key('saved-workers-browse'), onPressed: _browse, child: const Text('Browse workers'))); }
      final ids = entries.where((entry) => entry.profile != null).map((entry) => entry.uid).toList();
      final countKey = ids.join('|');
      if (_counts == null || _countKey != countKey) { _countKey = countKey; _counts = _filters.loadAnnualCounts(ids, now: DateTime.now()); }
      return FutureBuilder<Map<String, int>>(future: _counts, builder: (context, ranks) => ListView(padding: const EdgeInsets.all(16), children: [
        TextButton.icon(key: const Key('saved-workers-location'), onPressed: _finding ? null : _locate, icon: const Icon(Icons.my_location), label: Text(_finding ? 'Finding position…' : 'Use location for distances')),
        if (ranks.hasError) TextButton(onPressed: _retry, child: const Text('Rank lookup failed — retry')),
        for (final entry in entries) Padding(padding: const EdgeInsets.only(bottom: 14), child: Dismissible(key: ValueKey('saved-${entry.uid}'),
          direction: DismissDirection.endToStart, confirmDismiss: (_) async { await _remove(entry.uid); return false; },
          background: const ColoredBox(color: AppTheme.dangerRed, child: Align(alignment: AlignmentDirectional.centerEnd, child: Padding(padding: EdgeInsets.all(16), child: Icon(Icons.bookmark_remove, color: AppTheme.surfaceWhite)))),
          child: _card(entry, ranks.data?[entry.uid]))),
      ]));
    })),
  );
  Widget _card(SavedWorker entry, int? annual) {
    final worker = entry.profile;
    if (worker == null) { return AppCard(child: ListTile(title: const Text('Worker no longer available'), subtitle: const Text('Remove this saved reference or browse other workers.'),
      trailing: IconButton(key: Key('saved-remove-${entry.uid}'), tooltip: 'Remove unavailable worker', onPressed: () => _remove(entry.uid), icon: const Icon(Icons.bookmark_remove_outlined)))); }
    final distance = _filters.distanceKm(worker.location, _origin);
    return AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [UserAvatar(fullName: worker.fullName, avatarUrl: worker.avatarUrl), const SizedBox(width: 12), Expanded(child: Text(worker.fullName,
        textDirection: contentDirection(worker.fullName), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
        IconButton(key: Key('saved-remove-${entry.uid}'), tooltip: 'Remove saved worker', onPressed: () => _remove(entry.uid), icon: const Icon(Icons.bookmark, color: AppTheme.brandBlue))]),
      const SizedBox(height: 10), if (annual != null) RankBadge(rank: WorkerRank.forCompletedInYear(annual)),
      if (annual == null) const Text('Annual rank not loaded', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
      const SizedBox(height: 8), Text('${worker.rating.toStringAsFixed(1)} rating • ${worker.isAvailable ? 'Available' : 'Unavailable'} • ${distance == null ? 'Distance not set' : '${distance.toStringAsFixed(1)} km'}', style: const TextStyle(fontSize: 13, color: AppTheme.textMuted)),
      const SizedBox(height: 10), Wrap(spacing: 10, runSpacing: 8, children: [
        OutlinedButton(key: Key('saved-profile-${entry.uid}'), onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => WorkerDetailScreen(worker: worker, myId: widget.userId,
          jobService: widget.jobService, profileService: widget.profileService, userLanguage: widget.userLanguage))), child: const Text('View profile')),
        ElevatedButton(key: Key('saved-chat-${entry.uid}'), onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChatScreen(myId: widget.userId, peerId: entry.uid,
          peerName: worker.fullName, chatService: widget.chatService))), child: const Text('Chat')),
      ]),
    ]));
  }
}
