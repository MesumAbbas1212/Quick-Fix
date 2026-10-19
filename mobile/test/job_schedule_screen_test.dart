import 'helpers/visible.dart' as test_viewport;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quickfix/models/job_model.dart';
import 'package:quickfix/services/job_schedule_service.dart';
import 'package:quickfix/services/job_service.dart';
import 'package:quickfix/views/worker/job_schedule_screen.dart';
class MockJobs extends Mock implements JobService {}
JobModel booking({String worker = 'w', JobStatus status = JobStatus.assigned}) => JobModel(id: 'j', userId: 'c', workerId: worker, title: 'Booked work', description: '', category: JobCategory.plumbing,
  address: '', location: const GeoPoint(33, 72), budgetMin: 1, budgetMax: 2, status: status, preferredDate: DateTime(2026, 10, 19), createdAt: DateTime(2026), updatedAt: DateTime(2026));
void main() {
  test('month grid is Monday-first and handles leap years without fake bookings', () {
    final cells = const JobScheduleService().monthCells(DateTime(2024, 2)); expect(cells.whereType<DateTime>(), hasLength(29)); expect(cells.take(3).every((date) => date == null), isTrue); expect(cells.length % 7, 0);
  });
  test('only this worker’s active jobs contribute dots and day lists', () {
    const service = JobScheduleService(); final jobs = [booking(), booking(worker: 'other'), booking(status: JobStatus.completed), booking(status: JobStatus.cancelled)];
    expect(service.onDay(jobs, 'w', DateTime(2026, 10, 19)), hasLength(1)); expect(service.inMonth(jobs, 'w', DateTime(2026, 11)), 0);
  });
  testWidgets('empty month remains navigable and retry renews the source', (tester) async {
    final jobs = MockJobs(); when(() => jobs.watchScheduledJobs('w')).thenAnswer((_) => Stream.error(StateError('offline')));
    await tester.pumpWidget(MaterialApp(home: JobScheduleScreen(workerId: 'w', jobService: jobs, initialDate: DateTime(2026, 10, 19)))); await tester.pumpAndSettle();
    when(() => jobs.watchScheduledJobs('w')).thenAnswer((_) => Stream.value([])); await tester.tap(find.text('Retry')); await tester.pumpAndSettle(); expect(find.text('October 2026'), findsOneWidget);
    await tester.tap(find.byKey(const Key('schedule-next'))); await tester.pumpAndSettle(); expect(find.text('November 2026'), findsOneWidget); await test_viewport.reveal(tester, find.text('No bookings this month')); expect(find.text('No bookings this month'), findsOneWidget);
  });
}
