import 'helpers/visible.dart' as test_viewport;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quickfix/models/account_deletion_policy.dart';
import 'package:quickfix/models/payment_model.dart';
import 'package:quickfix/models/payout_request.dart';
import 'package:quickfix/services/payout_service.dart';
import 'package:quickfix/views/worker/payout_screen.dart';
class MockPayouts extends Mock implements PayoutService {}
void main() {
  test('PKR parsing uses integer paisa and rejects excessive/nonfinite precision', () {
    expect(PayoutService.parsePaisa('12.34'), 1234); expect(PayoutService.parsePaisa('0.01'), 1);
    for (final text in ['NaN', 'Infinity', '-1', '1.001', '1e3', '90071992547409.99']) { expect(PayoutService.parsePaisa(text), isNull); }
    expect(PayoutRequest.fromMap({'amount': 12.34}, 'p').amountPaisa, 1234);
  });
  test('only paid receipts count; pending/paid payouts reserve but rejected ones do not', () {
    Payment paid(String worker, String status) => Payment(id: '', jobId: 'j', payerId: 'c', workerId: worker, amount: 100, status: status, createdAt: DateTime(2026));
    expect(PayoutService.receivedPaisa('w', [paid('w', 'paid'), paid('w', 'failed'), paid('other', 'paid')]), 10000);
    PayoutRequest payout(String status) => PayoutRequest(id: status, workerId: 'w', amountPaisa: 1000, method: 'bank', accountRef: 'DEMO', status: status);
    expect(PayoutService.reservedPaisa([payout('pending'), payout('paid'), payout('rejected')]), 2000);
    expect(const PayoutSnapshot(receivedPaisa: 1000, reservedPaisa: 2000, revision: 1).availablePaisa, 0);
  });
  test('withdrawal erasure drops bank/unknown identity fields and retains accounting', () {
    final retained = AccountDeletionPolicy.retainedPayout({'workerId': 'w', 'amount': 12, 'amountPaisa': 1200, 'status': 'pending', 'method': 'bank', 'accountRef': 'secret', 'name': 'Private'}, 'w');
    expect(retained['workerId'], AccountDeletionPolicy.deletedAccount); expect(retained['amountPaisa'], 1200); expect(retained.containsKey('accountRef'), isFalse); expect(retained.containsKey('name'), isFalse);
  });
  testWidgets('load error retries a real no-balance/history state', (tester) async {
    final service = MockPayouts(); when(() => service.load('w')).thenThrow(StateError('offline'));
    await tester.pumpWidget(MaterialApp(home: PayoutScreen(workerId: 'w', payoutService: service))); await tester.pumpAndSettle();
    when(() => service.load('w')).thenAnswer((_) async => const PayoutSnapshot(receivedPaisa: 0, reservedPaisa: 0, revision: 0)); await tester.tap(find.text('Retry')); await tester.pumpAndSettle();
    expect(find.text('Available: PKR 0.00'), findsOneWidget); expect(tester.widget<ElevatedButton>(find.byKey(const Key('payout-request'))).onPressed, isNull); await test_viewport.reveal(tester, find.text('No withdrawal requests yet')); expect(find.text('No withdrawal requests yet'), findsOneWidget);
  });
}
