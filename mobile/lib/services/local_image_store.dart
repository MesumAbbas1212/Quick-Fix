import 'dart:io';
import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

/// Stores job photos on the device itself (app documents directory) until
/// Firebase Storage (billing-gated) is enabled. Local paths are saved on the
/// job record in Firestore, so images render from local storage.
class LocalImageStore {
  static const _subDir = 'quickfix_job_images';
  static const _avatarSubDir = 'quickfix_avatars';

  const LocalImageStore();

  /// Copies a single picked avatar image into the app documents directory
  /// and returns its local path. Reused for profile pictures until Firebase
  /// Storage is enabled.
  Future<String> saveAvatar(XFile picked) async {
    final dir = await _avatarDir();
    final ext = _extensionOf(picked.path);
    final target = File('${dir.path}${Platform.pathSeparator}${DateTime.now().millisecondsSinceEpoch}$ext');
    await picked.saveTo(target.path);
    return target.path;
  }

  /// Copies the picked images into the app documents directory and returns
  /// the local file paths (absolute). Keeps original file names unique by
  /// prefixing a timestamp.
  Future<List<String>> saveImages(List<XFile> picked) async {
    final dir = await _imagesDir();
    final saved = <String>[];
    final now = DateTime.now().millisecondsSinceEpoch;

    for (var i = 0; i < picked.length; i++) {
      final ext = _extensionOf(picked[i].path);
      final target = File('${dir.path}${Platform.pathSeparator}${now}_$i$ext');
      await picked[i].saveTo(target.path);
      saved.add(target.path);
    }
    return saved;
  }

  /// Reads a saved local image as bytes, or null when missing.
  Future<Uint8List?> readImage(String path) async {
    final file = File(path);
    if (!await file.exists()) return null;
    return file.readAsBytes();
  }

  Future<Directory> _imagesDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}${Platform.pathSeparator}$_subDir');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<Directory> _avatarDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}${Platform.pathSeparator}$_avatarSubDir');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  String _extensionOf(String path) {
    final dot = path.lastIndexOf('.');
    if (dot == -1 || dot == path.length - 1) return '.jpg';
    final ext = path.substring(dot).toLowerCase();
    return ext.length <= 5 ? ext : '.jpg';
  }
}
