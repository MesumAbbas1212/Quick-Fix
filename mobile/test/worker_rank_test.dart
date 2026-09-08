import 'package:flutter_test/flutter_test.dart';
import 'package:quickfix/models/worker_rank.dart';

void main() {
  group('WorkerRank ladder', () {
    test('tiers are ordered Apprentice -> Journeyman -> Expert -> Master -> Grandmaster',
        () {
      expect(WorkerRank.tiers.map((t) => t.name).toList(), [
        'Apprentice',
        'Journeyman',
        'Expert',
        'Master',
        'Grandmaster',
      ]);
      for (var i = 1; i < WorkerRank.tiers.length; i++) {
        expect(
          WorkerRank.tiers[i].minJobsInYear,
          greaterThan(WorkerRank.tiers[i - 1].minJobsInYear),
        );
      }
      expect(WorkerRank.tiers.first.minJobsInYear, 0);

      // Policy: every rank step is exactly 156 completions per year.
      for (var i = 0; i < WorkerRank.tiers.length; i++) {
        expect(
          WorkerRank.tiers[i].minJobsInYear,
          i * 156,
          reason: 'tier $i should sit at ${i * 156} completions/year',
        );
      }
    });

    test('zero completions is the entry rank', () {
      expect(WorkerRank.forCompletedInYear(0).name, 'Apprentice');
      expect(WorkerRank.forCompletedInYear(155).name, 'Apprentice');
    });

    test('reaching or surpassing a threshold grants the next rank', () {
      final expectations = <(int, String)>[
        (155, 'Apprentice'),
        (156, 'Journeyman'),
        (311, 'Journeyman'),
        (312, 'Expert'),
        (467, 'Expert'),
        (468, 'Master'),
        (623, 'Master'),
        (624, 'Grandmaster'),
        (700, 'Grandmaster'),
      ];
      for (final (count, name) in expectations) {
        expect(WorkerRank.forCompletedInYear(count).name, name,
            reason: '$count completed jobs should be $name');
      }
    });

    test('negative counts clamp to Apprentice', () {
      expect(WorkerRank.forCompletedInYear(-3).name, 'Apprentice');
    });

    test('each tier knows its next rank and remaining jobs', () {
      expect(WorkerRank.forCompletedInYear(156).nextRank?.name, 'Expert');
      expect(WorkerRank.forCompletedInYear(150).jobsUntilNext(150), 6);
      expect(WorkerRank.forCompletedInYear(0).jobsUntilNext(0), 156);
      expect(WorkerRank.forCompletedInYear(624).nextRank, isNull);
      expect(WorkerRank.forCompletedInYear(700).jobsUntilNext(700), isNull);
    });
  });

  group('WorkerRank.countCompletedInYear', () {
    final now = DateTime(2026, 9, 1);

    test('counts completions inside the trailing 365-day window', () {
      final stamps = [
        now.subtract(const Duration(days: 10)),
        now.subtract(const Duration(days: 200)),
        now.subtract(const Duration(days: 364)),
        now.subtract(const Duration(days: 366)),
        now.subtract(const Duration(days: 700)),
      ];
      expect(WorkerRank.countCompletedInYear(stamps, now: now), 3);
    });

    test('includes the exact window edge and the now instant', () {
      final stamps = [
        now.subtract(const Duration(days: 365)),
        now,
      ];
      expect(WorkerRank.countCompletedInYear(stamps, now: now), 2);
    });

    test('ignores future-dated completions', () {
      final stamps = [
        now.add(const Duration(days: 30)),
        now.subtract(const Duration(days: 1)),
      ];
      expect(WorkerRank.countCompletedInYear(stamps, now: now), 1);
    });

    test('empty history counts zero', () {
      expect(WorkerRank.countCompletedInYear(<DateTime>[], now: now), 0);
    });
  });
}
