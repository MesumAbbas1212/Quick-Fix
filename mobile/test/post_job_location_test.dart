import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:quickfix/services/location_provider.dart';
import 'package:quickfix/services/location_service.dart';
import 'package:quickfix/views/jobs/post_job_screen.dart';

final Uint8List _tinyPng = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89,
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x44, 0x41, 0x54,
  0x78, 0x9C, 0x62, 0x00, 0x01, 0x00, 0x00, 0x05, 0x00, 0x01,
  0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00,
  0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

class _DeniedProvider implements LocationProvider {
  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.denied;

  @override
  Future<LocationPermission> requestPermission() async =>
      LocationPermission.denied;

  @override
  Future<Position> getCurrentPosition() async => throw UnimplementedError();
}

void main() {
  late Directory tempDir;
  late String pngPath;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('qfix_postjob');
    pngPath = '${tempDir.path}${Platform.pathSeparator}pic.png';
    File(pngPath).writeAsBytesSync(_tinyPng);
  });

  tearDown(() => tempDir.deleteSync(recursive: true));

  testWidgets('posting blocked with snackbar when location permission denied',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: PostJobScreen(
              userId: 'user-1',
              locationService: LocationService(provider: _DeniedProvider()),
              prefilledImages: [XFile(pngPath)],
            ),
          ),
        ),
      ),
    );

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Leaky faucet needs fixing');
    await tester.enterText(fields.at(1), 'Model Town, Lahore');
    await tester.enterText(fields.at(2), '2500');

    await tester.ensureVisible(find.text('Post Job'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Post Job'));
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.textContaining('Location permission is required'), findsOneWidget);
  });
}
