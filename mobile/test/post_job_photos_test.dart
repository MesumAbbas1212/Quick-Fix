import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quickfix/views/jobs/post_job_screen.dart';

class _Picker extends Mock implements ImagePicker {}

/// 1x1 transparent PNG (valid image data).
final Uint8List _tinyPng = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
  0x89, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x44, 0x41,
  0x54, 0x78, 0x9C, 0x62, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
  0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
  0x42, 0x60, 0x82,
]);

List<String> _stripOrder(WidgetTester tester) {
  final images = tester.widgetList<Image>(
    find.descendant(
      of: find.byKey(const Key('post-job-photo-strip')),
      matching: find.byType(Image),
    ),
  );
  return [
    for (final image in images)
      if (image.image is FileImage) (image.image as FileImage).file.path,
  ];
}

void main() {
  late Directory tempDir;
  late List<String> paths;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('qfix_photos');
    paths = [];
    for (var i = 0; i < 3; i++) {
      final path = '${tempDir.path}${Platform.pathSeparator}photo$i.png';
      File(path).writeAsBytesSync(_tinyPng);
      paths.add(path);
    }
  });

  tearDown(() => tempDir.deleteSync(recursive: true));

  Future<void> pumpScreen(WidgetTester tester, {int picked = 3}) async {
    tester.view.physicalSize = const Size(1000, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final picker = _Picker();
    when(() => picker.pickMultiImage()).thenAnswer(
      (_) async => paths.take(picked).map((path) => XFile(path)).toList(),
    );

    await tester.pumpWidget(
      MaterialApp(home: PostJobScreen(userId: 'u1', imagePicker: picker)),
    );
    await tester.pump();
  }

  Future<void> addPhotos(WidgetTester tester) async {
    await tester.tap(find.text('Add Photos'));
    await tester.pump();
    await tester.pump();
  }

  testWidgets('three picks show a counter, a preview and a removable strip',
      (tester) async {
    await pumpScreen(tester);
    await addPhotos(tester);

    expect(find.text('3 of 5 photos'), findsOneWidget);
    expect(find.byKey(const Key('post-job-photo-strip')), findsOneWidget);
    expect(find.byKey(const Key('post-job-remove-photo-0')), findsOneWidget);
    expect(find.byKey(const Key('post-job-remove-photo-2')), findsOneWidget);
    expect(_stripOrder(tester), paths);
    // The placeholder is gone once photos exist.
    expect(find.text('Add Photos'), findsNothing);
  });

  testWidgets('removing the middle photo keeps the other two in order', (
    tester,
  ) async {
    await pumpScreen(tester);
    await addPhotos(tester);

    await tester.tap(find.byKey(const Key('post-job-remove-photo-1')));
    await tester.pump();

    expect(find.text('2 of 5 photos'), findsOneWidget);
    expect(_stripOrder(tester), [paths[0], paths[2]]);
    expect(find.byKey(const Key('post-job-remove-photo-2')), findsNothing);
  });

  testWidgets('removing every photo returns to the empty placeholder', (
    tester,
  ) async {
    await pumpScreen(tester);
    await addPhotos(tester);

    for (var remaining = 3; remaining > 0; remaining--) {
      // Always remove the first row: the badge keys are re-indexed.
      await tester.tap(find.byKey(const Key('post-job-remove-photo-0')));
      await tester.pump();
    }

    expect(find.text('Add Photos'), findsOneWidget);
    expect(find.byKey(const Key('post-job-photo-strip')), findsNothing);
    expect(find.byKey(const Key('post-job-photo-counter')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('prefilled photos cannot be removed', (tester) async {
    tester.view.physicalSize = const Size(1000, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: PostJobScreen(
          userId: 'u1',
          prefilledImages: [XFile(paths[0])],
        ),
      ),
    );
    await tester.pump();

    expect(find.text('1 of 5 photos'), findsOneWidget);
    expect(find.byKey(const Key('post-job-photo-0')), findsOneWidget);
    expect(find.byKey(const Key('post-job-remove-photo-0')), findsNothing);
  });
}
