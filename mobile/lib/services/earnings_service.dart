import 'package:quickfix/models/earnings_summary.dart';
import 'package:quickfix/models/job_model.dart';
import 'package:quickfix/models/payment_model.dart';

/// Pure calculations over existing job/payment streams. No queries, polling,
/// budget-as-income, or chart package. Paid receipts are cash-basis income;
/// unpaid completed jobs show a clearly labelled estimate, excluded from totals.
class EarningsService {
  const EarningsService();

  DateTime _date(DateTime clock, int year, int month, int day) => clock.isUtc
      ? DateTime.utc(year, month, day)
      : DateTime(year, month, day);

  DateTime periodStart(EarningsPeriod period, DateTime now) {
    return switch (period) {
      EarningsPeriod.week => _date(now, now.year, now.month, now.day - now.weekday + 1),
      EarningsPeriod.month => _date(now, now.year, now.month, 1),
      EarningsPeriod.year => _date(now, now.year, 1, 1),
    };
  }

  EarningsSummary summarize({
    required String workerId,
    required Iterable<Payment> payments,
    required Iterable<JobModel> jobs,
    required EarningsPeriod period,
    required DateTime now,
  }) {
    final start = periodStart(period, now);
    bool inPeriod(DateTime date) => !date.isBefore(start) && !date.isAfter(now);
    final completed = {
      for (final job in jobs)
        if (job.workerId == workerId && job.status == JobStatus.completed)
          job.id: job,
    };
    final validPayments = payments.where((p) =>
        p.workerId == workerId && p.amount.isFinite && p.amount >= 0 &&
        !p.createdAt.isAfter(now)).toList();
    final paid = validPayments.where((p) => p.status == 'paid').toList();
    final selectedPaid = paid.where((p) => inPeriod(p.createdAt)).toList();
    final selectedPayments = validPayments.where((p) => inPeriod(p.createdAt)).toList();
    final ids = {
      ...selectedPayments.map((p) => p.jobId),
      ...completed.values
          .where((j) => inPeriod(j.completedAt ?? j.updatedAt))
          .map((j) => j.id),
    };
    final rows = <JobEarnings>[];
    for (final id in ids) {
      final receipts = selectedPaid.where((p) => p.jobId == id).toList();
      final attempts = selectedPayments.where((p) => p.jobId == id).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      final job = completed[id];
      // A receipt outside the selected period is not "awaiting payment".
      if (receipts.isEmpty && paid.any((p) => p.jobId == id)) continue;
      final received = receipts.fold<double>(0, (sum, p) => sum + p.amount);
      final date = attempts.isNotEmpty
          ? attempts.first.createdAt
          : job?.completedAt ?? job?.updatedAt ?? now;
      rows.add(JobEarnings(
        jobId: id,
        title: job?.title ?? 'Job $id',
        date: date,
        received: received,
        estimate: job?.budgetMax ?? 0,
        receiptCount: receipts.length,
        status: receipts.isNotEmpty
            ? 'Paid'
            : attempts.isNotEmpty && attempts.first.status == 'failed'
                ? 'Payment failed' : 'Awaiting payment',
      ));
    }
    rows.sort((a, b) {
      final order = b.date.compareTo(a.date);
      return order != 0 ? order : a.jobId.compareTo(b.jobId);
    });
    final monday = periodStart(EarningsPeriod.week, now);
    final weeks = [
      for (var i = 7; i >= 0; i--)
        _date(now, monday.year, monday.month, monday.day - i * 7),
    ];
    return EarningsSummary(
      received: selectedPaid.fold<double>(0, (sum, p) => sum + p.amount),
      paidJobCount: selectedPaid.map((p) => p.jobId).toSet().length,
      completedJobCount: completed.values
          .where((j) => inPeriod(j.completedAt ?? j.updatedAt)).length,
      weeks: List.unmodifiable(weeks.map((week) {
        final end = _date(now, week.year, week.month, week.day + 7);
        final sum = paid.where((p) =>
            !p.createdAt.isBefore(week) && p.createdAt.isBefore(end))
            .fold<double>(0, (total, p) => total + p.amount);
        return WeeklyEarnings(start: week, amount: sum);
      })),
      rows: List.unmodifiable(rows),
    );
  }
}
