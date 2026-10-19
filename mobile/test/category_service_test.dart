// ignore_for_file: subtype_of_sealed_class
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quickfix/models/job_model.dart';
import 'package:quickfix/services/category_service.dart';

class MockFirestore extends Mock implements FirebaseFirestore {}
class MockCollection extends Mock implements CollectionReference<Map<String, dynamic>> {}
class MockSnapshot extends Mock implements QuerySnapshot<Map<String, dynamic>> {}
class MockDocument extends Fake implements QueryDocumentSnapshot<Map<String, dynamic>> {
  @override final String id;
  final Map<String, dynamic> values;
  MockDocument(this.id, this.values);
  @override Map<String, dynamic> data() => values;
  @override bool get exists => true;
}

void main() {
  late MockFirestore firestore;
  late MockCollection collection;
  late MockSnapshot snapshot;
  late CategoryService service;
  setUp(() {
    firestore = MockFirestore(); collection = MockCollection(); snapshot = MockSnapshot();
    service = CategoryService(firestore: firestore);
    when(() => firestore.collection('categories')).thenReturn(collection);
    when(() => collection.get()).thenAnswer((_) async => snapshot);
  });
  MockDocument document(String id, Map<String, dynamic> data) {
    return MockDocument(id, data);
  }
  test('admin names map to real enum values', () {
    expect(CategoryService.categoryFor({'name': 'applianceRepair'}, 'random-id'), JobCategory.applianceRepair);
    expect(CategoryService.categoryFor({'name': 'plumbing'}, 'random-id'), JobCategory.plumbing);
  });
  test('legacy fields, display labels and snake-case document ids resolve', () {
    expect(CategoryService.categoryFor({'category': 'plumbing', 'name': 'Custom plumbing'}, 'legacy'), JobCategory.plumbing);
    expect(CategoryService.categoryFor({'name': 'Appliance Repair'}, 'legacy'), JobCategory.applianceRepair);
    expect(CategoryService.categoryFor({}, 'appliance_repair'), JobCategory.applianceRepair);
  });
  test('unknown labels are not silently coerced to Other', () {
    expect(CategoryService.categoryFor({'name': 'Unknown custom category'}, 'random-id'), isNull);
  });
  test('missing catalog uses the enum, but a present inactive catalog stays inactive', () async {
    when(() => snapshot.docs).thenReturn([]);
    expect((await service.getCategories()).map((c) => c.category).toSet(), JobCategory.values.toSet());
    when(() => snapshot.docs).thenReturn([document('plumbing', {'name': 'plumbing', 'isActive': false})]);
    final inactive = await service.getCategories();
    expect(inactive.length, 1); expect(inactive.single.isActive, isFalse);
  });
  test('deduplicates legacy/admin records and prefers canonical document ids', () async {
    when(() => snapshot.docs).thenReturn([
      document('appliance_repair', {'category': 'applianceRepair', 'name': 'Old label'}),
      document('applianceRepair', {'name': 'applianceRepair', 'isActive': false}),
    ]);
    final result = await service.getCategories();
    expect(result.length, 1); expect(result.single.id, 'applianceRepair'); expect(result.single.isActive, isFalse);
  });
  test('sorts by order and omits unknown catalog identifiers', () async {
    when(() => snapshot.docs).thenReturn([
      document('plumbing', {'name': 'plumbing', 'sortOrder': 2}),
      document('beauty', {'name': 'beauty', 'sortOrder': 1}),
      document('unknown', {'name': 'unknown'}),
    ]);
    expect((await service.getCategories()).map((c) => c.category), [JobCategory.beauty, JobCategory.plumbing]);
  });
  test('read errors propagate for the screen Retry instead of a false empty catalog', () async {
    when(() => collection.get()).thenThrow(StateError('offline'));
    await expectLater(service.getCategories(), throwsStateError);
  });
}
