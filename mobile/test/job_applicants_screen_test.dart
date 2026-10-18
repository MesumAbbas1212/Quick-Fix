import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quickfix/core/widgets/loading_list.dart';
import 'package:quickfix/models/job_model.dart';
import 'package:quickfix/models/job_request.dart';
import 'package:quickfix/models/worker_profile.dart';
import 'package:quickfix/services/job_request_service.dart';
import 'package:quickfix/services/job_service.dart';
import 'package:quickfix/services/profile_service.dart';
import 'package:quickfix/views/jobs/job_applicants_screen.dart';

class MockJobRequestService extends Mock implements JobRequestService {}
class MockJobService extends Mock implements JobService {}
class MockProfileService extends Mock implements ProfileService {}

final _at = DateTime(2026, 10, 1);

JobModel _job({JobStatus status = JobStatus.open, String? workerId, String owner = 'me'}) =>
    JobModel(
      id: 'j1', userId: owner, workerId: workerId,
      title: 'Sink Leak', description: 'Kitchen sink leaking.',
      category: JobCategory.plumbing, address: 'Attock',
      location: const GeoPoint(33.77, 72.37),
      budgetMin: 3000, budgetMax: 5000, preferredDate: _at,
      status: status, createdAt: _at, updatedAt: _at,
    );

WorkerProfile _worker(String uid, {
  double rating = 4, GeoPoint? location, String? name,
}) => WorkerProfile(
      uid: uid, fullName: name ?? 'Worker $uid', email: '$uid@example.com',
      professions: [JobCategory.plumbing], rating: rating, completedJobs: 20,
      location: location, createdAt: _at, updatedAt: _at,
    );

JobRequest _request(String id, String workerId, {
  JobRequestStatus status = JobRequestStatus.pending,
  String? message, String jobId = 'j1',
}) => JobRequest(
      id: id, jobId: jobId, workerId: workerId, userId: 'me',
      status: status, message: message, createdAt: _at,
    );

void main() {
  group('JobApplicantsScreen', () {
    late MockJobRequestService requests;
    late MockJobService jobs;
    late MockProfileService profiles;

    void stubRequests(List<JobRequest> data) =>
        when(() => requests.watchUserRequests('me'))
            .thenAnswer((_) => Stream<List<JobRequest>>.value(data));

    void stubWorker(String uid, {
      double rating = 4, GeoPoint? location, String? name,
    }) {
      when(() => profiles.getWorkerProfile(uid))
          .thenAnswer((_) async => _worker(uid, rating: rating, location: location, name: name));
      when(() => jobs.watchCompletedJobsForWorker(uid))
          .thenAnswer((_) => Stream<List<JobModel>>.value([]));
    }

    Future<void> pumpApplicants(WidgetTester tester) async {
      tester.view.physicalSize = const Size(400, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: JobApplicantsScreen(
          jobId: 'j1', myId: 'me', jobRequestService: requests,
          jobService: jobs, profileService: profiles,
        ),
      ));
      await tester.pump();
      await tester.pump();
    }

    setUp(() {
      requests = MockJobRequestService();
      jobs = MockJobService();
      profiles = MockProfileService();
      when(() => jobs.watchJob('j1'))
          .thenAnswer((_) => Stream<JobModel?>.value(_job()));
      stubRequests([]);
      when(() => requests.respondToRequest(
        requestId: any(named: 'requestId'), status: JobRequestStatus.declined,
      )).thenAnswer((_) async {});
      when(() => requests.acceptApplicant(
        jobId: 'j1', requestId: any(named: 'requestId'),
        ownerId: 'me', jobService: jobs,
      )).thenAnswer((_) async {});
    });

    testWidgets('shows skeletons until requests arrive', (tester) async {
      final controller = StreamController<List<JobRequest>>();
      addTearDown(controller.close);
      when(() => requests.watchUserRequests('me')).thenAnswer((_) => controller.stream);
      await pumpApplicants(tester);
      expect(find.byType(LoadingList), findsOneWidget);
      expect(find.text('Sink Leak'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('shows job summary, an empty state and a working refresh CTA', (tester) async {
      await pumpApplicants(tester);
      expect(find.text('Applicants'), findsOneWidget);
      expect(find.text('Sink Leak'), findsOneWidget);
      expect(find.text('PKR 3,000–5,000'), findsOneWidget);
      expect(find.text('No applicants yet'), findsOneWidget);
      expect(find.textContaining('budget'), findsOneWidget);
      await tester.tap(find.byKey(const Key('empty-applicants-refresh')));
      await tester.pumpAndSettle();
      verify(() => requests.watchUserRequests('me')).called(2);
      verify(() => jobs.watchJob('j1')).called(2);
    });

    testWidgets('request errors retry by re-subscribing', (tester) async {
      when(() => requests.watchUserRequests('me'))
          .thenAnswer((_) => Stream<List<JobRequest>>.error(Exception('offline')));
      await pumpApplicants(tester);
      expect(find.text('Could not load applicants. Check your connection.'), findsOneWidget);
      stubRequests([_request('r1', 'w1')]);
      stubWorker('w1');
      await tester.tap(find.byKey(const Key('error-retry-button')));
      await tester.pumpAndSettle();
      expect(find.text('Worker w1'), findsOneWidget);
      verify(() => requests.watchUserRequests('me')).called(2);
    });

    testWidgets('job errors do not leave a spinner or expose action buttons', (tester) async {
      when(() => jobs.watchJob('j1'))
          .thenAnswer((_) => Stream<JobModel?>.error(Exception('offline')));
      await pumpApplicants(tester);
      expect(find.text('Could not load this job. Check your connection.'), findsOneWidget);
      expect(find.byType(LoadingList), findsNothing);
      when(() => jobs.watchJob('j1'))
          .thenAnswer((_) => Stream<JobModel?>.value(_job()));
      await tester.tap(find.byKey(const Key('error-retry-button')));
      await tester.pumpAndSettle();
      expect(find.text('No applicants yet'), findsOneWidget);
    });

    testWidgets('worker-profile fetch errors can be retried', (tester) async {
      stubRequests([_request('r1', 'w1')]);
      when(() => profiles.getWorkerProfile('w1')).thenThrow(Exception('offline'));
      await pumpApplicants(tester);
      expect(find.text('Could not load worker profiles. Please retry.'), findsOneWidget);
      stubWorker('w1');
      await tester.tap(find.byKey(const Key('error-retry-button')));
      await tester.pumpAndSettle();
      expect(find.text('Worker w1'), findsOneWidget);
      verify(() => profiles.getWorkerProfile('w1')).called(2);
    });

    testWidgets('lists applicants by rating descending with their message', (tester) async {
      stubRequests([
        _request('r1', 'low', message: 'Hi, I can fix it.'),
        _request('r2', 'high'),
      ]);
      stubWorker('low', rating: 3);
      stubWorker('high', rating: 4.9);
      await pumpApplicants(tester);
      expect(find.text('Worker high'), findsOneWidget);
      expect(find.text('Worker low'), findsOneWidget);
      expect(tester.getTopLeft(find.text('Worker high')).dy,
          lessThan(tester.getTopLeft(find.text('Worker low')).dy));
      expect(find.text('Hi, I can fix it.'), findsOneWidget);
      expect(find.byKey(const Key('applicant-accept-r2')), findsOneWidget);
      expect(find.byKey(const Key('applicant-decline-r2')), findsOneWidget);
      expect(find.text('20 jobs done'), findsNWidgets(2));
      expect(find.text('Apprentice'), findsNWidgets(2));
    });

    testWidgets('equal ratings are sorted by distance to the job', (tester) async {
      stubRequests([_request('rFar', 'far'), _request('rNear', 'near')]);
      stubWorker('far', location: const GeoPoint(31.5, 74.3));
      stubWorker('near', location: const GeoPoint(33.77, 72.37));
      await pumpApplicants(tester);
      expect(tester.getTopLeft(find.text('Worker near')).dy,
          lessThan(tester.getTopLeft(find.text('Worker far')).dy));
      expect(find.text('0.0 km from job'), findsOneWidget);
    });

    testWidgets('unknown distance comes last for equal ratings', (tester) async {
      stubRequests([_request('r1', 'unknown'), _request('r2', 'known')]);
      stubWorker('unknown');
      stubWorker('known', location: const GeoPoint(33.8, 72.4));
      await pumpApplicants(tester);
      expect(tester.getTopLeft(find.text('Worker known')).dy,
          lessThan(tester.getTopLeft(find.text('Worker unknown')).dy));
      expect(find.text('Distance unavailable'), findsOneWidget);
    });

    testWidgets('filters out another job and non-pending applications', (tester) async {
      stubRequests([
        _request('r1', 'w1'),
        _request('elsewhere', 'w2', jobId: 'another-job'),
        _request('declined', 'w3', status: JobRequestStatus.declined),
      ]);
      stubWorker('w1');
      await pumpApplicants(tester);
      expect(find.text('Worker w1'), findsOneWidget);
      verifyNever(() => profiles.getWorkerProfile('w2'));
      verifyNever(() => profiles.getWorkerProfile('w3'));
    });

    testWidgets('accept delegates to atomic selection and shows the confirmed worker', (tester) async {
      stubRequests([_request('r1', 'w1'), _request('r2', 'w2')]);
      stubWorker('w1');
      stubWorker('w2');
      await pumpApplicants(tester);
      await tester.tap(find.byKey(const Key('applicant-accept-r1')));
      await tester.pumpAndSettle();
      verify(() => requests.acceptApplicant(
        jobId: 'j1', requestId: 'r1', ownerId: 'me', jobService: jobs,
      )).called(1);
      expect(find.text('Worker confirmed'), findsOneWidget);
      expect(find.text('Worker w1'), findsOneWidget);
      expect(find.text('This worker is now handling your job.'), findsOneWidget);
      expect(find.textContaining('Other pending applicants were declined'), findsOneWidget);
      expect(find.byKey(const Key('applicant-accept-r1')), findsNothing);
      expect(find.byKey(const Key('applicant-accept-r2')), findsNothing);
    });

    testWidgets('an in-flight decision disables every applicant action', (tester) async {
      final pending = Completer<void>();
      stubRequests([_request('r1', 'w1'), _request('r2', 'w2')]);
      stubWorker('w1');
      stubWorker('w2');
      when(() => requests.acceptApplicant(
        jobId: 'j1', requestId: 'r1', ownerId: 'me', jobService: jobs,
      )).thenAnswer((_) => pending.future);
      await pumpApplicants(tester);
      await tester.tap(find.byKey(const Key('applicant-accept-r1')));
      await tester.pump();
      for (final id in ['r1', 'r2']) {
        expect(tester.widget<ElevatedButton>(
            find.byKey(Key('applicant-accept-$id'))).onPressed, isNull);
        expect(tester.widget<OutlinedButton>(
            find.byKey(Key('applicant-decline-$id'))).onPressed, isNull);
      }
      pending.complete();
      await tester.pumpAndSettle();
      verify(() => requests.acceptApplicant(
        jobId: 'j1', requestId: 'r1', ownerId: 'me', jobService: jobs,
      )).called(1);
    });

    testWidgets('failed acceptance leaves candidates available with an error', (tester) async {
      stubRequests([_request('r1', 'w1'), _request('r2', 'w2')]);
      stubWorker('w1');
      stubWorker('w2');
      when(() => requests.acceptApplicant(
        jobId: 'j1', requestId: 'r1', ownerId: 'me', jobService: jobs,
      )).thenThrow(Exception('permission denied'));
      await pumpApplicants(tester);
      await tester.tap(find.byKey(const Key('applicant-accept-r1')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Could not confirm this applicant.'), findsOneWidget);
      expect(find.text('Worker w1'), findsOneWidget);
      expect(find.text('Worker w2'), findsOneWidget);
      expect(find.text('Worker confirmed'), findsNothing);
      expect(tester.widget<ElevatedButton>(
          find.byKey(const Key('applicant-accept-r1'))).onPressed, isNotNull);
    });

    testWidgets('a stalled decision times out and re-enables the buttons', (tester) async {
      final pending = Completer<void>();
      stubRequests([_request('r1', 'w1')]);
      stubWorker('w1');
      when(() => requests.acceptApplicant(
        jobId: 'j1', requestId: 'r1', ownerId: 'me', jobService: jobs,
      )).thenAnswer((_) => pending.future);
      await pumpApplicants(tester);
      await tester.tap(find.byKey(const Key('applicant-accept-r1')));
      await tester.pump(const Duration(seconds: 16));
      await tester.pump();
      expect(find.textContaining('Could not confirm this applicant.'), findsOneWidget);
      expect(tester.widget<ElevatedButton>(
          find.byKey(const Key('applicant-accept-r1'))).onPressed, isNotNull);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      pending.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('an older profile fetch cannot overwrite a newer request snapshot', (tester) async {
      final controller = StreamController<List<JobRequest>>.broadcast();
      final oldProfile = Completer<WorkerProfile?>();
      addTearDown(controller.close);
      when(() => requests.watchUserRequests('me')).thenAnswer((_) => controller.stream);
      stubWorker('old');
      stubWorker('new');
      when(() => profiles.getWorkerProfile('old')).thenAnswer((_) => oldProfile.future);
      await pumpApplicants(tester);
      controller.add([_request('rOld', 'old')]);
      await tester.pump();
      controller.add([_request('rNew', 'new')]);
      await tester.pump();
      await tester.pump();
      expect(find.text('Worker new'), findsOneWidget);
      oldProfile.complete(_worker('old'));
      await tester.pumpAndSettle();
      expect(find.text('Worker new'), findsOneWidget);
      expect(find.text('Worker old'), findsNothing);
    });

    testWidgets('declining confirms, cancelling performs no write, confirming writes once', (tester) async {
      stubRequests([_request('r1', 'w1')]);
      stubWorker('w1');
      await pumpApplicants(tester);
      await tester.tap(find.byKey(const Key('applicant-decline-r1')));
      await tester.pumpAndSettle();
      expect(find.text('Decline this applicant?'), findsOneWidget);
      verifyNever(() => requests.respondToRequest(
        requestId: 'r1', status: JobRequestStatus.declined,
      ));
      await tester.tap(find.byKey(const Key('cancel-decline-button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('applicant-decline-r1')), findsOneWidget);
      verifyNever(() => requests.respondToRequest(
        requestId: 'r1', status: JobRequestStatus.declined,
      ));
      await tester.tap(find.byKey(const Key('applicant-decline-r1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirm-decline-button')));
      await tester.pumpAndSettle();
      verify(() => requests.respondToRequest(
        requestId: 'r1', status: JobRequestStatus.declined,
      )).called(1);
      expect(find.text('Applicant declined.'), findsOneWidget);
      expect(find.text('No applicants yet'), findsOneWidget);
    });

    testWidgets('an already assigned job shows only the confirmed worker', (tester) async {
      when(() => jobs.watchJob('j1')).thenAnswer((_) =>
          Stream<JobModel?>.value(_job(status: JobStatus.assigned, workerId: 'w1')));
      stubRequests([_request('r1', 'w1', status: JobRequestStatus.accepted)]);
      stubWorker('w1');
      await pumpApplicants(tester);
      expect(find.text('Worker w1'), findsOneWidget);
      expect(find.text('This worker is now handling your job.'), findsOneWidget);
      expect(find.byKey(const Key('applicant-accept-r1')), findsNothing);
    });

    testWidgets('missing worker profiles cannot be accepted blindly', (tester) async {
      stubRequests([_request('r1', 'deleted-worker')]);
      when(() => profiles.getWorkerProfile('deleted-worker')).thenAnswer((_) async => null);
      await pumpApplicants(tester);
      expect(find.text('Worker profile unavailable'), findsOneWidget);
      expect(tester.widget<ElevatedButton>(
          find.byKey(const Key('applicant-accept-r1'))).onPressed, isNull);
      expect(tester.widget<OutlinedButton>(
          find.byKey(const Key('applicant-decline-r1'))).onPressed, isNotNull);
    });

    testWidgets('user-authored names and messages render in their own direction', (tester) async {
      stubRequests([_request('r1', 'w1', message: 'میں یہ کام کر سکتا ہوں')]);
      stubWorker('w1', name: 'محمد علی');
      await pumpApplicants(tester);
      expect(tester.widget<Text>(find.text('محمد علی')).textDirection, TextDirection.rtl);
      expect(tester.widget<Text>(find.text('میں یہ کام کر سکتا ہوں')).textDirection,
          TextDirection.rtl);
    });

    testWidgets('cancelled jobs cannot accept applicants', (tester) async {
      when(() => jobs.watchJob('j1'))
          .thenAnswer((_) => Stream<JobModel?>.value(_job(status: JobStatus.cancelled)));
      await pumpApplicants(tester);
      expect(find.text('This job is closed'), findsOneWidget);
      expect(find.text('Back to job'), findsOneWidget);
    });

    testWidgets('a non-owner cannot choose applicants', (tester) async {
      when(() => jobs.watchJob('j1'))
          .thenAnswer((_) => Stream<JobModel?>.value(_job(owner: 'someone-else')));
      await pumpApplicants(tester);
      expect(find.text('Job unavailable'), findsOneWidget);
      expect(find.text('Only the job owner can view and choose applicants.'), findsOneWidget);
    });
  });
}
