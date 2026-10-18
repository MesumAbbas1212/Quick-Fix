import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quickfix/models/user_model.dart';
import 'package:quickfix/models/worker_verification.dart';
import 'package:quickfix/services/local_image_store.dart';
import 'package:quickfix/services/verification_service.dart';
import 'package:quickfix/views/worker/verification_screen.dart';
class MockVerification extends Mock implements VerificationService {}
class MockImages extends Mock implements LocalImageStore {}
class MockPicker extends Mock implements ImagePicker {}
void main() {
  late MockVerification service; late MockImages images; late MockPicker picker;
  final user = UserModel(uid: 'w', fullName: 'Worker', email: 'w@example.com', phone: '', role: UserRole.worker, createdAt: DateTime(2026), updatedAt: DateTime(2026));
  final Uint8List png = base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jM1sAAAAASUVORK5CYII=');
  setUpAll(() { registerFallbackValue(ImageSource.camera); registerFallbackValue(CameraDevice.rear); registerFallbackValue(XFile('/picked/photo.jpg')); });
  setUp(() {
    service = MockVerification(); images = MockImages(); picker = MockPicker();
    when(() => service.getVerification('w')).thenAnswer((_) async => null);
    when(() => images.readVerificationImage('w', any())).thenAnswer((_) async => png);
    when(() => picker.pickImage(source: any(named: 'source'), preferredCameraDevice: any(named: 'preferredCameraDevice'),
      maxWidth: any(named: 'maxWidth'), imageQuality: any(named: 'imageQuality'))).thenAnswer((_) async => XFile('/picked/photo.jpg'));
    when(() => images.saveVerificationImage(uid: 'w', kind: any(named: 'kind'), picked: any(named: 'picked')))
      .thenAnswer((invocation) async => '/local/${invocation.namedArguments[#kind]}.jpg');
    when(() => service.submit(uid: 'w', cnicFrontPath: any(named: 'cnicFrontPath'), cnicBackPath: any(named: 'cnicBackPath'),
      selfiePath: any(named: 'selfiePath'), consent: true)).thenAnswer((_) async {});
  });
  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(600, 1200); tester.view.devicePixelRatio = 1; addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: VerificationScreen(user: user, verificationService: service, imageStore: images, imagePicker: picker)));
    await tester.pumpAndSettle();
  }
  Future<void> tap(WidgetTester tester, String key) async {
    await tester.scrollUntilVisible(find.byKey(Key(key)), 200, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.byKey(Key(key))); await tester.pumpAndSettle();
  }
  testWidgets('not-started state explains privacy and requires all photos plus consent', (tester) async {
    await pump(tester); expect(find.text('Not started'), findsOneWidget);
    expect(find.textContaining('Photos stay in this device'), findsOneWidget);
    await tester.scrollUntilVisible(find.byKey(const Key('verification-submit')), 200, scrollable: find.byType(Scrollable).first);
    expect(tester.widget<ElevatedButton>(find.byKey(const Key('verification-submit'))).onPressed, isNull);
    verifyNever(() => service.submit(uid: 'w', cnicFrontPath: any(named: 'cnicFrontPath'), cnicBackPath: any(named: 'cnicBackPath'), selfiePath: any(named: 'selfiePath'), consent: true));
  });
  testWidgets('three captures are copied locally and consent permits a pending submission', (tester) async {
    await pump(tester);
    for (final kind in ['front', 'back', 'selfie']) { await tap(tester, 'verification-$kind'); }
    await tap(tester, 'verification-consent');
    when(() => service.submit(uid: 'w', cnicFrontPath: '/local/front.jpg', cnicBackPath: '/local/back.jpg', selfiePath: '/local/selfie.jpg', consent: true)).thenAnswer((_) async {
      when(() => service.getVerification('w')).thenAnswer((_) async => const WorkerVerification(status: VerificationStatus.pending));
    });
    await tap(tester, 'verification-submit'); expect(find.text('Pending'), findsOneWidget);
    verify(() => service.submit(uid: 'w', cnicFrontPath: '/local/front.jpg', cnicBackPath: '/local/back.jpg', selfiePath: '/local/selfie.jpg', consent: true)).called(1);
  });
  testWidgets('pending and verified states do not offer resubmission', (tester) async {
    when(() => service.getVerification('w')).thenAnswer((_) async => const WorkerVerification(status: VerificationStatus.pending));
    await pump(tester); expect(find.text('Pending'), findsOneWidget); expect(find.byKey(const Key('verification-submit')), findsNothing);
    when(() => service.getVerification('w')).thenAnswer((_) async => const WorkerVerification(status: VerificationStatus.verified));
    await tester.tap(find.byKey(const Key('verification-refresh'))); await tester.pumpAndSettle();
    expect(find.text('Verified'), findsOneWidget); expect(find.byKey(const Key('verification-submit')), findsNothing);
  });
  testWidgets('a rejected request displays the private reason and a resubmit action', (tester) async {
    when(() => service.getVerification('w')).thenAnswer((_) async => const WorkerVerification(status: VerificationStatus.rejected, note: 'Capture a readable CNIC front.'));
    await pump(tester); expect(find.text('Rejected'), findsOneWidget); expect(find.text('Capture a readable CNIC front.'), findsOneWidget);
    await tester.scrollUntilVisible(find.byKey(const Key('verification-submit')), 200, scrollable: find.byType(Scrollable).first);
    expect(find.text('Resubmit for verification'), findsOneWidget);
  });
  testWidgets('read errors provide an actual retry', (tester) async {
    when(() => service.getVerification('w')).thenThrow(StateError('offline'));
    await pump(tester); expect(find.textContaining('Could not load your verification.'), findsOneWidget);
    when(() => service.getVerification('w')).thenAnswer((_) async => null);
    await tester.tap(find.byKey(const Key('error-retry-button'))); await tester.pumpAndSettle(); expect(find.text('Not started'), findsOneWidget);
  });
  testWidgets('capture errors are visible and do not fabricate a saved photo', (tester) async {
    when(() => images.saveVerificationImage(uid: 'w', kind: any(named: 'kind'), picked: any(named: 'picked'))).thenThrow(StateError('disk full'));
    await pump(tester); await tap(tester, 'verification-front');
    await tester.scrollUntilVisible(find.byKey(const Key('verification-submit')), 200, scrollable: find.byType(Scrollable).first);
    expect(find.textContaining('Could not capture this photo.'), findsOneWidget);
    expect(tester.widget<ElevatedButton>(find.byKey(const Key('verification-submit'))).onPressed, isNull);
  });
}
