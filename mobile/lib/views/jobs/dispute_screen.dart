import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:quickfix/core/theme/app_theme.dart';
import 'package:quickfix/core/utils/content_direction.dart';
import 'package:quickfix/core/widgets/app_card.dart';
import 'package:quickfix/core/widgets/empty_state.dart';
import 'package:quickfix/core/widgets/error_state.dart';
import 'package:quickfix/core/widgets/loading_list.dart';
import 'package:quickfix/core/widgets/local_photo_viewer.dart';
import 'package:quickfix/models/dispute_case.dart';
import 'package:quickfix/models/job_model.dart';
import 'package:quickfix/models/payment_model.dart';
import 'package:quickfix/services/dispute_service.dart';
import 'package:quickfix/services/job_service.dart';
import 'package:quickfix/services/payment_service.dart';
import 'package:quickfix/services/local_image_store.dart';
class DisputeScreen extends StatefulWidget {
  final String jobId, userId;
  final DisputeService? disputeService;
  final JobService? jobService;
  final PaymentService? paymentService;
  final LocalImageStore? imageStore;
  final ImagePicker? imagePicker;
  const DisputeScreen({super.key, required this.jobId, required this.userId, this.disputeService, this.jobService, this.paymentService, this.imageStore, this.imagePicker});
  @override
  State<DisputeScreen> createState() => _DisputeScreenState();
}
class _DisputeScreenState extends State<DisputeScreen> {
  late final DisputeService _cases = widget.disputeService ?? DisputeService();
  late final JobService _jobs = widget.jobService ?? JobService();
  late final PaymentService _payments = widget.paymentService ?? PaymentService();
  late Future<(JobModel?, DisputeCase?, List<Payment>)> _future = _load();
  final _description = TextEditingController();
  String? _category, _resolution, _error;
  final _paths = <String>[];
  bool _busy = false;
  Future<(JobModel?, DisputeCase?, List<Payment>)> _load() async {
    final job = await _jobs.getJob(widget.jobId).timeout(const Duration(seconds: 8));
    final existing = await _cases.getForJob(widget.jobId); final receipts = await _payments.getPaymentsForJob(widget.jobId).timeout(const Duration(seconds: 8));
    return (job, existing, receipts);
  }
  @override
  void dispose() { _description.dispose(); super.dispose(); }
  void _retry() => setState(() { _future = _load(); });
  Future<void> _photos() async {
    if (_busy || _paths.length >= 5) { return; } setState(() { _busy = true; _error = null; });
    try {
      final picked = await (widget.imagePicker ?? ImagePicker()).pickMultiImage(maxWidth: 1600, imageQuality: 80).timeout(const Duration(minutes: 2));
      if (picked.isEmpty) { return; }
      final paths = await (widget.imageStore ?? const LocalImageStore()).saveImages(picked.take(5 - _paths.length).toList()).timeout(const Duration(seconds: 8));
      if (mounted) { setState(() { _paths.addAll(paths); }); }
    } catch (_) { if (mounted) { setState(() { _error = 'Could not copy evidence photos. Retry; photos are not remote uploads.'; }); } }
    finally { if (mounted) { setState(() { _busy = false; }); } }
  }
  Future<void> _submit() async {
    if (_busy) { return; }
    if (_category == null || _resolution == null || _description.text.trim().length < 20) { setState(() { _error = 'Choose the issue/resolution and write at least 20 characters.'; }); return; }
    setState(() { _busy = true; _error = null; });
    try { await _cases.submit(jobId: widget.jobId, raisedBy: widget.userId, category: _category!, description: _description.text.trim(), expectedResolution: _resolution!, images: List.of(_paths)); if (mounted) { _retry(); } }
    catch (_) { if (mounted) { setState(() { _error = 'Case submission was not confirmed. Refresh before retrying; a single case may already exist.'; }); } }
    finally { if (mounted) { setState(() { _busy = false; }); } }
  }
  @override
  Widget build(BuildContext context) => PopScope(canPop: !_busy, child: Scaffold(backgroundColor: AppTheme.bgLight,
    appBar: AppBar(title: const Text('Job dispute'), actions: [IconButton(tooltip: 'Refresh dispute status', onPressed: _busy ? null : _retry, icon: const Icon(Icons.refresh))]),
    body: SafeArea(child: FutureBuilder<(JobModel?, DisputeCase?, List<Payment>)>(future: _future, builder: (context, snapshot) {
      if (snapshot.hasError) { return ErrorState(message: 'Could not load the job/case/receipts.', onRetry: _retry); }
      if (!snapshot.hasData) { return const LoadingList(); }
      final job = snapshot.data!.$1; final existing = snapshot.data!.$2;
      if (existing != null) { return ListView(padding: const EdgeInsets.all(16), children: [AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(existing.status == 'open' ? 'Submitted for manual review' : 'Case ${existing.status}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)), const SizedBox(height: 10),
        const Text('Response target: 48 hours, not a guaranteed SLA in this prototype. No automatic reply, refund or real funds transfer is triggered.', style: TextStyle(fontSize: 13, color: AppTheme.textMuted)), const SizedBox(height: 10),
        Text(existing.category), Text(existing.description, textDirection: contentDirection(existing.description)), Text('Requested: ${existing.expectedResolution}'),
        if (existing.resolutionNote?.isNotEmpty ?? false) Text(existing.resolutionNote!, textDirection: contentDirection(existing.resolutionNote!)),
        const SizedBox(height: 10), const Text('One case per completed job is retained. Read Privacy for moderation/evidence retention; local image files are not remotely viewable.'),
      ]))]); }
      if (job == null || job.anonymized || job.status != JobStatus.completed || (job.userId != widget.userId && job.workerId != widget.userId)) { return EmptyState(icon: Icons.lock_outline, title: 'Dispute unavailable', message: 'Only participants of a completed, non-erased job can open this flow.', action: OutlinedButton(onPressed: () => Navigator.of(context).maybePop(), child: const Text('Back to job'))); }
      return ListView(padding: const EdgeInsets.all(16), children: [
        AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(job.title, textDirection: contentDirection(job.title), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          Text('Recorded paid receipts: PKR ${DisputeService.paidTotal(snapshot.data!.$3).toStringAsFixed(2)} • simulation only'), const Text('Describe the problem; avoid passwords, bank secrets or identity documents. Evidence photos stay on this device, so admins need a separate approved channel for images.', style: TextStyle(fontSize: 13, color: AppTheme.textMuted))])),
        RadioGroup<String>(groupValue: _category, onChanged: (value) { if (!_busy) { setState(() { _category = value; }); } }, child: Column(children: [for (final category in DisputeCase.categories) RadioListTile<String>(key: Key('dispute-category-$category'), title: Text(category), value: category, enabled: !_busy)])),
        TextField(key: const Key('dispute-description'), controller: _description, enabled: !_busy, minLines: 3, maxLines: 8, maxLength: 2000, textDirection: contentDirection(_description.text), onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'What happened?')),
        OutlinedButton.icon(key: const Key('dispute-photos'), onPressed: _busy || _paths.length >= 5 ? null : _photos, icon: const Icon(Icons.photo_library_outlined), label: Text('Add local evidence (${_paths.length}/5)')),
        for (final path in _paths) Row(children: [Expanded(child: LocalPhotoThumb(path: path, imageStore: widget.imageStore)), IconButton(tooltip: 'Remove draft evidence reference', onPressed: _busy ? null : () => setState(() { _paths.remove(path); }), icon: const Icon(Icons.close))]),
        const Text('Expected resolution', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        RadioGroup<String>(groupValue: _resolution, onChanged: (value) { if (!_busy) { setState(() { _resolution = value; }); } }, child: Column(children: [for (final resolution in DisputeCase.resolutions) RadioListTile<String>(key: Key('dispute-resolution-$resolution'), title: Text(resolution), value: resolution, enabled: !_busy)])),
        if (_error != null) Text(_error!, style: const TextStyle(fontSize: 13, color: AppTheme.dangerRed)),
        ElevatedButton(key: const Key('dispute-submit'), onPressed: _busy ? null : _submit, child: Text(_busy ? 'Submitting…' : 'Submit dispute')),
      ]);
    })),
  ));
}
