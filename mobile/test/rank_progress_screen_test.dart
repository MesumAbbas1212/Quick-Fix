import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quickfix/core/widgets/loading_list.dart';
import 'package:quickfix/core/widgets/rank_badge.dart';
import 'package:quickfix/models/job_model.dart';
import 'package:quickfix/models/worker_rank.dart';
import 'package:quickfix/services/job_service.dart';
import 'package:quickfix/views/worker/rank_progress_screen.dart';

class MockJobService extends Mock implements JobService {}

final _now = DateTime.utc(2026, 10, 18, 12);

JobModel _job(DateTime at, {String id = 'j1', JobStatus status = JobStatus.completed}) =>
    JobModel(
      id: id,
      userId: 'c1',
      workerId: 'w1',
      title: 'Job $id',
      description: 'Work',
      category: JobCategory.other,
      address: 'Attock',
      location: const GeoPoint(33.77, 72.37),
      budgetMin: 1000,
      budgetMax: 5000,
      preferredDate: at,
      status: status,
      completedAt: at,
      createdAt: at,
      updatedAt: at,
    );

List<JobModel> _jobs(int count) => [
      for (var i = 0; i < count; i++)
        // More than one job per day is valid. All 624 must be within a year.
        _job(_now.subtract(Duration(days: 1 + i % 300)), id: 'j$i'),
    ];

void main() {
  group('RankProgressScreen', () {
    late MockJobService service;

    setUp(() => service = MockJobService());

    Future<void> pumpProgress(WidgetTester tester) async {
      tester.view.physicalSize = const Size(400, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: RankProgressScreen(
          workerUid: 'w1', jobService: service, clock: () => _now,
        ),
      ));
      await tester.pump();
    }

    void stubJobs(List<JobModel> jobs) =>
        when(() => service.watchCompletedJobsForWorker('w1'))
            .thenAnswer((_) => Stream<List<JobModel>>.value(jobs));

    testWidgets('shows skeletons while waiting for the completion stream', (tester) async {
      final controller = StreamController<List<JobModel>>();
      addTearDown(controller.close);
      when(() => service.watchCompletedJobsForWorker('w1'))
          .thenAnswer((_) => controller.stream);
      await pumpProgress(tester);
      expect(find.byType(LoadingList), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('zero jobs shows Apprentice, a back action and the entire ladder', (tester) async {
      stubJobs([]);
      await pumpProgress(tester);
      expect(find.text('Rank progress'), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const Key('current-rank-name'))).data,
          'Apprentice');
      expect(find.text('0 jobs completed in the last 12 months'), findsOneWidget);
      expect(find.text('+156 to Journeyman'), findsOneWidget);
      expect(find.text('Threshold: 156 jobs in the last 12 months'), findsOneWidget);
      for (final tier in WorkerRank.tiers) {
        expect(find.text(tier.name), findsWidgets);
        expect(find.text('${tier.minJobsInYear} jobs / year'), findsOneWidget);
      }
      expect(find.byKey(const Key('rank-back-button')), findsOneWidget);
      expect(find.text('How ranks work'), findsOneWidget);
      expect(find.textContaining('rank can also be lost'), findsOneWidget);
      final emblems = tester.widgetList<RankEmblem>(find.byType(RankEmblem));
      expect(emblems.first.size, 64);
      expect(emblems.length, WorkerRank.tiers.length + 1);
      verify(() => service.watchCompletedJobsForWorker('w1')).called(1);
    });

    testWidgets('156 jobs reaches Journeyman and targets Expert', (tester) async {
      stubJobs(_jobs(156));
      await pumpProgress(tester);
      expect(tester.widget<Text>(find.byKey(const Key('current-rank-name'))).data,
          'Journeyman');
      expect(find.text('156 jobs completed in the last 12 months'), findsOneWidget);
      expect(find.text('+156 to Expert'), findsOneWidget);
      expect(find.text('156 / 312'), findsOneWidget);
      expect(tester.widget<LinearProgressIndicator>(
          find.byKey(const Key('rank-next-progress'))).value, 0);
      expect(tester.widget<Text>(find.byKey(const Key('rank-state-Apprentice'))).data,
          'Achieved');
      expect(tester.widget<Text>(find.byKey(const Key('rank-state-Journeyman'))).data,
          'Current');
      expect(tester.widget<Text>(find.byKey(const Key('rank-state-Expert'))).data,
          'Locked');
    });

    testWidgets('progress measures the current step, not the lifetime total', (tester) async {
      stubJobs(_jobs(200));
      await pumpProgress(tester);
      final bar = tester.widget<LinearProgressIndicator>(
          find.byKey(const Key('rank-next-progress')));
      expect(bar.value, closeTo((200 - 156) / (312 - 156), 0.000001));
      expect(find.text('+112 to Expert'), findsOneWidget);
    });

    testWidgets('excludes old, future and non-completed jobs', (tester) async {
      stubJobs([
        _job(_now.subtract(const Duration(days: 400)), id: 'old'),
        _job(_now.add(const Duration(days: 1)), id: 'future'),
        _job(_now.subtract(const Duration(days: 1)), id: 'open', status: JobStatus.open),
      ]);
      await pumpProgress(tester);
      expect(find.text('0 jobs completed in the last 12 months'), findsOneWidget);
      expect(find.text('+156 to Journeyman'), findsOneWidget);
    });

    testWidgets('includes the exact 365-day boundary', (tester) async {
      stubJobs([_job(_now.subtract(const Duration(days: 365)))]);
      await pumpProgress(tester);
      expect(find.text('1 job completed in the last 12 months'), findsOneWidget);
      expect(find.text('+155 to Journeyman'), findsOneWidget);
    });

    testWidgets('Grandmaster has a maxed-out state and no progress bar', (tester) async {
      stubJobs(_jobs(624));
      await pumpProgress(tester);
      expect(tester.widget<Text>(find.byKey(const Key('current-rank-name'))).data,
          'Grandmaster');
      expect(find.text('Highest rank reached'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.textContaining('to Journeyman'), findsNothing);
      expect(find.textContaining('to Expert'), findsNothing);
    });

    testWidgets('a stream error offers a real retry that reloads jobs', (tester) async {
      when(() => service.watchCompletedJobsForWorker('w1'))
          .thenAnswer((_) => Stream<List<JobModel>>.error(Exception('offline')));
      await pumpProgress(tester);
      expect(find.text('Could not load rank progress. Check your connection.'), findsOneWidget);
      stubJobs(_jobs(156));
      await tester.tap(find.byKey(const Key('error-retry-button')));
      await tester.pumpAndSettle();
      expect(find.text('156 jobs completed in the last 12 months'), findsOneWidget);
      verify(() => service.watchCompletedJobsForWorker('w1')).called(2);
    });
  });
}
