enum EarningsPeriod { week, month, year }

class WeeklyEarnings {
  final DateTime start;
  final double amount;

  const WeeklyEarnings({required this.start, required this.amount});
}

class JobEarnings {
  final String jobId;
  final String title;
  final DateTime date;
  final double received;
  final double estimate;
  final int receiptCount;
  final String status;

  const JobEarnings({
    required this.jobId,
    required this.title,
    required this.date,
    required this.received,
    required this.estimate,
    required this.receiptCount,
    required this.status,
  });
}

class EarningsSummary {
  final double received;
  final int paidJobCount;
  final int completedJobCount;
  final List<WeeklyEarnings> weeks;
  final List<JobEarnings> rows;

  const EarningsSummary({
    required this.received,
    required this.paidJobCount,
    required this.completedJobCount,
    required this.weeks,
    required this.rows,
  });
}
