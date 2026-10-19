import 'package:flutter/material.dart';
import 'package:quickfix/models/dispute_case.dart';
import 'package:quickfix/services/dispute_service.dart';
import 'package:quickfix/services/job_service.dart';
import 'package:quickfix/services/payment_service.dart';
import 'package:quickfix/views/jobs/dispute_screen.dart';
class JobDisputeLink extends StatefulWidget {
  final String jobId, userId;
  final DisputeService? disputeService;
  final JobService? jobService;
  final PaymentService? paymentService;
  const JobDisputeLink({super.key, required this.jobId, required this.userId, this.disputeService, this.jobService, this.paymentService});
  @override
  State<JobDisputeLink> createState() => _JobDisputeLinkState();
}
class _JobDisputeLinkState extends State<JobDisputeLink> {
  late final DisputeService _cases = widget.disputeService ?? DisputeService();
  late final Stream<DisputeCase?> _stream = _watch();
  Stream<DisputeCase?> _watch() { try { return _cases.watchForJob(widget.jobId); } catch (error, stack) { return Stream.error(error, stack); } }
  @override
  Widget build(BuildContext context) => StreamBuilder<DisputeCase?>(stream: _stream, builder: (context, snapshot) => TextButton.icon(key: ValueKey('job-dispute-${widget.jobId}'), icon: const Icon(Icons.report_problem_outlined),
    onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => DisputeScreen(jobId: widget.jobId, userId: widget.userId, disputeService: _cases, jobService: widget.jobService, paymentService: widget.paymentService))),
    label: Text(snapshot.hasError ? 'Dispute status unavailable — open to retry' : snapshot.data == null ? 'Something went wrong?' : 'Dispute: ${snapshot.data!.status}')));
}
