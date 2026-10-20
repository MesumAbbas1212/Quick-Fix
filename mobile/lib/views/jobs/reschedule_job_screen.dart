import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:quickfix/core/theme/app_theme.dart';
import 'package:quickfix/core/utils/content_direction.dart';
import 'package:quickfix/core/widgets/app_card.dart';
import 'package:quickfix/core/widgets/empty_state.dart';
import 'package:quickfix/core/widgets/error_state.dart';
import 'package:quickfix/core/widgets/loading_list.dart';
import 'package:quickfix/models/job_model.dart';
import 'package:quickfix/services/job_service.dart';

class RescheduleJobScreen extends StatefulWidget {
  final String jobId;
  final String userId;
  final bool initialCancel;
  final JobService? jobService;
  const RescheduleJobScreen({super.key, required this.jobId, required this.userId, this.initialCancel = false, this.jobService});
  @override
  State<RescheduleJobScreen> createState() => _RescheduleJobScreenState();
}
class _RescheduleJobScreenState extends State<RescheduleJobScreen> {
  late final JobService _jobs = widget.jobService ?? JobService();
  late Stream<JobModel?> _stream = _watch();
  late bool _cancel = widget.initialCancel;
  bool _busy = false;
  DateTime? _date;
  DateTime? _time;
  bool _timeChanged = false;
  String? _reason;
  String? _error;
  final _detail = TextEditingController();
  static const _reasons = ['Plans changed', 'Schedule conflict', 'No longer needed', 'Other'];
  Stream<JobModel?> _watch() { try { return _jobs.watchJob(widget.jobId); } catch (error, stack) { return Stream.error(error, stack); } }
  void _retry() => setState(() { _stream = _watch(); _error = null; });
  @override
  void dispose() { _detail.dispose(); super.dispose(); }
  Future<void> _chooseDate(JobModel job) async {
    final now = DateTime.now(); final first = DateTime(now.year, now.month, now.day); final selected = _date ?? job.preferredDate;
    final last = first.add(const Duration(days: 365));
    final picked = await showDatePicker(context: context, initialDate: selected.isBefore(first) ? first : selected.isAfter(last) ? last : selected,
      firstDate: first, lastDate: last);
    if (picked != null && mounted) setState(() { _date = picked; });
  }
  Future<void> _chooseTime(JobModel job) async {
    final current = _timeChanged ? _time : job.preferredTime;
    final picked = await showTimePicker(context: context, initialTime: current == null ? TimeOfDay.now() : TimeOfDay.fromDateTime(current));
    if (picked != null && mounted) setState(() { _timeChanged = true; _time = DateTime(2000, 1, 1, picked.hour, picked.minute); });
  }
  Future<void> _save(JobModel job) async {
    if (_busy) return;
    final date = _date ?? job.preferredDate; final time = _timeChanged ? _time : job.preferredTime;
    if (_cancel && (_reason == null || (_reason == 'Other' && _detail.text.trim().length < 5))) { setState(() { _error = 'Choose a reason; add details for Other.'; }); return; }
    if (!_cancel && !JobService.validSchedule(date, time, DateTime.now())) { setState(() { _error = 'Choose a future date/time, not a past appointment.'; }); return; }
    final confirmed = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(title: Text(_cancel ? 'Cancel this job?' : 'Change the schedule?'),
      content: Text(_cancel ? 'The worker receives an in-app update. This job stays cancelled and does not automatically return to the board. Post a new job to hire again.' : 'The worker receives an in-app schedule update. Confirm the new appointment with them in Chat.'),
      actions: [TextButton(autofocus: true, onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Keep current')),
        TextButton(key: const Key('job-change-confirm'), onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Confirm'))]));
    if (confirmed != true || !mounted) return;
    setState(() { _busy = true; _error = null; });
    try {
      await _jobs.changeSchedule(jobId: job.id, ownerId: widget.userId, cancel: _cancel, date: date, time: time,
        reason: _cancel ? '$_reason${_detail.text.trim().isEmpty ? '' : ': ${_detail.text.trim()}'}' : null);
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_cancel ? 'Job cancelled' : 'Schedule updated'))); Navigator.of(context).pop(true); }
    } catch (_) { if (mounted) setState(() { _error = 'Could not save this change. The job may have changed; refresh and retry.'; }); }
    finally { if (mounted) setState(() { _busy = false; }); }
  }
  @override
  Widget build(BuildContext context) => PopScope(canPop: !_busy, child: Scaffold(backgroundColor: AppTheme.bgLight,
    appBar: AppBar(title: const Text('Schedule or cancel', maxLines: 1, overflow: TextOverflow.ellipsis)),
    body: SafeArea(child: StreamBuilder<JobModel?>(stream: _stream, builder: (context, snapshot) {
      if (snapshot.hasError) return ErrorState(message: 'Could not load the current schedule.', onRetry: _retry);
      if (!snapshot.hasData && snapshot.connectionState == ConnectionState.waiting) return const LoadingList();
      final job = snapshot.data;
      if (job == null) return EmptyState(icon: Icons.work_off_outlined, title: 'Job unavailable', message: 'Return to your jobs or reload.', action: OutlinedButton(onPressed: _retry, child: const Text('Reload')));
      if (job.userId != widget.userId || job.anonymized || !(job.status == JobStatus.assigned || job.status == JobStatus.inProgress)) {
        return EmptyState(icon: Icons.lock_outline, title: 'Changes are unavailable', message: 'Only the client can change assigned or in-progress work. Completed/cancelled history stays read-only.', action: OutlinedButton(onPressed: () => Navigator.of(context).maybePop(), child: const Text('Back to job')));
      }
      final date = _date ?? job.preferredDate; final time = _timeChanged ? _time : job.preferredTime;
      return ListView(padding: const EdgeInsets.all(16), children: [
        AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(job.title, textDirection: contentDirection(job.title), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8), Text('Current: ${intl.DateFormat('d MMM yyyy', 'en').format(job.preferredDate)}${job.preferredTime == null ? '' : ', ${intl.DateFormat('HH:mm', 'en').format(job.preferredTime!)}'}', style: const TextStyle(fontSize: 13))])),
        SwitchListTile(key: const Key('job-change-cancel-mode'), contentPadding: EdgeInsets.zero, value: _cancel, onChanged: _busy ? null : (value) => setState(() { _cancel = value; _error = null; }), title: const Text('Cancel instead of reschedule')),
        if (!_cancel) ...[
          OutlinedButton(key: const Key('job-change-date'), onPressed: _busy ? null : () => _chooseDate(job), child: Text('Date: ${intl.DateFormat('d MMM yyyy', 'en').format(date)}')),
          OutlinedButton(key: const Key('job-change-time'), onPressed: _busy ? null : () => _chooseTime(job), child: Text(time == null ? 'Choose time (optional)' : 'Time: ${intl.DateFormat('HH:mm', 'en').format(time)}')),
          if (time != null) TextButton(onPressed: _busy ? null : () => setState(() { _timeChanged = true; _time = null; }), child: const Text('Remove chosen time')),
        ] else ...[
          RadioGroup<String>(groupValue: _reason, onChanged: (value) { if (!_busy) setState(() { _reason = value; }); }, child: Column(children: [
            for (final reason in _reasons) RadioListTile<String>(key: Key('cancel-reason-$reason'), title: Text(reason), value: reason, enabled: !_busy),
          ])),
          TextField(key: const Key('job-change-detail'), controller: _detail, enabled: !_busy, maxLength: 350, minLines: 1, maxLines: 4, textDirection: contentDirection(_detail.text), onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'Reason details (required for Other)')),
          const Text('Cancellation ends the active booking, not a completed job or real payment. It does not reopen the board listing.', style: TextStyle(fontSize: 13, color: AppTheme.textMuted)),
        ],
        if (_error != null) Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(_error!, style: const TextStyle(fontSize: 13, color: AppTheme.dangerRed))),
        const SizedBox(height: 16), ElevatedButton(key: const Key('job-change-submit'), onPressed: _busy ? null : () => _save(job), child: Text(_busy ? 'Saving…' : _cancel ? 'Cancel job' : 'Confirm new schedule')),
      ]);
    })),
  ));
}
