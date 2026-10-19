import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quickfix/core/widgets/loading_list.dart';
import 'package:quickfix/models/job_model.dart';
import 'package:quickfix/services/job_service.dart';
import 'package:quickfix/views/jobs/reschedule_job_screen.dart';
class MockJobs extends Mock implements JobService {}
JobModel job({JobStatus status = JobStatus.assigned}) => JobModel(id: 'j', userId: 'u', workerId: 'w', title: 'مرمت', description: '', category: JobCategory.plumbing,
  address: '', location: const GeoPoint(33, 72), budgetMin: 1, budgetMax: 2, preferredDate: DateTime.now().add(const Duration(days: 3)), status: status, createdAt: DateTime(2026), updatedAt: DateTime(2026));
void main() {
  late MockJobs jobs;
  setUpAll(() { registerFallbackValue(DateTime(2026)); });
  setUp(() { jobs = MockJobs(); when(() => jobs.watchJob('j')).thenAnswer((_) => Stream.value(job())); });
  Future<void> pump(WidgetTester tester, {bool cancel = false}) async {
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) => Scaffold(body: TextButton(onPressed: () => Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => RescheduleJobScreen(jobId: 'j', userId: 'u', initialCancel: cancel, jobService: jobs))), child: const Text('Open'))))));
    await tester.tap(find.text('Open')); await tester.pump(); await tester.pump(const Duration(milliseconds: 400));
  }
  test('schedule validation handles calendar-only and explicit-time boundaries', () {
    final now = DateTime(2026, 10, 19, 12);
    expect(JobService.validSchedule(DateTime(2026, 10, 18), null, now), isFalse);
    expect(JobService.validSchedule(DateTime(2026, 10, 19), null, now), isTrue);
    expect(JobService.validSchedule(DateTime(2026, 10, 19), DateTime(2000, 1, 1, 11), now), isFalse);
    expect(JobService.validSchedule(DateTime(2026, 10, 19), DateTime(2000, 1, 1, 13), now), isTrue);
  });
  test('cancellation metadata is optional and serializes without changing old jobs', () {
    expect(JobModel.fromMap(job().toMap(), 'j').cancelReason, isNull);
    final changed = job().copyWith(cancelReason: 'Plans changed', cancelledAt: DateTime(2026));
    expect(JobModel.fromMap(changed.toMap(), 'j').cancelledAt, DateTime(2026)); expect(changed.cancelReason, 'Plans changed');
  });
  testWidgets('loading/error retry and read-only terminal state', (tester) async {
    final stream = StreamController<JobModel?>(); addTearDown(stream.close); when(() => jobs.watchJob('j')).thenAnswer((_) => stream.stream);
    await pump(tester); expect(find.byType(LoadingList), findsOneWidget); stream.addError(StateError('offline')); await tester.pump();
    when(() => jobs.watchJob('j')).thenAnswer((_) => Stream.value(job(status: JobStatus.completed))); await tester.tap(find.text('Retry')); await tester.pumpAndSettle();
    expect(find.text('Changes are unavailable'), findsOneWidget); expect(find.byKey(const Key('job-change-submit')), findsNothing);
  });
  testWidgets('cancel needs a reason and a confirmation before the service', (tester) async {
    when(() => jobs.changeSchedule(jobId: 'j', ownerId: 'u', cancel: true, date: any(named: 'date'), time: any(named: 'time'), reason: 'Plans changed')).thenAnswer((_) async {});
    await pump(tester, cancel: true); await tester.ensureVisible(find.byKey(const Key('job-change-submit'))); await tester.tap(find.byKey(const Key('job-change-submit'))); await tester.pump();
    expect(find.textContaining('Choose a reason'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('cancel-reason-Plans changed'))); await tester.tap(find.byKey(const Key('cancel-reason-Plans changed'))); await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('job-change-submit'))); await tester.tap(find.byKey(const Key('job-change-submit'))); await tester.pumpAndSettle();
    verifyNever(() => jobs.changeSchedule(jobId: 'j', ownerId: 'u', cancel: true, date: any(named: 'date'), time: any(named: 'time'), reason: 'Plans changed'));
    await tester.tap(find.byKey(const Key('job-change-confirm'))); await tester.pumpAndSettle();
    verify(() => jobs.changeSchedule(jobId: 'j', ownerId: 'u', cancel: true, date: any(named: 'date'), time: any(named: 'time'), reason: 'Plans changed')).called(1);
    expect(find.byType(RescheduleJobScreen), findsNothing);
  });
}
