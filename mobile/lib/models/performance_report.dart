class PerformanceActivity {
  final String title;
  final String status;
  final String? jobId;
  final DateTime? date;
  const PerformanceActivity({required this.title, required this.status, this.jobId, this.date});
}
class PerformanceReport {
  final int completedJobs;
  final double? replyRate, acceptanceRate, completionRate, averageRating, scheduleProxy;
  final String suggestion;
  final List<PerformanceActivity> activity;
  const PerformanceReport({required this.completedJobs, this.replyRate, this.acceptanceRate, this.completionRate, this.averageRating,
    this.scheduleProxy, required this.suggestion, this.activity = const []});
  bool get unlocked => completedJobs >= 3;
}
