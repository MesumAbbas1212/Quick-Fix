import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quickfix/core/widgets/loading_list.dart';
import 'package:quickfix/core/widgets/weekly_earnings_chart.dart';
import 'package:quickfix/models/job_model.dart';
import 'package:quickfix/models/payment_model.dart';
import 'package:quickfix/services/job_service.dart';
import 'package:quickfix/services/payment_service.dart';
import 'package:quickfix/views/jobs/my_jobs_screen.dart';
import 'package:quickfix/views/worker/earnings_screen.dart';

class MockJobService extends Mock implements JobService {}
class MockPaymentService extends Mock implements PaymentService {}
final _now = DateTime.utc(2026, 10, 18, 12);
JobModel _job({String title = 'Sink repair'}) => JobModel(
  id: 'j1', userId: 'c1', workerId: 'w1', title: title, description: 'Work',
  category: JobCategory.plumbing, address: 'Attock', location: const GeoPoint(33.77, 72.37),
  budgetMin: 1000, budgetMax: 5000, preferredDate: _now, status: JobStatus.completed,
  completedAt: _now, createdAt: _now, updatedAt: _now,
);
Payment _payment(String id, double amount, DateTime at) => Payment(
  id: id, jobId: 'j1', payerId: 'c1', workerId: 'w1', amount: amount, status: 'paid', createdAt: at,
);

void main() {
  group('EarningsScreen', () {
    late MockJobService jobs;
    late MockPaymentService payments;
    void data({List<JobModel> completed = const [], List<Payment> receipts = const []}) {
      when(() => jobs.watchCompletedJobsForWorker('w1'))
          .thenAnswer((_) => Stream.value(completed));
      when(() => payments.watchPaymentsByWorker('w1'))
          .thenAnswer((_) => Stream.value(receipts));
    }
    Future<void> pump(WidgetTester tester) async {
      tester.view.physicalSize = const Size(400, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(home: EarningsScreen(
        workerId: 'w1', jobService: jobs, paymentService: payments, clock: () => _now,
      )));
      await tester.pump();
    }
    setUp(() {
      jobs = MockJobService(); payments = MockPaymentService(); data();
      when(() => jobs.watchWorkerJobs('w1')).thenAnswer((_) => Stream.value(const <JobModel>[]));
    });

    testWidgets('shows skeletons until both streams have data', (tester) async {
      final controller = StreamController<List<Payment>>();
      addTearDown(controller.close);
      when(() => payments.watchPaymentsByWorker('w1')).thenAnswer((_) => controller.stream);
      await pump(tester);
      expect(find.byType(LoadingList), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
    testWidgets('empty history has a working View my jobs action', (tester) async {
      await pump(tester);
      expect(find.text('Complete your first job to see earnings'), findsOneWidget);
      await tester.tap(find.byKey(const Key('earnings-view-jobs')));
      await tester.pumpAndSettle();
      expect(find.byType(MyJobsScreen), findsOneWidget);
      final page = tester.widget<MyJobsScreen>(find.byType(MyJobsScreen));
      expect(page.workerId, 'w1');
      expect(page.jobService, same(jobs));
      verify(() => jobs.watchWorkerJobs('w1')).called(1);
    });
    testWidgets('renders paid totals, completed count, job rows and a local chart', (tester) async {
      data(completed: [_job()], receipts: [_payment('p1', 5000, _now)]);
      await pump(tester);
      expect(tester.widget<Text>(find.byKey(const Key('earnings-total'))).data, 'PKR 5,000');
      expect(find.text('1 paid job · 1 completed job'), findsOneWidget);
      expect(find.text('Sink repair'), findsOneWidget);
      expect(find.text('Paid'), findsOneWidget);
      expect(find.text('Last 8 weeks'), findsOneWidget);
      final painter = tester.widget<CustomPaint>(find.byKey(const Key('weekly-earnings-paint')))
          .painter as EarningsBarPainter;
      expect(painter.values.length, 8);
      expect(painter.values.last, 5000);
      expect(find.textContaining('No real money is transferred'), findsOneWidget);
    });
    testWidgets('period changes recalculate locally without re-fetching', (tester) async {
      data(completed: [_job()], receipts: [
        _payment('p1', 5000, _now), _payment('p2', 2500, DateTime.utc(2026, 9, 1)),
      ]);
      await pump(tester);
      expect(tester.widget<Text>(find.byKey(const Key('earnings-total'))).data, 'PKR 5,000');
      await tester.tap(find.byKey(const Key('earnings-period-year')));
      await tester.pump();
      expect(tester.widget<Text>(find.byKey(const Key('earnings-total'))).data, 'PKR 7,500');
      await tester.tap(find.byKey(const Key('earnings-period-week')));
      await tester.pump();
      expect(tester.widget<Text>(find.byKey(const Key('earnings-total'))).data, 'PKR 5,000');
      verify(() => jobs.watchCompletedJobsForWorker('w1')).called(1);
      verify(() => payments.watchPaymentsByWorker('w1')).called(1);
    });
    testWidgets('completed but unpaid work is labelled estimated, excluded from the hero', (tester) async {
      data(completed: [_job()]); await pump(tester);
      expect(tester.widget<Text>(find.byKey(const Key('earnings-total'))).data, 'PKR 0');
      expect(find.text('Awaiting payment'), findsOneWidget);
      expect(find.text('PKR 5,000 estimated — not received'), findsOneWidget);
    });
    testWidgets('payment errors offer a retry that subscribes again', (tester) async {
      when(() => payments.watchPaymentsByWorker('w1'))
          .thenAnswer((_) => Stream<List<Payment>>.error(Exception('offline')));
      await pump(tester);
      expect(find.text('Could not load payments. Please retry.'), findsOneWidget);
      data(completed: [_job()], receipts: [_payment('p1', 5000, _now)]);
      await tester.tap(find.byKey(const Key('error-retry-button')));
      await tester.pumpAndSettle();
      expect(find.text('Sink repair'), findsOneWidget);
      verify(() => payments.watchPaymentsByWorker('w1')).called(2);
    });
    testWidgets('job errors are not hidden by successful payment snapshots', (tester) async {
      when(() => jobs.watchCompletedJobsForWorker('w1'))
          .thenAnswer((_) => Stream<List<JobModel>>.error(Exception('offline')));
      await pump(tester);
      expect(find.text('Could not load completed jobs. Please retry.'), findsOneWidget);
      expect(find.byType(LoadingList), findsNothing);
    });
    testWidgets('a period with no rows has a useful empty state and action', (tester) async {
      data(receipts: [_payment('p1', 500, DateTime.utc(2026, 1, 1))]);
      await pump(tester);
      expect(find.text('No earnings in this period'), findsOneWidget);
      expect(find.byKey(const Key('earnings-empty-period-jobs')), findsOneWidget);
    });
    testWidgets('user-authored job titles are RTL-safe', (tester) async {
      data(completed: [_job(title: 'باورچی خانے کی مرمت')]);
      await pump(tester);
      expect(tester.widget<Text>(find.text('باورچی خانے کی مرمت')).textDirection, TextDirection.rtl);
    });
  });
}
