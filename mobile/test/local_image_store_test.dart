import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:quickfix/services/local_image_store.dart';

class _FakePathProvider extends PathProviderPlatform with MockPlatformInterfaceMixin {
  final Directory docsDir;

  _FakePathProvider(this.docsDir);

  @override
  Future<String?> getApplicationDocumentsPath() async => docsDir.path;
}

void main() {
  late Directory tmpDocs;

  setUp(() async {
    tmpDocs = await Directory.systemTemp.createTemp('quickfix_images_test');
    PathProviderPlatform.instance = _FakePathProvider(tmpDocs);
  });

  tearDown(() async {
    if (await tmpDocs.exists()) {
      await tmpDocs.delete(recursive: true);
    }
  });

  test('saveImages copies files into the app documents subdirectory', () async {
    final srcDir = await Directory.systemTemp.createTemp('quickfix_src');
    final src1 = File('${srcDir.path}${Platform.pathSeparator}photo1.png');
    final src2 = File('${srcDir.path}${Platform.pathSeparator}photo2.jpg');
    await src1.writeAsBytes([1, 2, 3]);
    await src2.writeAsBytes([4, 5, 6]);

    final store = LocalImageStore();
    final paths = await store.saveImages([XFile(src1.path), XFile(src2.path)]);

    expect(paths, hasLength(2));
    for (final p in paths) {
      expect(File(p).existsSync(), isTrue);
      expect(p.contains('quickfix_job_images'), isTrue);
    }
    expect(paths[0].endsWith('.png'), isTrue);
    expect(paths[1].endsWith('.jpg'), isTrue);

    await srcDir.delete(recursive: true);
  });

  test('readImage returns bytes for existing file and null for missing', () async {
    final srcDir = await Directory.systemTemp.createTemp('quickfix_src2');
    final src = File('${srcDir.path}${Platform.pathSeparator}photo.jpg');
    await src.writeAsBytes([10, 20, 30]);

    final store = LocalImageStore();
    final paths = await store.saveImages([XFile(src.path)]);

    final bytes = await store.readImage(paths.first);
    expect(bytes, [10, 20, 30]);

    expect(await store.readImage('${srcDir.path}${Platform.pathSeparator}nope.jpg'), isNull);
    await srcDir.delete(recursive: true);
  });

  test('saveAvatar stores single file in avatars subdirectory', () async {
    final srcDir = await Directory.systemTemp.createTemp('quickfix_src3');
    final src = File('${srcDir.path}${Platform.pathSeparator}avatar.png');
    await src.writeAsBytes([7, 8, 9]);

    final store = LocalImageStore();
    final path = await store.saveAvatar(XFile(src.path));

    expect(path.contains('quickfix_avatars'), isTrue);
    expect(path.endsWith('.png'), isTrue);
    expect(File(path).existsSync(), isTrue);

    final bytes = await store.readImage(path);
    expect(bytes, [7, 8, 9]);

    await srcDir.delete(recursive: true);
  });
  test('verification photos are namespaced and other accounts cannot read them', () async {
    final source = File('${tmpDocs.path}/capture.jpg'); await source.writeAsBytes([1, 2, 3]);
    final store = LocalImageStore();
    final path = await store.saveVerificationImage(uid: 'w1', kind: 'front', picked: XFile(source.path));
    expect(path, contains('quickfix_verification'));
    expect(await store.hasVerificationImage('w1', path), isTrue);
    expect(await store.readVerificationImage('w1', path), [1, 2, 3]);
    expect(await store.readVerificationImage('w2', path), isNull);
    expect(await store.readVerificationImage('w1', source.path), isNull);
  });
  test('UID traversal and symlink escapes never expose arbitrary files', () async {
    final source = File('${tmpDocs.path}/outside.jpg'); await source.writeAsBytes([9]);
    final store = LocalImageStore();
    final path = await store.saveVerificationImage(uid: '..', kind: 'front', picked: XFile(source.path));
    expect(path, contains('/quickfix_verification/'));
    final link = Link('${File(path).parent.path}/escape.jpg'); await link.create(source.path);
    expect(await store.readVerificationImage('..', link.path), isNull);
  });
  test('clearing verification removes only that account’s proof photos', () async {
    final source = File('${tmpDocs.path}/capture.jpg'); await source.writeAsBytes([7]);
    final store = LocalImageStore();
    final one = await store.saveVerificationImage(uid: 'w1', kind: 'front', picked: XFile(source.path));
    final two = await store.saveVerificationImage(uid: 'w2', kind: 'selfie', picked: XFile(source.path));
    await store.clearVerificationImages('w1'); expect(await File(one).exists(), isFalse); expect(await File(two).exists(), isTrue);
  });
  test('unknown verification photo kinds are rejected before copying', () async {
    await expectLater(LocalImageStore().saveVerificationImage(uid: 'w1', kind: '../escape', picked: XFile('unused')), throwsArgumentError);
  });

}
