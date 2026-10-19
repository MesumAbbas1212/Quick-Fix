import 'helpers/visible.dart' as test_viewport;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quickfix/models/dispute_case.dart';
import 'package:quickfix/models/job_model.dart';
import 'package:quickfix/models/payment_model.dart';
import 'package:quickfix/services/dispute_service.dart';
import 'package:quickfix/services/job_service.dart';
import 'package:quickfix/services/payment_service.dart';
import 'package:quickfix/views/jobs/dispute_screen.dart';
class MockCases extends Mock implements DisputeService {}
class MockJobs extends Mock implements JobService {}
class MockPayments extends Mock implements PaymentService {}
class MockDB extends Mock implements FirebaseFirestore {}
JobModel completed() => JobModel(id: 'j', userId: 'u', workerId: 'w', title: 'Completed work', description: '', category: JobCategory.plumbing, address: '', location: const GeoPoint(33, 72), budgetMin: 1, budgetMax: 2, status: JobStatus.completed, preferredDate: DateTime(2026), createdAt: DateTime(2026), updatedAt: DateTime(2026));
void main() {
  test('paid receipt total ignores failed and nonfinite values', () {
    Payment payment(double amount, String status) => Payment(id: '', jobId: 'j', payerId: 'u', workerId: 'w', amount: amount, status: status, createdAt: DateTime(2026));
    expect(DisputeService.paidTotal([payment(100, 'paid'), payment(50, 'failed'), payment(double.nan, 'paid')]), 100);
  });
  test('dispute validation runs before any backend writes', () async {
    final db = MockDB(); await expectLater(DisputeService(firestore: db).submit(jobId: 'j', raisedBy: 'u', category: 'invalid', description: 'short', expectedResolution: 'Other', images: []), throwsArgumentError); verifyNever(() => db.collection(any()));
  });
  testWidgets('existing case is read-only with honest target/retention copy', (tester) async {
    final cases = MockCases(); final jobs = MockJobs(); final payments = MockPayments(); when(() => jobs.getJob('j')).thenAnswer((_) async => completed()); when(() => payments.getPaymentsForJob('j')).thenAnswer((_) async => []);
    when(() => cases.getForJob('j')).thenAnswer((_) async => const DisputeCase(id: 'j', jobId: 'j', raisedBy: 'u', againstId: 'w', category: 'Poor quality', description: 'Work details for manual review', expectedResolution: 'Redo the work', status: 'open'));
    await tester.pumpWidget(MaterialApp(home: DisputeScreen(jobId: 'j', userId: 'u', disputeService: cases, jobService: jobs, paymentService: payments))); await tester.pumpAndSettle();
    expect(find.text('Submitted for manual review'), findsOneWidget); expect(find.textContaining('not a guaranteed SLA'), findsOneWidget); expect(find.byKey(const Key('dispute-submit')), findsNothing);
  });
  testWidgets('submission form rejects missing category/details/resolution', (tester) async {
    final cases = MockCases(); final jobs = MockJobs(); final payments = MockPayments(); when(() => jobs.getJob('j')).thenAnswer((_) async => completed()); when(() => payments.getPaymentsForJob('j')).thenAnswer((_) async => []); when(() => cases.getForJob('j')).thenAnswer((_) async => null);
    await tester.pumpWidget(MaterialApp(home: DisputeScreen(jobId: 'j', userId: 'u', disputeService: cases, jobService: jobs, paymentService: payments))); await tester.pumpAndSettle();
    await test_viewport.reveal(tester, find.byKey(const Key('dispute-submit'))); await tester.tap(find.byKey(const Key('dispute-submit'))); await tester.pump(); expect(find.textContaining('at least 20 characters'), findsOneWidget);
  });
}
