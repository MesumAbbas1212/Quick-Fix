import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quickfix/features/payments/presentation/mock_payment_screen.dart';

void main() {
  testWidgets('MockPaymentScreen renders job summary and pay button',
      (tester) async {
    tester.view.physicalSize = const Size(600, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: MockPaymentScreen(
          jobId: 'job1',
          jobTitle: 'AC Repair',
          amount: 2500,
          payerId: 'user1',
          workerId: 'worker1',
        ),
      ),
    );

    expect(find.text('Mock Payment'), findsOneWidget);
    expect(find.text('AC Repair'), findsOneWidget);
    expect(find.textContaining('Pay PKR 2500'), findsOneWidget);
  });

  testWidgets('tapping pay shows success sheet', (tester) async {
    tester.view.physicalSize = const Size(600, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: MockPaymentScreen(
          jobId: 'job1',
          jobTitle: 'AC Repair',
          amount: 2500,
          payerId: 'user1',
          workerId: 'worker1',
        ),
      ),
    );

    await tester.tap(find.textContaining('Pay PKR 2500'));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(find.text('Payment Successful'), findsOneWidget);
  });
}
