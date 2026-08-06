import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quickfix/features/reviews/presentation/review_screen.dart';

void main() {
  testWidgets('ReviewScreen renders stars, text field and submit button',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: ReviewScreen(
              jobId: 'job1',
              workerId: 'worker1',
              reviewerId: 'user1',
            ),
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.star_border), findsNWidgets(5));
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Submit Review'), findsOneWidget);
  });

  testWidgets('tapping the third star selects 3 stars', (tester) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: ReviewScreen(
              jobId: 'job1',
              workerId: 'worker1',
              reviewerId: 'user1',
            ),
          ),
        ),
      ),
    );

    final stars = find.byIcon(Icons.star_border);
    await tester.tap(stars.at(2));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.star), findsNWidgets(3));
    expect(find.byIcon(Icons.star_border), findsNWidgets(2));
  });
}
