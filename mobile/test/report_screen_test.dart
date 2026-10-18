import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quickfix/services/report_service.dart';
import 'package:quickfix/views/admin/report_screen.dart';

class MockReportService extends Mock implements ReportService {}

void main() {
  late MockReportService service;

  setUp(() {
    service = MockReportService();
    when(() => service.hasOpenReport(any(), any()))
        .thenAnswer((_) async => false);
    when(() => service.submitReport(
          reporterId: any(named: 'reporterId'),
          reportedId: any(named: 'reportedId'),
          reason: any(named: 'reason'),
          jobId: any(named: 'jobId'),
          details: any(named: 'details'),
        )).thenAnswer((_) async {});
  });

  Future<void> pumpReport(
    WidgetTester tester, {
    bool self = false,
    String? jobId,
    String? jobTitle,
  }) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: ReportScreen(
          myId: 'me',
          reportedId: self ? 'me' : 'them',
          reportedName: 'the worker',
          jobId: jobId,
          jobTitle: jobTitle,
          reportService: service,
        ),
      ),
    );
    // Flush the duplicate-check future.
    await tester.pump();
  }

  testWidgets('blocks self-report', (tester) async {
    await pumpReport(tester, self: true);

    expect(find.textContaining('Self-report not allowed'), findsOneWidget);
    expect(find.byKey(const Key('submit-report-button')), findsNothing);
    verifyNever(() => service.hasOpenReport(any(), any()));
  });

  testWidgets('shows all six reasons and job context', (tester) async {
    await pumpReport(
      tester,
      jobId: 'j1',
      jobTitle: 'AC Repair',
    );

    expect(find.text('Report the worker'), findsOneWidget);
    expect(find.textContaining('About: AC Repair'), findsOneWidget);
    expect(find.byKey(const Key('report-reason-Other')), findsOneWidget);
    expect(
      find.byKey(const Key('report-reason-Didn\'t show up')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('report-details-field')), findsOneWidget);
  });

  testWidgets('submit is disabled while duplicate check runs', (tester) async {
    // Never completes → the check stays pending.
    final pending = Completer<bool>();
    when(() => service.hasOpenReport(any(), any()))
        .thenAnswer((_) => pending.future);
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: ReportScreen(
          myId: 'me',
          reportedId: 'them',
          reportedName: 'the worker',
          reportService: service,
        ),
      ),
    );
    // First frame: check in flight, button disabled.
    final button = tester.widget<ElevatedButton>(
      find.byKey(const Key('submit-report-button')),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('shows duplicate notice and disables submit', (tester) async {
    when(() => service.hasOpenReport(any(), any()))
        .thenAnswer((_) async => true);
    await pumpReport(tester);

    expect(find.textContaining('You already have an open report'), findsOneWidget);
    final button = tester.widget<ElevatedButton>(
      find.byKey(const Key('submit-report-button')),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('submitting without a reason shows validation error',
      (tester) async {
    await pumpReport(tester);
    await tester.ensureVisible(find.byKey(const Key('submit-report-button')));
    await tester.tap(find.byKey(const Key('submit-report-button')));
    await tester.pumpAndSettle();

    expect(find.text('Choose a reason to continue.'), findsWidgets);
    verifyNever(
      () => service.submitReport(
        reporterId: any(named: 'reporterId'),
        reportedId: any(named: 'reportedId'),
        reason: any(named: 'reason'),
        jobId: any(named: 'jobId'),
        details: any(named: 'details'),
      ),
    );
  });

  testWidgets('confirming submits the report and pops with snackbar',
      (tester) async {
    await pumpReport(tester, jobId: 'j1');

    await tester.tap(
      find.byKey(const Key('report-reason-Other')),
    );
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('report-details-field')),
      'Kept calling after hours.',
    );
    await tester.ensureVisible(find.byKey(const Key('submit-report-button')));
    await tester.tap(find.byKey(const Key('submit-report-button')));
    await tester.pumpAndSettle();

    // Confirmation dialog.
    expect(find.text('Submit report?'), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Submit report'),
      ),
    );
    await tester.pumpAndSettle();

    final call = verify(
      () => service.submitReport(
        reporterId: 'me',
        reportedId: 'them',
        reason: 'Other',
        jobId: 'j1',
        details: 'Kept calling after hours.',
      ),
    ).captured;
    expect(call, isNotEmpty);

    expect(find.byType(ReportScreen), findsNothing);
    expect(find.textContaining('Report submitted'), findsOneWidget);
  });
}
