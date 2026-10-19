import 'package:quickfix/models/job_model.dart';
class JobScheduleService {
  const JobScheduleService();
  List<DateTime?> monthCells(DateTime month) {
    final first = DateTime(month.year, month.month, 1); final leading = first.weekday - 1;
    final days = DateTime(month.year, month.month + 1, 0).day; final count = ((leading + days + 6) ~/ 7) * 7;
    return List.generate(count, (index) => index < leading || index >= leading + days ? null : DateTime(month.year, month.month, index - leading + 1));
  }
  bool _active(JobModel job, String uid) => job.workerId == uid && !job.anonymized && (job.status == JobStatus.assigned || job.status == JobStatus.inProgress);
  List<JobModel> onDay(Iterable<JobModel> jobs, String uid, DateTime date) => jobs.where((job) => _active(job, uid) && job.preferredDate.year == date.year && job.preferredDate.month == date.month && job.preferredDate.day == date.day).toList()
    ..sort((a, b) { final first = a.preferredTime, second = b.preferredTime; if (first == null) return second == null ? a.id.compareTo(b.id) : 1; if (second == null) return -1; return (first.hour * 60 + first.minute).compareTo(second.hour * 60 + second.minute); });
  int inMonth(Iterable<JobModel> jobs, String uid, DateTime month) => jobs.where((job) => _active(job, uid) && job.preferredDate.year == month.year && job.preferredDate.month == month.month).length;
}
