import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quickfix/models/job_model.dart';
import 'package:quickfix/models/payment_model.dart';
import 'package:quickfix/models/worker_profile.dart';
import 'package:quickfix/services/job_service.dart';
import 'package:quickfix/services/payment_service.dart';
import 'package:quickfix/services/profile_service.dart';
import 'package:quickfix/views/payments/payment_screen.dart';

class MockJobService extends Mock implements JobService {}

class MockPaymentService extends Mock implements PaymentService {}

class MockProfileService extends Mock implements ProfileService {}

JobModel _job({JobStatus status = JobStatus.completed}) {
  return JobModel(
    id: 'j1',
    userId: 'me',
    workerId: 'w1',
    title: 'AC Repair',
    description: 'Split AC not cooling.',
    category: JobCategory.applianceRepair,
    address: 'Model Town, Lahore',
    location: const GeoPoint(31.5, 74.3),
    budgetMin: 2000,
    budgetMax: 3500,
    preferredDate: DateTime(2026, 10, 1),
    status: status,
    completedAt: status == JobStatus.completed
        ? DateTime(2026, 10, 15)
        : null,
    createdAt: DateTime(2026, 9, 20),
    updatedAt: DateTime(2026, 10, 15),
  );
}

void main() {
  late MockJobService jobService;
  late MockPaymentService paymentService;
  late MockProfileService profileService;

  final _worker = WorkerProfile(
    uid: 'w1',
    fullName: 'Ahmed Worker',
    email: 'worker@example.com',
    phone: '+92 300 1234567',
    professions: [JobCategory.applianceRepair],
    minBudget: 2000,
    maxBudget: 8000,
    rating: 4.8,
    completedJobs: 34,
    reviews: 34,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  final _paid = Payment(
    id: 'p1',
    jobId: 'j1',
    payerId: 'me',
    workerId: 'w1',
    amount: 3500,
    status: 'paid',
    createdAt: DateTime(2026, 10, 15),
  );

  Future<void> pumpPayment(
    WidgetTester tester, {
    JobStatus status = JobStatus.completed,
    Payment? existing,
  }) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: PaymentScreen(
          jobId: 'j1',
          myId: 'me',
          jobService: jobService,
          paymentService: paymentService,
          profileService: profileService,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  setUp(() {
    jobService = MockJobService();
    paymentService = MockPaymentService();
    profileService = MockProfileService();
  });

  void stubJob(JobStatus status) {
    when(() => jobService.watchJob('j1')).thenAnswer(
      (_) => Stream<JobModel?>.value(_job(status: status)),
    );
    when(() => profileService.watchWorkerProfile('w1')).thenAnswer(
      (_) => Stream<WorkerProfile?>.value(_worker),
    );
  }

  testWidgets('shows the payment form for an unpaid completed job',
      (tester) async {
    stubJob(JobStatus.completed);
    when(() => paymentService.getPaidPaymentForJob('j1'))
        .thenAnswer((_) async => null);

    await pumpPayment(tester);

    expect(find.text('Payment'), findsWidgets);
    expect(find.text('AC Repair'), findsOneWidget);
    expect(find.text('Ahmed Worker'), findsOneWidget);
    expect(find.text('Cash on completion'), findsWidgets);
    expect(find.textContaining('Confirm payment · PKR 3,500'), findsOneWidget);
    expect(find.byKey(const Key('method-cash')), findsOneWidget);
    expect(find.byKey(const Key('confirm-payment-button')), findsOneWidget);
  });

  testWidgets('confirming processes the payment and shows the receipt',
      (tester) async {
    stubJob(JobStatus.completed);
    when(() => paymentService.getPaidPaymentForJob('j1'))
        .thenAnswer((_) async => null);
    when(() => paymentService.simulatePayment(
          jobId: any(named: 'jobId'),
          payerId: any(named: 'payerId'),
          workerId: any(named: 'workerId'),
          amount: any(named: 'amount'),
        )).thenAnswer((_) async => _paid);

    await pumpPayment(tester);
    await tester.ensureVisible(find.byKey(const Key('confirm-payment-button')));
    await tester.tap(find.byKey(const Key('confirm-payment-button')));
    await tester.pumpAndSettle();

    verify(
      () => paymentService.simulatePayment(
        jobId: 'j1',
        payerId: 'me',
        workerId: 'w1',
        amount: 3500,
      ),
    ).called(1);

    expect(find.text('Payment complete'), findsOneWidget);
    expect(find.textContaining('MOCK-p1'), findsOneWidget);
    expect(find.byKey(const Key('confirm-payment-button')), findsNothing);
    expect(find.byKey(const Key('rate-worker-button')), findsOneWidget);
  });

  testWidgets('an already paid job goes straight to the receipt',
      (tester) async {
    stubJob(JobStatus.completed);
    when(() => paymentService.getPaidPaymentForJob('j1'))
        .thenAnswer((_) async => _paid);

    await pumpPayment(tester);

    expect(find.text('Payment complete'), findsOneWidget);
    expect(find.byKey(const Key('confirm-payment-button')), findsNothing);
    expect(find.byKey(const Key('rate-worker-button')), findsOneWidget);
  });

  testWidgets('an in-progress job explains that payment is not available',
      (tester) async {
    stubJob(JobStatus.inProgress);
    when(() => paymentService.getPaidPaymentForJob('j1'))
        .thenAnswer((_) async => null);

    await pumpPayment(tester);

    expect(find.textContaining('Payment becomes available'), findsOneWidget);
    expect(find.byKey(const Key('confirm-payment-button')), findsNothing);
  });
  testWidgets('removed job displays a recoverable empty state', (tester) async {
    when(() => jobService.watchJob('j1')).thenAnswer((_) => Stream<JobModel?>.value(null));
    when(() => paymentService.getPaidPaymentForJob('j1')).thenAnswer((_) async => null);
    await pumpPayment(tester);
    expect(find.text('Job unavailable'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    when(() => jobService.watchJob('j1')).thenAnswer((_) => Stream.value(_job()));
    when(() => profileService.watchWorkerProfile('w1')).thenAnswer((_) => Stream.value(_worker));
    await tester.tap(find.text('Reload job')); await tester.pumpAndSettle();
    expect(find.byKey(const Key('confirm-payment-button')), findsOneWidget);
    verify(() => jobService.watchJob('j1')).called(2);
  });

  testWidgets('payment read failure retries without resubscribing to the job', (tester) async {
    stubJob(JobStatus.completed);
    when(() => paymentService.getPaidPaymentForJob('j1')).thenThrow(StateError('offline'));
    await pumpPayment(tester);
    expect(find.text('Could not load payment status.'), findsOneWidget);
    when(() => paymentService.getPaidPaymentForJob('j1')).thenAnswer((_) async => null);
    await tester.tap(find.byKey(const Key('error-retry-button'))); await tester.pumpAndSettle();
    expect(find.byKey(const Key('confirm-payment-button')), findsOneWidget);
    verify(() => jobService.watchJob('j1')).called(1);
    verify(() => paymentService.getPaidPaymentForJob('j1')).called(2);
  });

  testWidgets('failed processing rechecks an existing receipt before allowing another payment', (tester) async {
    stubJob(JobStatus.completed);
    var reads = 0;
    when(() => paymentService.getPaidPaymentForJob('j1')).thenAnswer((_) async => ++reads == 1 ? null : _paid);
    when(() => paymentService.simulatePayment(jobId: 'j1', payerId: 'me', workerId: 'w1', amount: 3500))
        .thenThrow(StateError('job-status update failed after receipt'));
    await pumpPayment(tester);
    await tester.ensureVisible(find.byKey(const Key('confirm-payment-button')));
    await tester.tap(find.byKey(const Key('confirm-payment-button'))); await tester.pumpAndSettle();
    expect(find.text('Payment complete'), findsOneWidget);
    expect(find.byKey(const Key('confirm-payment-button')), findsNothing);
    verify(() => paymentService.getPaidPaymentForJob('j1')).called(2);
    verify(() => paymentService.simulatePayment(jobId: 'j1', payerId: 'me', workerId: 'w1', amount: 3500)).called(1);
  });

}
