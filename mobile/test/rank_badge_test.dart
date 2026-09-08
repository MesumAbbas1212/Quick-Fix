import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quickfix/core/widgets/rank_badge.dart';
import 'package:quickfix/models/worker_rank.dart';

void main() {
  Widget wrap(Widget child) =>
      MaterialApp(home: Scaffold(body: Center(child: child)));

  testWidgets('shows the rank name', (tester) async {
    // 320 completions in the trailing year -> Expert (312 threshold).
    await tester.pumpWidget(
      wrap(RankBadge(rank: WorkerRank.forCompletedInYear(320))),
    );
    expect(find.text('Expert'), findsOneWidget);
  });

  testWidgets('draws the vector emblem (not an icon glyph)', (tester) async {
    final rank = WorkerRank.forCompletedInYear(320);
    await tester.pumpWidget(wrap(RankBadge(rank: rank)));
    // The emblem is a CustomPaint-drawn shape.
    expect(find.byType(RankEmblem), findsOneWidget);
    expect(find.byType(CustomPaint), findsOneWidget);
    // No Material icon glyph inside the badge.
    expect(find.descendant(of: find.byType(RankEmblem), matching: find.byType(Icon)), findsNothing);
  });

  testWidgets('shows progress to the next rank when count provided',
      (tester) async {
    // 320 jobs: Expert, 148 short of Master (468).
    await tester.pumpWidget(
      wrap(
        RankBadge(
          rank: WorkerRank.forCompletedInYear(320),
          completedInYear: 320,
        ),
      ),
    );
    expect(find.text('Expert'), findsOneWidget);
    expect(find.text('+148 to Master'), findsOneWidget);
  });

  testWidgets('no progress text at the top rank', (tester) async {
    await tester.pumpWidget(
      wrap(
        RankBadge(
          rank: WorkerRank.forCompletedInYear(700),
          completedInYear: 700,
        ),
      ),
    );
    expect(find.text('Grandmaster'), findsOneWidget);
    // Only the rank name is shown — no extra Text widgets.
    expect(find.byType(Text), findsOneWidget);
  });

  testWidgets('no progress text when completedInYear omitted', (tester) async {
    // 156 completions -> Journeyman.
    await tester.pumpWidget(
      wrap(RankBadge(rank: WorkerRank.forCompletedInYear(156))),
    );
    expect(find.text('Journeyman'), findsOneWidget);
    expect(find.textContaining('to'), findsNothing);
  });
}
