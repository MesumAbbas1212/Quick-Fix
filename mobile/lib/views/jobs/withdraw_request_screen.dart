import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:quickfix/core/theme/app_theme.dart';
import 'package:quickfix/core/utils/content_direction.dart';
import 'package:quickfix/core/widgets/app_card.dart';
import 'package:quickfix/core/widgets/empty_state.dart';
import 'package:quickfix/core/widgets/error_state.dart';
import 'package:quickfix/core/widgets/loading_list.dart';
import 'package:quickfix/models/job_model.dart';
import 'package:quickfix/models/job_request.dart';
import 'package:quickfix/services/job_service.dart';
import 'package:quickfix/services/job_request_service.dart';
class WithdrawRequestScreen extends StatefulWidget {
  final String requestId, workerId;
  final JobRequestService? requestService;
  final JobService? jobService;
  const WithdrawRequestScreen({super.key, required this.requestId, required this.workerId, this.requestService, this.jobService});
  @override
  State<WithdrawRequestScreen> createState() => _WithdrawRequestScreenState();
}
class _WithdrawRequestScreenState extends State<WithdrawRequestScreen> {
  late final JobRequestService _requests = widget.requestService ?? JobRequestService();
  late final JobService _jobs = widget.jobService ?? JobService();
  late Stream<JobRequest?> _stream = _watch();
  final _titles = <String, Future<JobModel?>>{};
  bool _busy = false;
  String? _error;
  Stream<JobRequest?> _watch() { try { return _requests.watchRequest(widget.requestId); } catch (error, stack) { return Stream.error(error, stack); } }
  void _retry() => setState(() { _stream = _watch(); _titles.clear(); });
  Future<JobModel?> _job(String id) async => await _jobs.getJob(id).timeout(const Duration(seconds: 8));
  Future<void> _withdraw() async {
    if (_busy) return;
    final yes = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(title: const Text('Withdraw this application?'), content: const Text('The client will no longer see it among pending applicants. This does not cancel an accepted booking.'),
      actions: [TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Keep application')), TextButton(key: const Key('withdraw-confirm'), onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Withdraw'))]));
    if (yes != true || !mounted) return; setState(() { _busy = true; _error = null; });
    try { await _requests.withdrawRequest(requestId: widget.requestId, workerId: widget.workerId); }
    catch (_) { if (mounted) setState(() { _error = 'Could not withdraw. The client may already have decided; refresh and retry if still pending.'; }); }
    finally { if (mounted) setState(() { _busy = false; }); }
  }
  @override
  Widget build(BuildContext context) => PopScope(canPop: !_busy, child: Scaffold(backgroundColor: AppTheme.bgLight, appBar: AppBar(title: const Text('Application status'), actions: [IconButton(tooltip: 'Refresh application', onPressed: _busy ? null : _retry, icon: const Icon(Icons.refresh))]),
    body: SafeArea(child: StreamBuilder<JobRequest?>(stream: _stream, builder: (context, snapshot) {
      if (snapshot.hasError) return ErrorState(message: 'Could not load this application.', onRetry: _retry);
      if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) return const LoadingList();
      final request = snapshot.data;
      if (request == null) return EmptyState(icon: Icons.assignment_outlined, title: 'Application unavailable', message: 'It may have been removed during account cleanup.', action: OutlinedButton(onPressed: _retry, child: const Text('Reload')));
      if (request.workerId != widget.workerId) return const ErrorState(message: 'Only the applicant can manage this request.');
      return ListView(padding: const EdgeInsets.all(16), children: [AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        FutureBuilder<JobModel?>(future: _titles.putIfAbsent(request.jobId, () => _job(request.jobId)), builder: (context, job) => Text(job.hasError ? 'Job title unavailable' : job.connectionState == ConnectionState.waiting ? 'Loading job…' : job.data?.title ?? 'Job no longer available',
          textDirection: contentDirection(job.data?.title ?? ''), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
        const SizedBox(height: 10), Text('Applied ${intl.DateFormat('d MMM yyyy, HH:mm', 'en').format(request.createdAt)}'),
        if (request.message?.trim().isNotEmpty ?? false) Text(request.message!, textDirection: contentDirection(request.message!), style: const TextStyle(fontSize: 13)),
        const SizedBox(height: 10), Text('Status: ${request.status.name}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 10), Text(switch (request.status) {
          JobRequestStatus.pending => 'Withdraw before the client selects you. Applicant selection and withdrawal are checked transactionally.',
          JobRequestStatus.accepted => 'Already accepted: this is a booking. Application withdrawal cannot cancel an assigned job.',
          JobRequestStatus.declined => 'The client already declined this application. There is no pending request to withdraw.',
          JobRequestStatus.withdrawn => 'You withdrew this request. It is retained as history, not a pending applicant.',
        }, style: const TextStyle(fontSize: 13, color: AppTheme.textMuted)),
      ])), if (_error != null) Padding(padding: const EdgeInsets.symmetric(vertical: 14), child: Text(_error!, style: const TextStyle(fontSize: 13, color: AppTheme.dangerRed))),
        if (request.status == JobRequestStatus.pending) ElevatedButton(key: const Key('withdraw-request'), onPressed: _busy ? null : _withdraw, style: ElevatedButton.styleFrom(backgroundColor: AppTheme.dangerRed, foregroundColor: AppTheme.surfaceWhite), child: Text(_busy ? 'Withdrawing…' : 'Withdraw request')),
        if (request.status != JobRequestStatus.pending) TextButton(onPressed: () => Navigator.of(context).maybePop(), child: const Text('Back to jobs')),
      ]);
    })),
  ));
}
