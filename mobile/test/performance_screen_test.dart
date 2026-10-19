import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quickfix/models/performance_report.dart';
import 'package:quickfix/services/performance_service.dart';
import 'package:quickfix/views/worker/performance_screen.dart';
class MockPerformance extends Mock implements PerformanceService {}
void main() {
  test('rates use decided/eligible denominators and exclude withdrawn applications', () {
    final jobs = [for (var i = 0; i < 3; i++) {'id': 'j$i', 'workerId': 'w', 'status': 'completed'}, {'workerId': 'w', 'status': 'cancelled'}];
    final requests = [for (final status in ['accepted', 'declined', 'pending', 'withdrawn']) {'workerId': 'w', 'status': status}];
    final report = PerformanceService.compute('w', jobs, requests, []);
    expect(report.unlocked, isTrue); expect(report.replyRate, closeTo(2 / 3, .00001)); expect(report.acceptanceRate, .5); expect(report.completionRate, .75); expect(report.scheduleProxy, isNull);
  });
  test('date-only deadline includes the scheduled day and skips unknown dates', () {
    final report = PerformanceService.compute('w', [
      {'workerId': 'w', 'status': 'completed', 'preferredDate': DateTime(2026, 10, 1), 'completedAt': DateTime(2026, 10, 1, 23)},
      {'workerId': 'w', 'status': 'completed', 'preferredDate': DateTime(2026, 10, 1), 'completedAt': DateTime(2026, 10, 2)},
      {'workerId': 'w', 'status': 'completed'}], [], []);
    expect(report.scheduleProxy, .5); expect(report.averageRating, isNull); expect(report.replyRate, isNull);
  });
  test('received review overrides legacy job score without duplicate counting', () {
    final report = PerformanceService.compute('w', [{'id': 'j', 'workerId': 'w', 'status': 'completed', 'rating': 1}], [], [{'workerId': 'w', 'jobId': 'j', 'rating': 5}]);
    expect(report.averageRating, 5); expect(report.unlocked, isFalse);
  });
  testWidgets('error retry and insufficient-data action do not show fake 0 percent metrics', (tester) async {
    final service = MockPerformance(); when(() => service.watch('w')).thenAnswer((_) => Stream.error(StateError('offline')));
    await tester.pumpWidget(MaterialApp(home: PerformanceScreen(workerId: 'w', performanceService: service))); await tester.pumpAndSettle();
    when(() => service.watch('w')).thenAnswer((_) => Stream.value(const PerformanceReport(completedJobs: 0, suggestion: 'More data')));
    await tester.tap(find.text('Retry')); await tester.pumpAndSettle(); expect(find.text('Complete 3 jobs to unlock insights'), findsOneWidget); expect(find.text('0%'), findsNothing); expect(find.text('View my jobs'), findsOneWidget);
  });
  testWidgets('enlarged metrics stay scrollable on a narrow screen', (tester) async {
    final service = MockPerformance(); when(() => service.watch('w')).thenAnswer((_) => Stream.value(const PerformanceReport(completedJobs: 3, replyRate: .5, completionRate: 1, suggestion: 'Keep schedules current')));
    tester.view.physicalSize = const Size(320, 700); tester.view.devicePixelRatio = 1; addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)), child: child!), home: PerformanceScreen(workerId: 'w', performanceService: service)));
    await tester.pumpAndSettle(); expect(tester.takeException(), isNull); expect(find.text('Clients replied'), findsOneWidget);
  });
}
