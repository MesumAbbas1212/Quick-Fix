// ignore_for_file: subtype_of_sealed_class
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quickfix/services/local_image_store.dart';
import 'package:quickfix/services/verification_service.dart';
class MockFirestore extends Mock implements FirebaseFirestore {}
class MockCollection extends Mock implements CollectionReference<Map<String, dynamic>> {}
class MockReference extends Mock implements DocumentReference<Map<String, dynamic>> {}
class MockSnapshot extends Mock implements DocumentSnapshot<Map<String, dynamic>> {}
class MockTransaction extends Mock implements Transaction {}
class MockImages extends Mock implements LocalImageStore {}
void main() {
  late MockFirestore firestore; late MockReference private; late MockReference worker;
  late MockSnapshot proof; late MockSnapshot profile; late MockTransaction transaction; late MockImages images;
  late VerificationService service;
  setUpAll(() { registerFallbackValue((Transaction _) async {}); });
  setUp(() {
    firestore = MockFirestore(); private = MockReference(); worker = MockReference(); proof = MockSnapshot(); profile = MockSnapshot();
    transaction = MockTransaction(); images = MockImages();
    final proofs = MockCollection(); final workers = MockCollection();
    when(() => firestore.collection('workerVerifications')).thenReturn(proofs); when(() => proofs.doc('w')).thenReturn(private);
    when(() => firestore.collection('workers')).thenReturn(workers); when(() => workers.doc('w')).thenReturn(worker);
    when(() => transaction.get(private)).thenAnswer((_) async => proof); when(() => transaction.get(worker)).thenAnswer((_) async => profile);
    when(() => transaction.set(private, any())).thenReturn(transaction); when(() => transaction.update(worker, any())).thenReturn(transaction);
    when(() => profile.exists).thenReturn(true); when(() => profile.data()).thenReturn({}); when(() => proof.data()).thenReturn(null);
    when(() => private.get()).thenAnswer((_) async => proof);
    when(() => images.hasVerificationImage('w', any())).thenAnswer((_) async => true);
    when(() => firestore.runTransaction<void>(any())).thenAnswer((invocation) async {
      await (invocation.positionalArguments.single as Future<void> Function(Transaction))(transaction);
    });
    service = VerificationService(firestore: firestore, imageStore: images);
  });
  Future<void> submit({bool consent = true, String front = '/local/front'}) => service.submit(uid: 'w', cnicFrontPath: front,
    cnicBackPath: '/local/back', selfiePath: '/local/selfie', consent: consent);
  test('requires explicit consent before any database transaction', () async {
    await expectLater(submit(consent: false), throwsA(isA<VerificationException>()));
    verifyNever(() => firestore.runTransaction<void>(any()));
  });
  test('requires all three paths and device-available photos', () async {
    await expectLater(submit(front: ''), throwsA(isA<VerificationException>()));
    when(() => images.hasVerificationImage('w', '/local/front')).thenAnswer((_) async => false);
    await expectLater(submit(), throwsA(isA<VerificationException>())); verifyNever(() => firestore.runTransaction<void>(any()));
  });
  test('cannot submit before provisioning a worker profile', () async {
    when(() => profile.exists).thenReturn(false); await expectLater(submit(), throwsA(isA<VerificationException>()));
    verifyNever(() => transaction.set(private, any()));
  });
  test('writes proof references privately and publishes status only atomically', () async {
    await submit();
    final privateData = verify(() => transaction.set(private, captureAny())).captured.single as Map;
    expect(privateData['cnicFrontPath'], '/local/front'); expect(privateData['cnicBackPath'], '/local/back');
    expect(privateData['selfiePath'], '/local/selfie'); expect(privateData['consent'], isTrue); expect(privateData['submittedAt'], isA<FieldValue>());
    final publicData = verify(() => transaction.update(worker, captureAny())).captured.single as Map;
    final summary = publicData['verification'] as Map;
    expect(summary.keys, unorderedEquals(['status', 'submittedAt'])); expect(summary['status'], 'pending');
    expect(publicData.toString(), isNot(contains('/local')));
  });
  test('pending and verified requests cannot be overwritten by an owner', () async {
    for (final status in ['pending', 'verified']) {
      when(() => proof.data()).thenReturn({'status': status}); await expectLater(submit(), throwsA(isA<VerificationException>()));
    }
    verifyNever(() => transaction.set(private, any()));
  });
  test('public verified status also prevents an inconsistent resubmission', () async {
    when(() => profile.data()).thenReturn({'verification': {'status': 'verified'}});
    await expectLater(submit(), throwsA(isA<VerificationException>())); verifyNever(() => transaction.update(worker, any()));
  });
  test('a rejected request can be resubmitted without publishing the private note', () async {
    when(() => proof.data()).thenReturn({'status': 'rejected', 'note': 'Unreadable document'});
    await submit(); final data = verify(() => transaction.set(private, captureAny())).captured.single as Map;
    expect(data['status'], 'pending'); expect(data.containsKey('reviewedAt'), isFalse); expect(data.containsKey('note'), isFalse);
  });
  test('missing private record reads as not started, not an exception', () async { expect(await service.getVerification('w'), isNull); });
}
