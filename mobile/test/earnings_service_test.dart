import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quickfix/models/earnings_summary.dart';
import 'package:quickfix/models/job_model.dart';
import 'package:quickfix/models/payment_model.dart';
import 'package:quickfix/services/earnings_service.dart';

final _now = DateTime.utc(2026, 10, 18, 12);
Payment _payment(String id, double amount, DateTime date, {
  String jobId = 'j1', String worker = 'w1', String status = 'paid',
}) => Payment(id: id, jobId: jobId, payerId: 'c1', workerId: worker,
    amount: amount, status: status, createdAt: date);
JobModel _job(String id, DateTime at, {String worker = 'w1', JobStatus status = JobStatus.completed}) => JobModel(
  id: id, userId: 'c1', workerId: worker, title: 'Sink repair', description: 'Work',
  category: JobCategory.plumbing, address: 'Attock', location: const GeoPoint(33.77, 72.37),
  budgetMin: 1000, budgetMax: 5000, preferredDate: at, status: status,
  createdAt: at, updatedAt: at, completedAt: at,
);

void main() {
  group('EarningsService', () {
    const service = EarningsService();
    EarningsSummary calculate({List<Payment> payments = const [], List<JobModel> jobs = const [],
      EarningsPeriod period = EarningsPeriod.month}) => service.summarize(
      workerId: 'w1', payments: payments, jobs: jobs, period: period, now: _now,
    );

    test('week starts Monday, month and year start at midnight', () {
      expect(service.periodStart(EarningsPeriod.week, _now), DateTime.utc(2026, 10, 12));
      expect(service.periodStart(EarningsPeriod.month, _now), DateTime.utc(2026, 10, 1));
      expect(service.periodStart(EarningsPeriod.year, _now), DateTime.utc(2026, 1, 1));
      expect(service.periodStart(EarningsPeriod.week, DateTime.utc(2026, 1, 1)), DateTime.utc(2025, 12, 29));
    });
    test('empty history has zero income and exactly eight zero-filled weeks', () {
      final result = calculate();
      expect(result.received, 0);
      expect(result.rows, isEmpty);
      expect(result.weeks.length, 8);
      expect(result.weeks.every((week) => week.amount == 0), isTrue);
      expect(result.weeks.last.start, DateTime.utc(2026, 10, 12));
      expect(result.weeks.first.start, DateTime.utc(2026, 8, 24));
    });
    test('only paid receipts count as income, not pending or failed attempts', () {
      final result = calculate(payments: [
        _payment('paid', 2500, _now),
        _payment('pending', 10000, _now, jobId: 'j2', status: 'pending'),
        _payment('failed', 8000, _now, jobId: 'j3', status: 'failed'),
      ]);
      expect(result.received, 2500);
      expect(result.paidJobCount, 1);
      expect(result.rows.map((r) => r.status), containsAll(['Paid', 'Awaiting payment', 'Payment failed']));
    });
    test('a completed budget is an estimate, never received income', () {
      final result = calculate(jobs: [_job('j1', _now)]);
      expect(result.received, 0);
      expect(result.completedJobCount, 1);
      expect(result.paidJobCount, 0);
      expect(result.rows.single.estimate, 5000);
      expect(result.rows.single.received, 0);
      expect(result.rows.single.status, 'Awaiting payment');
    });
    test('multiple receipts add together but the paid job count is unique', () {
      final result = calculate(payments: [
        _payment('p1', 1000, _now), _payment('p2', 1500, _now),
      ], jobs: [_job('j1', _now)]);
      expect(result.received, 2500);
      expect(result.paidJobCount, 1);
      expect(result.rows.single.received, 2500);
      expect(result.rows.single.receiptCount, 2);
      expect(result.rows.single.title, 'Sink repair');
    });
    test('income uses receipt date, not the earlier completion date', () {
      final result = calculate(payments: [_payment('p1', 2500, _now)],
          jobs: [_job('j1', DateTime.utc(2026, 8, 1))]);
      expect(result.received, 2500);
      expect(result.completedJobCount, 0);
      expect(result.rows.single.date, _now);
    });
    test('period boundaries are inclusive, future records are ignored', () {
      final result = calculate(payments: [
        _payment('edge', 10, DateTime.utc(2026, 10, 1)),
        _payment('before', 20, DateTime.utc(2026, 9, 30, 23, 59)),
        _payment('now', 30, _now),
        _payment('future', 100, _now.add(const Duration(seconds: 1))),
      ]);
      expect(result.received, 40);
    });
    test('another worker and non-completed jobs cannot inflate the summary', () {
      final result = calculate(payments: [_payment('p1', 500, _now, worker: 'other')], jobs: [
        _job('j1', _now, worker: 'other'), _job('j2', _now, status: JobStatus.assigned),
      ]);
      expect(result.received, 0);
      expect(result.completedJobCount, 0);
      expect(result.rows, isEmpty);
    });
    test('invalid amounts do not break totals or chart scales', () {
      final result = calculate(payments: [
        _payment('negative', -100, _now), _payment('nan', double.nan, _now),
        _payment('infinite', double.infinity, _now), _payment('valid', 50, _now),
      ]);
      expect(result.received, 50);
      expect(result.weeks.last.amount, 50);
    });
    test('the chart assigns Monday boundaries to the following week', () {
      final result = calculate(payments: [
        _payment('sun', 100, DateTime.utc(2026, 10, 11, 23, 59)),
        _payment('mon', 200, DateTime.utc(2026, 10, 12)),
      ]);
      expect(result.weeks[result.weeks.length - 2].amount, 100);
      expect(result.weeks.last.amount, 200);
    });
    test('the eight-week chart ignores earlier income without removing it from yearly totals', () {
      final result = calculate(period: EarningsPeriod.year, payments: [
        _payment('old', 900, DateTime.utc(2026, 1, 1)),
        _payment('recent', 100, _now),
      ]);
      expect(result.received, 1000);
      expect(result.weeks.fold<double>(0, (sum, w) => sum + w.amount), 100);
    });
    test('paid archived jobs still count and have a stable fallback title', () {
      final result = calculate(payments: [_payment('p1', 1000, _now, jobId: 'archived')]);
      expect(result.received, 1000);
      expect(result.rows.single.title, 'Job archived');
    });
    test('a job paid outside the period is not incorrectly labelled unpaid', () {
      final result = calculate(payments: [_payment('p1', 1000, DateTime.utc(2026, 9, 30))],
          jobs: [_job('j1', _now)]);
      expect(result.received, 0);
      expect(result.completedJobCount, 1);
      expect(result.rows, isEmpty);
    });
  });
}
