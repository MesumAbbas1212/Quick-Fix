import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quickfix/models/job_request.dart';
import 'package:quickfix/services/job_request_service.dart';
import 'package:quickfix/services/job_service.dart';
import 'package:quickfix/views/jobs/withdraw_request_screen.dart';
class MockRequests extends Mock implements JobRequestService {}
class MockJobs extends Mock implements JobService {}
JobRequest request(JobRequestStatus status) => JobRequest(id: 'r', jobId: 'j', workerId: 'w', userId: 'c', status: status, message: 'درخواست', createdAt: DateTime(2026));
void main() {
  test('withdrawn is a real backward-compatible request enum value', () {
    expect(JobRequest.fromMap(request(JobRequestStatus.withdrawn).toMap(), 'r').status, JobRequestStatus.withdrawn); expect(request(JobRequestStatus.pending).copyWith(status: JobRequestStatus.withdrawn).status, JobRequestStatus.withdrawn);
  });
  testWidgets('already-accepted request is read-only and explains why', (tester) async {
    final requests = MockRequests(); final jobs = MockJobs(); when(() => requests.watchRequest('r')).thenAnswer((_) => Stream.value(request(JobRequestStatus.accepted))); when(() => jobs.getJob('j')).thenAnswer((_) async => null);
    await tester.pumpWidget(MaterialApp(home: WithdrawRequestScreen(requestId: 'r', workerId: 'w', requestService: requests, jobService: jobs))); await tester.pumpAndSettle();
    expect(find.textContaining('Already accepted'), findsOneWidget); expect(find.byKey(const Key('withdraw-request')), findsNothing);
  });
  testWidgets('withdrawal requires confirmation before the awaited service call', (tester) async {
    final requests = MockRequests(); final jobs = MockJobs(); when(() => requests.watchRequest('r')).thenAnswer((_) => Stream.value(request(JobRequestStatus.pending))); when(() => jobs.getJob('j')).thenAnswer((_) async => null);
    when(() => requests.withdrawRequest(requestId: 'r', workerId: 'w')).thenAnswer((_) async {});
    await tester.pumpWidget(MaterialApp(home: WithdrawRequestScreen(requestId: 'r', workerId: 'w', requestService: requests, jobService: jobs))); await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('withdraw-request'))); await tester.pumpAndSettle(); verifyNever(() => requests.withdrawRequest(requestId: 'r', workerId: 'w'));
    await tester.tap(find.byKey(const Key('withdraw-confirm'))); await tester.pumpAndSettle(); verify(() => requests.withdrawRequest(requestId: 'r', workerId: 'w')).called(1);
  });
}
