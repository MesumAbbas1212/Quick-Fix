import 'dart:convert';
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
  static const _verificationSubDir = 'quickfix_verification';
  final Future<Directory> Function()? documentsDirectory;

  const LocalImageStore({this.documentsDirectory});
  Future<Directory> _documents() => (documentsDirectory ?? getApplicationDocumentsDirectory)();

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
    final docs = await _documents();
    final dir = Directory('${docs.path}${Platform.pathSeparator}$_subDir');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<Directory> _avatarDir() async {
    final docs = await _documents();
    final dir = Directory('${docs.path}${Platform.pathSeparator}$_avatarSubDir');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<Directory> _verificationDir(String uid) async {
    if (uid.isEmpty) throw ArgumentError('A signed-in account is required.');
    final docs = await _documents();
    final dir = Directory('${docs.path}${Platform.pathSeparator}$_verificationSubDir${Platform.pathSeparator}${base64Url.encode(utf8.encode(uid)).replaceAll('=', '')}');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<String> saveVerificationImage({required String uid, required String kind, required XFile picked}) async {
    if (!const {'front', 'back', 'selfie'}.contains(kind)) throw ArgumentError('Unknown verification photo.');
    final dir = await _verificationDir(uid);
    final path = '${dir.path}${Platform.pathSeparator}${kind}_${DateTime.now().microsecondsSinceEpoch}${_extensionOf(picked.path)}';
    await picked.saveTo(path);
    return path;
  }

  Future<bool> hasVerificationImage(String uid, String path) async {
    final dir = await _verificationDir(uid);
    // Never follow arbitrary Firestore paths or symlinks outside this account's directory.
    final file = File(path);
    if (!await file.exists()) return false;
    final resolved = await file.resolveSymbolicLinks();
    final root = await dir.resolveSymbolicLinks();
    return resolved.startsWith('$root${Platform.pathSeparator}');
  }
  Future<Uint8List?> readVerificationImage(String uid, String path) async =>
      await hasVerificationImage(uid, path) ? readImage(path) : null;

  Future<void> clearVerificationImages(String uid) async {
    final directory = await _verificationDir(uid);
    if (await directory.exists()) await directory.delete(recursive: true);
  }

  String _extensionOf(String path) {
    final dot = path.lastIndexOf('.');
    if (dot == -1 || dot == path.length - 1) return '.jpg';
    final ext = path.substring(dot).toLowerCase();
    return ext.length <= 5 ? ext : '.jpg';
  }
}
