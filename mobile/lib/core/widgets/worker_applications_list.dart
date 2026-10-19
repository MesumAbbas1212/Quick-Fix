import 'package:flutter/material.dart';
import 'package:quickfix/core/theme/app_theme.dart';
import 'package:quickfix/core/widgets/empty_state.dart';
import 'package:quickfix/core/widgets/error_state.dart';
import 'package:quickfix/core/widgets/loading_list.dart';
import 'package:quickfix/models/job_request.dart';
import 'package:quickfix/services/job_request_service.dart';
import 'package:quickfix/services/job_service.dart';
import 'package:quickfix/views/jobs/withdraw_request_screen.dart';
class WorkerApplicationsList extends StatefulWidget {
  final String workerId;
  final JobRequestService? requestService;
  final JobService? jobService;
  const WorkerApplicationsList({super.key, required this.workerId, this.requestService, this.jobService});
  @override
  State<WorkerApplicationsList> createState() => _WorkerApplicationsListState();
}
class _WorkerApplicationsListState extends State<WorkerApplicationsList> {
  late final JobRequestService _requests = widget.requestService ?? JobRequestService();
  late Stream<List<JobRequest>> _stream = _watch();
  Stream<List<JobRequest>> _watch() { try { return _requests.watchWorkerRequests(widget.workerId); } catch (error, stack) { return Stream.error(error, stack); } }
  void _retry() => setState(() { _stream = _watch(); });
  @override
  Widget build(BuildContext context) => StreamBuilder<List<JobRequest>>(stream: _stream, builder: (context, snapshot) {
    if (snapshot.hasError) return ErrorState(message: 'Could not load your applications.', onRetry: _retry);
    if (!snapshot.hasData) return const SingleChildScrollView(child: LoadingList());
    if (snapshot.data!.isEmpty) return EmptyState(icon: Icons.assignment_outlined, title: 'No applications sent', message: 'Apply from the open Jobs board first.', action: OutlinedButton(onPressed: _retry, child: const Text('Refresh applications')));
    final requests = snapshot.data!;
    return ListView(padding: const EdgeInsets.all(14), children: [const Text('My applications', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      for (final request in requests) ListTile(key: Key('application-${request.id}'), leading: const Icon(Icons.assignment_outlined, color: AppTheme.brandBlue),
        title: Text('Application • ${request.status.name}'), subtitle: Text('Applied ${request.createdAt.day}/${request.createdAt.month}/${request.createdAt.year}'), trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => WithdrawRequestScreen(requestId: request.id, workerId: widget.workerId, requestService: widget.requestService, jobService: widget.jobService)))),
    ]);
  });
}
