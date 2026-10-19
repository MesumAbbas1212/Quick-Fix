import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:quickfix/core/theme/app_theme.dart';
import 'package:quickfix/core/utils/content_direction.dart';
import 'package:quickfix/core/utils/location_access.dart';
import 'package:quickfix/core/widgets/app_card.dart';
import 'package:quickfix/core/widgets/empty_state.dart';
import 'package:quickfix/core/widgets/error_state.dart';
import 'package:quickfix/core/widgets/loading_list.dart';
import 'package:quickfix/models/job_model.dart';
import 'package:quickfix/services/chat_service.dart';
import 'package:quickfix/services/job_service.dart';
import 'package:quickfix/services/location_service.dart';
import 'package:quickfix/services/map_launcher.dart';
class NavigateToJobScreen extends StatefulWidget {
  final String jobId, workerId;
  final JobService? jobService;
  final LocationService? locationService;
  final ChatService? chatService;
  final UrlLauncher? urlLauncher;
  const NavigateToJobScreen({super.key, required this.jobId, required this.workerId, this.jobService, this.locationService, this.chatService, this.urlLauncher});
  @override
  State<NavigateToJobScreen> createState() => _NavigateToJobScreenState();
}
class _NavigateToJobScreenState extends State<NavigateToJobScreen> {
  late final JobService _jobs = widget.jobService ?? JobService();
  late final LocationService _locations = widget.locationService ?? LocationService();
  late final ChatService _chat = widget.chatService ?? ChatService();
  late final UrlLauncher _maps = widget.urlLauncher ?? const MapLauncher();
  late Stream<JobModel?> _stream = _watch();
  final _eta = TextEditingController();
  GeoPoint? _origin;
  bool _busy = false;
  String? _error;
  Stream<JobModel?> _watch() { try { return _jobs.watchJob(widget.jobId); } catch (error, stack) { return Stream.error(error, stack); } }
  @override
  void dispose() { _eta.dispose(); super.dispose(); }
  Future<GeoPoint?> _position() async {
    if (!await explainLocationAccess(context, locationService: _locations, purpose: 'Use one departure position for distance or an explicit Chat update')) { return null; }
    return await _locations.getCurrentLocation().timeout(const Duration(seconds: 8));
  }
  Future<void> _locate() async {
    if (_busy) { return; } setState(() { _busy = true; _error = null; });
    try { final point = await _position(); if (mounted) { setState(() { _origin = point; if (point == null) { _error = 'Position not shared. Maps still works without location permission.'; } }); } }
    catch (_) { if (mounted) { setState(() { _error = 'Could not get a position. Retry; Maps does not need your GPS.'; }); } }
    finally { if (mounted) { setState(() { _busy = false; }); } }
  }
  Future<void> _open(JobModel job) async {
    try { if (!await _maps.openLocation(job.location.latitude, job.location.longitude).timeout(const Duration(seconds: 8))) { throw StateError('No handler'); } }
    catch (_) { if (mounted) { setState(() { _error = 'Could not open Maps. Try another map app and retry.'; }); } }
  }
  Future<void> _share(JobModel job) async {
    if (_busy) { return; }
    final minutes = _eta.text.trim().isEmpty ? null : int.tryParse(_eta.text.trim());
    if (_eta.text.trim().isNotEmpty && (minutes == null || minutes < 1 || minutes > 1440)) { setState(() { _error = 'Enter your own ETA as 1–1440 minutes, or leave it blank.'; }); return; }
    setState(() { _busy = true; _error = null; });
    try {
      // Always take a fresh, explicitly consented one-shot position for sharing.
      final point = await _position();
      if (!mounted) { return; }
      if (point == null) { throw StateError('No consent/fix'); }
      final current = await _jobs.getJob(job.id).timeout(const Duration(seconds: 8));
      if (!mounted) { return; }
      if (current == null || current.workerId != widget.workerId || current.userId != job.userId || current.anonymized || !(current.status == JobStatus.assigned || current.status == JobStatus.inProgress)) { throw StateError('Booking changed'); }
      await _chat.sendMessage(senderId: widget.workerId, receiverId: current.userId, text: minutes == null ? 'Shared my departure position (no ETA supplied)' : 'Estimated arrival in $minutes minutes (worker-provided estimate)',
        attachmentType: 'location', attachmentUrl: '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}').timeout(const Duration(seconds: 15));
      if (mounted) { setState(() { _origin = point; }); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('One position update sent in Chat'))); }
    } catch (_) { if (mounted) { setState(() { _error = 'Could not confirm sharing. Check permission, connection and whether the booking is still active, then retry.'; }); } }
    finally { if (mounted) { setState(() { _busy = false; }); } }
  }
  @override
  Widget build(BuildContext context) => Scaffold(backgroundColor: AppTheme.bgLight, appBar: AppBar(title: const Text('Navigate to job')),
    body: SafeArea(child: StreamBuilder<JobModel?>(stream: _stream, builder: (context, snapshot) {
      if (snapshot.hasError) { return ErrorState(message: 'Could not load the destination.', onRetry: () => setState(() { _stream = _watch(); })); }
      if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) { return const LoadingList(); }
      final job = snapshot.data;
      if (job == null || job.workerId != widget.workerId || !job.hasDisclosedLocation || job.status == JobStatus.open || job.status == JobStatus.cancelled) { return EmptyState(icon: Icons.location_off_outlined,
        title: 'Destination unavailable', message: 'Navigation needs an assigned job with a disclosed pin. Erased or unassigned locations are not replaced by 0,0.', action: OutlinedButton(onPressed: () => Navigator.of(context).maybePop(), child: const Text('Back to jobs'))); }
      final distance = LocationService.distanceKm(_origin, job.location);
      return ListView(padding: const EdgeInsets.all(16), children: [
        AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(job.title, textDirection: contentDirection(job.title), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)), const SizedBox(height: 10),
          Text(job.address, textDirection: contentDirection(job.address)), Text('${job.location.latitude.toStringAsFixed(5)}, ${job.location.longitude.toStringAsFixed(5)}', style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
          const SizedBox(height: 10), Text(distance == null ? 'Distance hidden until you explicitly use one position.' : '${distance.toStringAsFixed(1)} km straight-line distance, not road distance.'),
        ])), const SizedBox(height: 14),
        ElevatedButton.icon(key: const Key('navigate-open-maps'), onPressed: _busy ? null : () => _open(job), icon: const Icon(Icons.map_outlined), label: const Text('Open in Maps')),
        OutlinedButton(key: const Key('navigate-my-position'), onPressed: _busy ? null : _locate, child: Text(_busy ? 'Working…' : 'Use one position for distance')),
        const Text('No embedded map, route-time API or background tracking. A straight-line distance cannot honestly predict a road ETA.', style: TextStyle(fontSize: 13, color: AppTheme.textMuted)),
        if (job.status == JobStatus.assigned || job.status == JobStatus.inProgress) ...[const SizedBox(height: 16), TextField(key: const Key('navigate-eta'), controller: _eta, enabled: !_busy, keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Your ETA in minutes (optional)', helperText: 'A worker estimate, not calculated travel time.')),
          OutlinedButton.icon(key: const Key('navigate-share-eta'), onPressed: _busy ? null : () => _share(job), icon: const Icon(Icons.share_location_outlined), label: const Text('Share my ETA / one position in Chat'))],
        if (_error != null) Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(_error!, style: const TextStyle(fontSize: 13, color: AppTheme.dangerRed))),
      ]);
    })),
  );
}
