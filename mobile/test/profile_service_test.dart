// ignore_for_file: subtype_of_sealed_class
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quickfix/services/profile_service.dart';

class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}

class MockCollectionReference
    extends Mock implements CollectionReference<Map<String, dynamic>> {}

class MockQuery extends Mock implements Query<Map<String, dynamic>> {}

class MockQuerySnapshot
    extends Mock implements QuerySnapshot<Map<String, dynamic>> {}

class MockQueryDocSnapshot
    extends Mock implements QueryDocumentSnapshot<Map<String, dynamic>> {}

class MockDocumentReference
    extends Mock implements DocumentReference<Map<String, dynamic>> {}

Map<String, dynamic> _workerMap({bool withAvailability = true, bool available = true}) {
  return {
    'fullName': 'Imran Khan',
    'email': 'imran@quickfix.com',
    'professions': const ['plumbing'],
    'languages': const ['Urdu', 'English'],
    'minBudget': 1500.0,
    'maxBudget': 4000.0,
    'rating': 4.5,
    'completedJobs': 27,
    'reviews': 31,
    'location': const GeoPoint(31.52, 74.36),
    if (withAvailability) 'isAvailable': available,
    'createdAt': Timestamp.fromDate(DateTime.now()),
    'updatedAt': Timestamp.fromDate(DateTime.now()),
  };
}

void main() {
  late MockFirebaseFirestore mockFirestore;
  late MockCollectionReference mockCollection;
  late MockQuery mockQuery;
  late MockQuerySnapshot mockSnapshot;
  late MockQueryDocSnapshot mockDoc;

  setUp(() {
    mockFirestore = MockFirebaseFirestore();
    mockCollection = MockCollectionReference();
    mockQuery = MockQuery();
    mockSnapshot = MockQuerySnapshot();
    mockDoc = MockQueryDocSnapshot();
    when(() => mockFirestore.collection('workers')).thenReturn(mockCollection);
    when(() => mockCollection.limit(20)).thenReturn(mockQuery);
    when(() => mockQuery.get()).thenAnswer((_) async => mockSnapshot);
    when(() => mockSnapshot.docs).thenReturn([mockDoc]);
    when(() => mockDoc.data()).thenReturn(_workerMap());
    when(() => mockDoc.id).thenReturn('w1');
  });

  group('ProfileService.searchWorkers', () {
    test('returns workers missing isAvailable field when fromLocation given',
        () async {
      when(() => mockDoc.data()).thenReturn(_workerMap(withAvailability: false));

      final service = ProfileService(firestore: mockFirestore);
      final result = await service.searchWorkers(
        fromLocation: const GeoPoint(31.5, 74.3),
      );

      expect(result, hasLength(1));
      expect(result.first.fullName, 'Imran Khan');
      expect(result.first.isAvailable, isTrue);
      verifyNever(() => mockCollection.where(any()));
    });

    test('applies availability filter in Dart when onlyAvailable requested',
        () async {
      when(() => mockDoc.data())
          .thenReturn(_workerMap(available: false));

      final service = ProfileService(firestore: mockFirestore);
      final result = await service.searchWorkers(
        fromLocation: const GeoPoint(31.5, 74.3),
        onlyAvailable: true,
      );

      expect(result, isEmpty);
    });

    test('filters workers beyond maxDistanceKm', () async {
      when(() => mockDoc.data()).thenReturn(_workerMap());
      when(() => mockDoc.id).thenReturn('near');
      final farDoc = MockQueryDocSnapshot();
      when(() => farDoc.data()).thenReturn({
        ..._workerMap(),
        'location': const GeoPoint(35.0, 70.0),
      });
      when(() => farDoc.id).thenReturn('far');
      when(() => mockSnapshot.docs)
          .thenReturn([mockDoc, farDoc]);

      when(() => mockCollection.limit(20)).thenReturn(mockQuery);

      final service = ProfileService(firestore: mockFirestore);
      final result = await service.searchWorkers(
        fromLocation: const GeoPoint(31.5, 74.3),
        maxDistanceKm: 25,
      );

      expect(result, hasLength(1));
      expect(result.first.uid, 'near');
    });
  });

  group('ProfileService.syncWorkerIdentity', () {
    test('merges name/avatar/phone into the workers doc', () async {
      final mockDocRef = MockDocumentReference();
      when(() => mockFirestore.collection('workers')).thenReturn(mockCollection);
      when(() => mockCollection.doc('w1')).thenReturn(mockDocRef);
      when(() => mockDocRef.set(any(), any()))
          .thenAnswer((_) async {});

      final service = ProfileService(firestore: mockFirestore);
      await service.syncWorkerIdentity(
        uid: 'w1',
        fullName: 'New Name',
        avatarUrl: '/data/avatars/new.png',
        phone: '03001234567',
      );

      verify(() => mockDocRef.set(any(), any())).called(1);
      verifyNever(() => mockDocRef.delete());
    });
  });
}