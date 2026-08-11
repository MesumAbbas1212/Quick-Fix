import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quickfix/core/theme/app_theme.dart';
import 'package:quickfix/models/job_model.dart';
import 'package:quickfix/views/jobs/job_request_screen.dart';

JobModel _buildJob() {
  return JobModel(
    id: 'job-1',
    userId: 'user-1',
    title: 'Fix leaking kitchen faucet',
    description: 'Dripping tap under the sink needs a new washer.',
    category: JobCategory.plumbing,
    address: 'Model Town, Lahore',
    location: const GeoPoint(31.5204, 74.3587),
    budgetMin: 1500,
    budgetMax: 2800,
    preferredDate: DateTime(2026, 8, 15),
    preferredTime: DateTime(2026, 8, 15, 10, 0),
    images: const [],
    status: JobStatus.open,
    rating: null,
    createdAt: DateTime(2026, 8, 10),
    updatedAt: DateTime(2026, 8, 10),
  );
}

void main() {
  testWidgets('accept button is green and decline is red', (tester) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: JobRequestScreen(job: _buildJob()),
    ));

    final accept = tester.widget<ElevatedButton>(find.widgetWithText(
        ElevatedButton, 'Accept Job'));
    final decline =
        tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Decline'));

    expect(accept.style!.backgroundColor!.resolve({}), AppTheme.successGreen);
    expect(decline.style!.backgroundColor!.resolve({}), AppTheme.dangerRed);
  });

  testWidgets('client info shows posting date and preferred date',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: JobRequestScreen(job: _buildJob()),
    ));

    await tester.ensureVisible(find.text('Posted:'));
    await tester.pumpAndSettle();

    expect(find.text('Posted:'), findsOneWidget);
    expect(find.text('August 10, 2026'), findsOneWidget);
    expect(find.text('Preferred Date:'), findsOneWidget);
    expect(find.text('August 15, 2026'), findsOneWidget);
  });

  testWidgets('star row reflects the client rating', (tester) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: JobRequestScreen(job: _buildJob()),
    ));

    await tester.ensureVisible(find.text('Rating:'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.star), findsNWidgets(5));
    expect(find.byIcon(Icons.star_border), findsNothing);
  });
}
