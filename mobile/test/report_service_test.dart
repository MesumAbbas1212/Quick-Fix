// ignore_for_file: subtype_of_sealed_class
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quickfix/services/report_service.dart';

class MockDocumentReference extends Mock implements DocumentReference<Map<String, dynamic>> {}

class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}

class MockCollectionReference
    extends Mock
    implements CollectionReference<Map<String, dynamic>> {}

class MockQuery extends Mock implements Query<Map<String, dynamic>> {}

class MockQuerySnapshot
    extends Mock
    implements QuerySnapshot<Map<String, dynamic>> {}

class MockDocumentSnapshot
    extends Mock
    implements QueryDocumentSnapshot<Map<String, dynamic>> {}

void main() {
  late MockFirebaseFirestore mockFirestore;
  late MockCollectionReference mockReports;
  late MockQuery mockQuery;
  late MockQuerySnapshot mockSnapshot;
  late ReportService service;

  setUp(() {
    mockFirestore = MockFirebaseFirestore();
    mockReports = MockCollectionReference();
    mockQuery = MockQuery();
    mockSnapshot = MockQuerySnapshot();
    service = ReportService(firestore: mockFirestore);
  });

  test('submitReport writes an open report with reason and details', () async {
    final mockDoc = MockDocumentReference();
    when(() => mockFirestore.collection('reports')).thenReturn(mockReports);
    when(() => mockReports.add(any())).thenAnswer((_) async => mockDoc);

    await service.submitReport(
      reporterId: 'r1',
      reportedId: 'w1',
      reason: 'no_show',
      jobId: 'job1',
      details: '  Never arrived.  ',
    );

    final captured = verify(
      () => mockReports.add(captureAny()),
    ).captured.single as Map<String, dynamic>;
    expect(captured['reporterId'], 'r1');
    expect(captured['reportedId'], 'w1');
    expect(captured['reason'], 'no_show');
    expect(captured['status'], 'open');
    expect(captured['jobId'], 'job1');
    expect(captured['details'], 'Never arrived.');
  });

  test('submitReport omits null jobId and blank details', () async {
    when(() => mockFirestore.collection('reports')).thenReturn(mockReports);
    when(() => mockReports.add(any()))
        .thenAnswer((_) async => MockDocumentReference());

    await service.submitReport(
      reporterId: 'r1',
      reportedId: 'w1',
      reason: 'rude_behavior',
      details: '   ',
    );

    final captured = verify(
      () => mockReports.add(captureAny()),
    ).captured.single as Map<String, dynamic>;
    expect(captured.containsKey('jobId'), isFalse);
    expect(captured.containsKey('details'), isFalse);
  });

  test('hasOpenReport is true when an open report exists', () async {
    when(() => mockFirestore.collection('reports')).thenReturn(mockReports);
    when(() => mockReports.where('reporterId', isEqualTo: 'r1'))
        .thenReturn(mockQuery);
    when(() => mockQuery.where('reportedId', isEqualTo: 'w1'))
        .thenReturn(mockQuery);
    when(() => mockQuery.where('status', isEqualTo: 'open'))
        .thenReturn(mockQuery);
    when(() => mockQuery.limit(1)).thenReturn(mockQuery);
    when(() => mockQuery.get()).thenAnswer((_) async => mockSnapshot);
    when(() => mockSnapshot.docs)
        .thenReturn([MockDocumentSnapshot()]);

    expect(await service.hasOpenReport('r1', 'w1'), isTrue);
  });

  test('hasOpenReport is false when no open report exists', () async {
    when(() => mockFirestore.collection('reports')).thenReturn(mockReports);
    when(() => mockReports.where('reporterId', isEqualTo: 'r1'))
        .thenReturn(mockQuery);
    when(() => mockQuery.where('reportedId', isEqualTo: 'w1'))
        .thenReturn(mockQuery);
    when(() => mockQuery.where('status', isEqualTo: 'open'))
        .thenReturn(mockQuery);
    when(() => mockQuery.limit(1)).thenReturn(mockQuery);
    when(() => mockQuery.get()).thenAnswer((_) async => mockSnapshot);
    when(() => mockSnapshot.docs).thenReturn([]);

    expect(await service.hasOpenReport('r1', 'w1'), isFalse);
  });
}
