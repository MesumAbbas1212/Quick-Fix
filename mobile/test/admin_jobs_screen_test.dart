import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quickfix/models/admin_job_row.dart';
import 'package:quickfix/models/user_model.dart';
import 'package:quickfix/services/admin_service.dart';
import 'package:quickfix/views/admin/admin_account_detail_screen.dart';
import 'package:quickfix/views/admin/admin_jobs_screen.dart';
import 'package:quickfix/views/admin/admin_widgets.dart';

class _Admin extends Mock implements AdminService {}

final _user = UserModel(
  uid: 'admin',
  email: 'admin@example.com',
  fullName: 'Admin',
  phone: '',
  role: UserRole.admin,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

AdminJobRow _job({String id = 'j1', String status = 'open'}) => AdminJobRow(
  id: id,
  title: 'Repair kitchen sink',
  category: 'plumbing',
  status: status,
  budgetMin: 25000,
  budgetMax: 50000,
  address: 'F-7, Islamabad',
  clientName: 'Client One',
  workerName: status == 'open' ? null : 'Worker One',
  createdAt: DateTime.now().subtract(const Duration(hours: 2)),
  clientId: 'client-1',
  workerId: status == 'open' ? null : 'worker-1',
  preferredDate: DateTime(2026, 11, 2),
  preferredTime: DateTime(2026, 11, 2, 14),
);

void _stubJobs(_Admin service, Stream<List<AdminJobRow>> jobs) {
  when(() => service.watchJobs(status: any(named: 'status'), limit: any(named: 'limit')))
      .thenAnswer((_) => jobs);
}

void main() {
  testWidgets('jobs loading state shows admin skeletons', (tester) async {
    final service = _Admin();
    _stubJobs(service, Stream<List<AdminJobRow>>.multi((_) {}));
    await tester.pumpWidget(MaterialApp(
      home: AdminJobsScreen(user: _user, adminService: service),
    ));
    expect(find.byType(AdminLoading), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('jobs empty state is explicit', (tester) async {
    final service = _Admin();
    _stubJobs(service, Stream.value(const <AdminJobRow>[]));
    await tester.pumpWidget(MaterialApp(
      home: AdminJobsScreen(user: _user, adminService: service),
    ));
    await tester.pumpAndSettle();
    expect(find.text('No jobs found'), findsOneWidget);
    expect(find.byKey(const Key('admin-jobs-filter-all')), findsOneWidget);
  });

  testWidgets('jobs error has retry', (tester) async {
    final service = _Admin();
    when(() => service.watchJobs(status: any(named: 'status'), limit: any(named: 'limit')))
        .thenAnswer((_) => Stream.error(StateError('offline')));
    await tester.pumpWidget(MaterialApp(
      home: AdminJobsScreen(user: _user, adminService: service),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Something went wrong'), findsOneWidget);
    await tester.tap(find.byKey(const Key('error-retry-button')));
    await tester.pump();
    verify(() => service.watchJobs(limit: 50)).called(2);
  });

  testWidgets('populated jobs show card fields and status counts', (tester) async {
    final service = _Admin();
    _stubJobs(service, Stream.value([_job(), _job(id: 'j2', status: 'completed')]));
    await tester.pumpWidget(MaterialApp(
      home: AdminJobsScreen(user: _user, adminService: service),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Repair kitchen sink'), findsNWidgets(2));
    expect(find.text('PKR 25,000 – 50,000'), findsOneWidget);
    expect(find.text('Client One → Unassigned'), findsOneWidget);
    expect(find.text('All (2)'), findsOneWidget);
    expect(find.byKey(const Key('admin-job-card-j1')), findsOneWidget);
  });

  testWidgets('status chips switch the loaded job list', (tester) async {
    final service = _Admin();
    _stubJobs(service, Stream.value([
      _job(),
      _job(id: 'j2', status: 'assigned'),
      _job(id: 'j3', status: 'inProgress'),
      _job(id: 'j4', status: 'completed'),
      _job(id: 'j5', status: 'cancelled'),
    ]));
    await tester.pumpWidget(MaterialApp(
      home: AdminJobsScreen(user: _user, adminService: service),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('admin-job-card-j1')), findsOneWidget);
    await tester.tap(find.byKey(const Key('admin-jobs-filter-completed')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('admin-job-card-j4')), findsOneWidget);
    expect(find.byKey(const Key('admin-job-card-j1')), findsNothing);
  });

  testWidgets('job details show schedule, address and linked worker drill-through', (tester) async {
    final service = _Admin();
    _stubJobs(service, Stream.value([_job(status: 'assigned')]));
    when(() => service.accountDetail('worker-1', worker: true))
        .thenAnswer((_) async => null);
    await tester.pumpWidget(MaterialApp(
      home: AdminJobsScreen(user: _user, adminService: service),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('admin-job-card-j1')));
    await tester.pumpAndSettle();
    expect(find.text('F-7, Islamabad'), findsOneWidget);
    expect(find.textContaining('2 Nov 2026'), findsOneWidget);
    expect(find.text('Worker One'), findsOneWidget);
    await tester.tap(find.text('Worker One'));
    await tester.pumpAndSettle();
    expect(find.byType(AdminAccountDetailScreen), findsOneWidget);
    expect(find.text('Account not found'), findsOneWidget);
  });

  testWidgets('search filters jobs by title and client name', (tester) async {
    final service = _Admin();
    _stubJobs(service, Stream.value([
      _job(),
      AdminJobRow(
        id: 'j2',
        title: 'Paint bedroom',
        category: 'painting',
        status: 'open',
        budgetMin: 1000,
        budgetMax: 2000,
        address: 'G-10, Islamabad',
        clientName: 'Ayesha Khan',
        workerName: null,
        createdAt: DateTime.now(),
      ),
    ]));
    await tester.pumpWidget(MaterialApp(
      home: AdminJobsScreen(user: _user, adminService: service),
    ));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('admin-jobs-search')), 'ayesha');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('admin-job-card-j2')), findsOneWidget);
    expect(find.byKey(const Key('admin-job-card-j1')), findsNothing);
  });

  testWidgets('cancellation requires a reason and dismissing confirmation writes nothing', (tester) async {
    final service = _Admin();
    _stubJobs(service, Stream.value([_job()]));
    when(() => service.cancelJob(any(), any())).thenAnswer((_) async {});
    await tester.pumpWidget(MaterialApp(
      home: AdminJobsScreen(user: _user, adminService: service),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('admin-job-card-j1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('admin-cancel-job')));
    await tester.pumpAndSettle();
    expect(tester.widget<ElevatedButton>(find.byKey(
      const Key('admin-cancel-job-reason-submit'),
    )).onPressed, isNull);
    expect(find.byKey(const Key('admin-cancel-job-confirm')), findsNothing);

    await tester.enterText(find.byKey(const Key('admin-cancel-job-reason')), 'Duplicate request');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('admin-cancel-job-reason-submit')));
    await tester.pumpAndSettle();
    expect(find.text('Cancel “Repair kitchen sink”?'), findsOneWidget);
    await tester.tap(find.text('Keep job'));
    await tester.pumpAndSettle();
    verifyNever(() => service.cancelJob(any(), any()));
  });

  testWidgets('confirming cancellation calls exact service; final jobs hide cancel', (tester) async {
    final service = _Admin();
    _stubJobs(service, Stream.value([
      _job(),
      _job(id: 'j2', status: 'completed'),
      _job(id: 'j3', status: 'cancelled'),
    ]));
    when(() => service.cancelJob('j1', 'Worker unavailable')).thenAnswer((_) async {});
    await tester.pumpWidget(MaterialApp(
      home: AdminJobsScreen(user: _user, adminService: service),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('admin-job-card-j1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('admin-cancel-job')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('admin-cancel-job-reason')), 'Worker unavailable');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('admin-cancel-job-reason-submit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('admin-cancel-job-confirm')));
    await tester.pumpAndSettle();
    verify(() => service.cancelJob('j1', 'Worker unavailable')).called(1);

    await tester.tap(find.byKey(const Key('admin-job-card-j2')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('admin-cancel-job')), findsNothing);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('admin-jobs-filter-cancelled')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('admin-job-card-j3')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('admin-cancel-job')), findsNothing);
  });
}
