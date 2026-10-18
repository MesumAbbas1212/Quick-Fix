// ignore_for_file: subtype_of_sealed_class
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quickfix/services/payment_service.dart';

class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}

class MockCollectionReference
    extends Mock
    implements CollectionReference<Map<String, dynamic>> {}

class MockQuery extends Mock implements Query<Map<String, dynamic>> {}

class MockDocumentReference
    extends Mock
    implements DocumentReference<Map<String, dynamic>> {}

class MockQuerySnapshot
    extends Mock
    implements QuerySnapshot<Map<String, dynamic>> {}

class MockDocumentSnapshot
    extends Mock
    implements DocumentSnapshot<Map<String, dynamic>> {}

Map<String, dynamic> _paymentMap({
  String jobId = 'job1',
  String payerId = 'client1',
  String workerId = 'worker1',
  double amount = 5000,
  String status = 'paid',
}) {
  return {
    'jobId': jobId,
    'payerId': payerId,
    'workerId': workerId,
    'amount': amount,
    'status': status,
    'method': 'cash',
    'createdAt': Timestamp.fromDate(DateTime(2026, 10, 5)),
  };
}

void main() {
  late MockFirebaseFirestore mockFirestore;
  late MockCollectionReference mockPayments;
  late MockQuery mockQuery;
  late MockQuerySnapshot mockSnapshot;
  late PaymentService service;

  setUp(() {
    mockFirestore = MockFirebaseFirestore();
    mockPayments = MockCollectionReference();
    mockQuery = MockQuery();
    mockSnapshot = MockQuerySnapshot();
    service = PaymentService(firestore: mockFirestore);
  });

  test('getPaidPaymentForJob returns the first paid payment', () async {
    when(() => mockFirestore.collection('payments'))
        .thenReturn(mockPayments);
    when(() => mockPayments.where('jobId', isEqualTo: 'job1'))
        .thenReturn(mockQuery);
    when(() => mockQuery.get()).thenAnswer((_) async => mockSnapshot);
    final docs = [MockDocumentSnapshot(), MockDocumentSnapshot()];
    when(() => mockSnapshot.docs).thenReturn(docs);
    when(() => docs[0].id).thenReturn('p1');
    when(() => docs[0].data()).thenReturn(_paymentMap(status: 'pending'));
    when(() => docs[1].id).thenReturn('p2');
    when(() => docs[1].data()).thenReturn(
      _paymentMap(status: 'paid', amount: 7000),
    );

    final paid = await service.getPaidPaymentForJob('job1');

    expect(paid, isNotNull);
    expect(paid!.status, 'paid');
    expect(paid.amount, 7000);
    expect(paid.id, 'p2');
  });

  test('getPaidPaymentForJob returns null when nothing is paid', () async {
    when(() => mockFirestore.collection('payments'))
        .thenReturn(mockPayments);
    when(() => mockPayments.where('jobId', isEqualTo: 'job1'))
        .thenReturn(mockQuery);
    when(() => mockQuery.get()).thenAnswer((_) async => mockSnapshot);
    when(() => mockSnapshot.docs).thenReturn([]);

    expect(await service.getPaidPaymentForJob('job1'), isNull);
  });

  test('watchPaymentsByPayer streams the client payments', () async {
    when(() => mockFirestore.collection('payments'))
        .thenReturn(mockPayments);
    when(() => mockPayments.where('payerId', isEqualTo: 'client1'))
        .thenReturn(mockQuery);
    when(() => mockQuery.snapshots())
        .thenAnswer((_) => Stream.value(mockSnapshot));
    final doc = MockDocumentSnapshot();
    when(() => mockSnapshot.docs).thenReturn([doc]);
    when(() => doc.id).thenReturn('p1');
    when(() => doc.data()).thenReturn(_paymentMap(payerId: 'client1'));

    final events = await service
        .watchPaymentsByPayer('client1')
        .take(1)
        .toList();

    expect(events.single, hasLength(1));
    expect(events.single.first.jobId, 'job1');
    expect(events.single.first.payerId, 'client1');
  });

  test('watchPaymentsByWorker streams the worker income', () async {
    when(() => mockFirestore.collection('payments'))
        .thenReturn(mockPayments);
    when(() => mockPayments.where('workerId', isEqualTo: 'worker9'))
        .thenReturn(mockQuery);
    when(() => mockQuery.snapshots())
        .thenAnswer((_) => Stream.value(mockSnapshot));
    final doc = MockDocumentSnapshot();
    when(() => mockSnapshot.docs).thenReturn([doc]);
    when(() => doc.id).thenReturn('p9');
    when(() => doc.data())
        .thenReturn(_paymentMap(workerId: 'worker9', amount: 9000));

    final events = await service
        .watchPaymentsByWorker('worker9')
        .take(1)
        .toList();

    expect(events.single, hasLength(1));
    expect(events.single.first.amount, 9000);
    expect(events.single.first.workerId, 'worker9');
  });

  test('simulatePayment writes a paid payment and marks the job paid',
      () async {
    final mockJobs = MockCollectionReference();
    final mockJobDoc = MockDocumentReference();
    final mockAddedDoc = MockDocumentReference();
    when(() => mockFirestore.collection('payments'))
        .thenReturn(mockPayments);
    when(() => mockFirestore.collection('jobs')).thenReturn(mockJobs);
    when(() => mockPayments.add(any()))
        .thenAnswer((_) async => mockAddedDoc);
    when(() => mockAddedDoc.id).thenReturn('newPayment');
    when(() => mockJobs.doc('job1')).thenReturn(mockJobDoc);
    when(() => mockJobDoc.update(any())).thenAnswer((_) async {});

    final payment = await service.simulatePayment(
      jobId: 'job1',
      payerId: 'client1',
      workerId: 'worker1',
      amount: 4000,
    );

    expect(payment.id, 'newPayment');
    expect(payment.status, 'paid');
    verify(
      () => mockPayments.add(any(that: (m) => m['amount'] == 4000)),
    ).called(1);
    verify(() => mockJobDoc.update(any())).called(1);
  });
}
