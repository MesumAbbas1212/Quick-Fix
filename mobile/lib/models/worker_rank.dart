import 'package:flutter/material.dart';

/// Worker rank tier.
///
/// A worker holds a tier when the number of jobs they completed within the
/// trailing 12 months is at least [minJobsInYear] (reaching or surpassing
/// the threshold promotes them). [tiers] is ordered from the entry level
/// (Apprentice) up to the highest rank (Grandmaster).
class WorkerRank {
  final String name;
  final int minJobsInYear;
  final IconData icon;
  final Color color;

  const WorkerRank({
    required this.name,
    required this.minJobsInYear,
    required this.icon,
    required this.color,
  });

  /// The rank ladder, lowest to highest. Each entry defines the minimum
  /// number of jobs completed in the last 12 months required to hold it.
  ///
  /// Policy: one rank step = 156 completed jobs per year
  /// (~3 jobs a week, a full work year), so the thresholds are cumulative:
  /// Apprentice 0, Journeyman 156, Expert 312, Master 468, Grandmaster 624.
  static const List<WorkerRank> tiers = [
    WorkerRank(
      name: 'Apprentice',
      minJobsInYear: 0,
      icon: Icons.handyman,
      color: Color(0xFF64748B),
    ),
    WorkerRank(
      name: 'Journeyman',
      minJobsInYear: 156,
      icon: Icons.construction,
      color: Color(0xFF047857),
    ),
    WorkerRank(
      name: 'Expert',
      minJobsInYear: 312,
      icon: Icons.star,
      color: Color(0xFFB45309),
    ),
    WorkerRank(
      name: 'Master',
      minJobsInYear: 468,
      icon: Icons.diamond,
      color: Color(0xFF6D28D9),
    ),
    WorkerRank(
      name: 'Grandmaster',
      minJobsInYear: 624,
      icon: Icons.emoji_events,
      color: Color(0xFFB91C1C),
    ),
  ];

  /// Highest tier whose threshold [completedInYear] meets or surpasses.
  static WorkerRank forCompletedInYear(int completedInYear) {
    final count = completedInYear < 0 ? 0 : completedInYear;
    WorkerRank current = tiers.first;
    for (final tier in tiers) {
      if (count >= tier.minJobsInYear) current = tier;
    }
    return current;
  }

  /// Counts [completedAts] that fall inside the trailing [window]
  /// (365 days by default) ending at [now].
  static int countCompletedInYear(
    Iterable<DateTime> completedAts, {
    required DateTime now,
    Duration window = const Duration(days: 365),
  }) {
    final start = now.subtract(window);
    var count = 0;
    for (final ts in completedAts) {
      if (!ts.isBefore(start) && !ts.isAfter(now)) count++;
    }
    return count;
  }

  int get index => tiers.indexWhere((t) => t.name == name);

  /// The next rank up, or null at the top of the ladder.
  WorkerRank? get nextRank =>
      index >= 0 && index + 1 < tiers.length ? tiers[index + 1] : null;

  /// Jobs still needed to reach [nextRank] (null at the top rank).
  int? jobsUntilNext(int completedInYear) {
    final next = nextRank;
    if (next == null) return null;
    final remaining = next.minJobsInYear - completedInYear;
    return remaining > 0 ? remaining : 0;
  }
}
