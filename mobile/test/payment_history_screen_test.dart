import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quickfix/models/job_model.dart';
import 'package:quickfix/models/payment_model.dart';
import 'package:quickfix/models/user_model.dart';
import 'package:quickfix/models/worker_profile.dart';
import 'package:quickfix/services/auth_service.dart';
import 'package:quickfix/services/job_service.dart';
import 'package:quickfix/services/payment_service.dart';
import 'package:quickfix/services/profile_service.dart';
import 'package:quickfix/views/jobs/post_job_screen.dart';
import 'package:quickfix/views/payments/payment_history_screen.dart';

class MockPaymentService extends Mock implements PaymentService {}

class MockJobService extends Mock implements JobService {}

class MockProfileService extends Mock implements ProfileService {}

class MockAuthService extends Mock implements AuthService {}

final _client = UserModel(
  uid: 'c1',
  email: 'client@example.com',
  fullName: 'Client One',
  phone: '+92 300 7654321',
  role: UserRole.user,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

final _worker = UserModel(
  uid: 'w1',
  email: 'worker@example.com',
  fullName: 'Ahmed Worker',
  phone: '+92 300 1234567',
  role: UserRole.worker,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

Payment _payment({
  required String id,
  required DateTime createdAt,
  double amount = 5000,
}) {
  return Payment(
    id: id,
    jobId: 'job-$id',
    payerId: 'c1',
    workerId: 'w1',
    amount: amount,
    status: 'paid',
    createdAt: createdAt,
  );
}

void main() {
  late MockPaymentService paymentService;
  late MockJobService jobService;
  late MockProfileService profileService;
  late MockAuthService authService;

  setUp(() {
    paymentService = MockPaymentService();
    jobService = MockJobService();
    profileService = MockProfileService();
    authService = MockAuthService();
  });

  Future<void> pumpHistory(
    WidgetTester tester, {
    required UserModel user,
    List<Payment> payments = const [],
    Object? error,
  }) async {
    final stream = error != null
        ? Stream<List<Payment>>.error(error)
        : Stream<List<Payment>>.value(payments);
    if (user.role == UserRole.worker) {
      when(() => paymentService.watchPaymentsByWorker('w1'))
          .thenAnswer((_) => stream);
    } else {
      when(() => paymentService.watchPaymentsByPayer('c1'))
          .thenAnswer((_) => stream);
    }
    when(() => jobService.getJob(any())).thenAnswer((inv) async {
      final jobId = inv.positionalArguments.first as String;
      return JobModel(
        id: jobId,
        userId: 'c1',
        workerId: 'w1',
        title: 'Job $jobId',
        description: 'desc',
        category: JobCategory.other,
        address: 'addr',
        location: const GeoPoint(0, 0),
        budgetMin: 1000,
        budgetMax: 5000,
        preferredDate: DateTime(2026, 10, 1),
        status: JobStatus.completed,
        createdAt: DateTime(2026, 9, 20),
        updatedAt: DateTime(2026, 9, 20),
      );
    });
    when(() => profileService.getWorkerProfile('w1')).thenAnswer(
      (_) async => WorkerProfile(
        uid: 'w1',
        fullName: 'Ahmed Worker',
        email: 'worker@example.com',
        phone: '+92 300 1234567',
        professions: [JobCategory.other],
        minBudget: 1000,
        maxBudget: 5000,
        rating: 4.8,
        completedJobs: 34,
        reviews: 34,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      ),
    );
    when(() => authService.getUserProfile('c1')).thenAnswer(
      (_) async => _client,
    );

    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: PaymentHistoryScreen(
          user: user,
          paymentService: paymentService,
          jobService: jobService,
          profileService: profileService,
          authService: authService,
        ),
      ),
    );
    // Stream emission, then the enrichment FutureBuilder (both complete,
    // so pumpAndSettle cannot hang on an infinite spinner).
    await tester.pump();
    await tester.pumpAndSettle();
  }

  testWidgets('client with no payments sees the empty state and CTA',
      (tester) async {
    await pumpHistory(tester, user: _client);

    expect(find.text('No payments yet'), findsOneWidget);
    expect(find.byKey(const Key('post-job-cta')), findsOneWidget);

    await tester.tap(find.byKey(const Key('post-job-cta')));
    await tester.pumpAndSettle();
    expect(find.byType(PostJobScreen), findsOneWidget);
  });

  testWidgets('worker with no payments sees the earnings empty state',
      (tester) async {
    await pumpHistory(tester, user: _worker);

    expect(find.text('No earnings yet'), findsOneWidget);
    expect(find.byKey(const Key('post-job-cta')), findsNothing);
    expect(find.text('Earnings'), findsOneWidget);
  });

  testWidgets('groups payments by month with a summary card', (tester) async {
    final payments = [
      _payment(id: 'p1', createdAt: DateTime(2026, 10, 18), amount: 2000),
      _payment(id: 'p2', createdAt: DateTime(2026, 10, 5), amount: 3000),
      _payment(id: 'p3', createdAt: DateTime(2026, 9, 20), amount: 4000),
    ];
    await pumpHistory(tester, user: _client, payments: payments);

    // Month headers, newest month first.
    expect(find.text('October 2026'), findsOneWidget);
    expect(find.text('September 2026'), findsOneWidget);

    // Job titles + worker name from the enrich step.
    expect(find.text('Job job-p1'), findsOneWidget);
    expect(find.text('Job job-p2'), findsOneWidget);
    expect(find.text('Job job-p3'), findsOneWidget);
    expect(find.textContaining('Ahmed Worker'), findsWidgets);

    // Summary card: labels are always present; the lifetime total is
    // clock-independent (2000 + 3000 + 4000). The "this month" figure
    // depends on DateTime.now(), so only its label is asserted.
    expect(find.text('This month'), findsOneWidget);
    expect(find.text('Total paid'), findsOneWidget);
    expect(find.text('PKR 9,000'), findsOneWidget);
  });

  testWidgets('worker view shows client names and earned totals',
      (tester) async {
    final payments = [
      _payment(id: 'p1', createdAt: DateTime(2026, 10, 18), amount: 7000),
    ];
    await pumpHistory(tester, user: _worker, payments: payments);

    expect(find.text('Earnings'), findsOneWidget);
    expect(find.text('Job job-p1'), findsOneWidget);
    expect(find.textContaining('Client One'), findsOneWidget);
    expect(find.text('Total earned'), findsOneWidget);
    expect(find.text('PKR 7,000'), findsWidgets);
  });

  testWidgets('stream errors render the error state', (tester) async {
    await pumpHistory(tester, user: _client, error: Exception('boom'));
    await tester.pump();

    expect(find.textContaining('Could not load payments'), findsOneWidget);
  });
}
