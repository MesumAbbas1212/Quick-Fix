import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:quickfix/core/theme/app_theme.dart';
import 'package:quickfix/core/utils/content_direction.dart';
import 'package:quickfix/core/widgets/app_card.dart';
import 'package:quickfix/core/widgets/empty_state.dart';
import 'package:quickfix/core/widgets/error_state.dart';
import 'package:quickfix/core/widgets/loading_list.dart';
import 'package:quickfix/models/job_model.dart';
import 'package:quickfix/models/user_model.dart';
import 'package:quickfix/services/auth_service.dart';
import 'package:quickfix/services/job_schedule_service.dart';
import 'package:quickfix/services/job_service.dart';
import 'package:quickfix/views/jobs/job_tracking_screen.dart';
class JobScheduleScreen extends StatefulWidget {
  final String workerId;
  final JobService? jobService;
  final AuthService? authService;
  final JobScheduleService? scheduleService;
  final DateTime? initialDate;
  const JobScheduleScreen({super.key, required this.workerId, this.jobService, this.authService, this.scheduleService, this.initialDate});
  @override
  State<JobScheduleScreen> createState() => _JobScheduleScreenState();
}
class _JobScheduleScreenState extends State<JobScheduleScreen> {
  late final JobService _jobs = widget.jobService ?? JobService();
  late final AuthService _auth = widget.authService ?? AuthService();
  late final JobScheduleService _schedule = widget.scheduleService ?? const JobScheduleService();
  late DateTime _day = widget.initialDate ?? DateTime.now();
  late DateTime _month = DateTime(_day.year, _day.month);
  late Stream<List<JobModel>> _stream = _watch();
  final _clients = <String, Future<UserModel?>>{};
  Stream<List<JobModel>> _watch() { try { return _jobs.watchScheduledJobs(widget.workerId); } catch (error, stack) { return Stream.error(error, stack); } }
  void _retry() => setState(() { _stream = _watch(); _clients.clear(); });
  void _move(int months) => setState(() { _month = DateTime(_month.year, _month.month + months); _day = _month; });
  Future<UserModel?> _loadClient(String uid) async => await _auth.getUserProfile(uid).timeout(const Duration(seconds: 8));
  @override
  Widget build(BuildContext context) => Scaffold(backgroundColor: AppTheme.bgLight, appBar: AppBar(title: const Text('Job schedule'), actions: [IconButton(tooltip: 'Refresh schedule', onPressed: _retry, icon: const Icon(Icons.refresh))]),
    body: SafeArea(child: StreamBuilder<List<JobModel>>(stream: _stream, builder: (context, snapshot) {
      if (snapshot.hasError) return ErrorState(message: 'Could not load booked jobs.', onRetry: _retry);
      if (!snapshot.hasData) return const LoadingList();
      final jobs = snapshot.data!; final selected = _schedule.onDay(jobs, widget.workerId, _day);
      // The month navigation and the calendar (weekday header + day grid)
      // stay fixed; only the selected day's bookings scroll below them.
      return Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(14, 14, 14, 0), child: Row(children: [IconButton(key: const Key('schedule-previous'), tooltip: 'Previous month', onPressed: () => _move(-1), icon: const Icon(Icons.chevron_left)),
          Expanded(child: Text(intl.DateFormat('MMMM yyyy', 'en').format(_month), textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
          IconButton(key: const Key('schedule-next'), tooltip: 'Next month', onPressed: () => _move(1), icon: const Icon(Icons.chevron_right))])),
        // The calendar width is capped so that a six-row month grid
        // always fits the pinned area on wide, short viewports
        // (e.g. the 800x600 test surface); narrower phones are
        // unaffected because their viewport is the smaller bound.
        Padding(padding: const EdgeInsets.symmetric(horizontal: 14), child: LayoutBuilder(builder: (context, constraints) => SingleChildScrollView(scrollDirection: Axis.horizontal, child: SizedBox(width: math.min(math.max(math.max(320.0, constraints.maxWidth), MediaQuery.textScalerOf(context).scale(12) * 17.5), 440.0).toDouble(), child: Column(children: [
          Row(children: [for (final label in ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']) Expanded(child: Center(child: Text(label, style: const TextStyle(fontSize: 12))))]),
          GridView.count(crossAxisCount: 7, childAspectRatio: .85, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), children: [for (final date in _schedule.monthCells(_month))
            date == null ? const SizedBox() : TextButton(key: Key('schedule-day-${date.day}'), onPressed: () => setState(() { _day = date; }),
              style: TextButton.styleFrom(padding: EdgeInsets.zero, backgroundColor: _day.year == date.year && _day.month == date.month && _day.day == date.day ? AppTheme.brandBlue.withValues(alpha: .1) : null),
              child: Column(mainAxisSize: MainAxisSize.min, children: [Text('${date.day}', style: const TextStyle(fontSize: 12)),
                if (_schedule.onDay(jobs, widget.workerId, date).isNotEmpty) const Icon(Icons.circle, size: 6, color: AppTheme.ctaOrange)]))]),
        ]))))),
        Expanded(child: ListView(padding: const EdgeInsets.all(14), children: [
        const Text('Dots indicate booked days, not estimated job durations. Swipe the calendar horizontally if needed on a narrow screen.', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
        const SizedBox(height: 14), Text(intl.DateFormat('EEE, d MMM', 'en').format(_day), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        if (_schedule.inMonth(jobs, widget.workerId, _month) == 0) EmptyState(icon: Icons.calendar_month_outlined, title: 'No bookings this month', message: 'Check another month or return to your jobs.', action: OutlinedButton(onPressed: () => _move(1), child: const Text('Next month')))
        else if (selected.isEmpty) EmptyState(icon: Icons.event_available_outlined, title: 'No bookings on this day', message: 'Choose a day with a dot or return to today.', action: OutlinedButton(onPressed: () => setState(() { _day = DateTime.now(); _month = DateTime(_day.year, _day.month); }), child: const Text('Today'))),
        if (selected.length > 1) const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Text('Multiple bookings: confirm times and travel with each client. Durations are unknown.', style: TextStyle(fontSize: 13, color: AppTheme.textMuted))),
        for (final job in selected) Padding(padding: const EdgeInsets.only(top: 12), child: AppCard(padding: 0, child: ListTile(key: Key('schedule-job-${job.id}'),
          title: Text(job.title, textDirection: contentDirection(job.title)), subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${job.preferredTime == null ? 'Time not provided' : intl.DateFormat('HH:mm', 'en').format(job.preferredTime!)} • ${job.status.name}'),
            FutureBuilder<UserModel?>(future: _clients.putIfAbsent(job.userId, () => _loadClient(job.userId)), builder: (context, client) => Text(client.hasError ? 'Client name unavailable' : client.connectionState == ConnectionState.waiting ? 'Loading client…' : client.data?.fullName ?? 'Former client', textDirection: contentDirection(client.data?.fullName ?? ''), style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)))]),
          trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => JobTrackingScreen(jobId: job.id, myId: widget.workerId, jobService: widget.jobService, authService: widget.authService)))))),
        ])),
      ]);
    })),
  );
}
