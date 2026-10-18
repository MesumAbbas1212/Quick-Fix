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
    if (path.isEmpty) return null;
    try {
      final file = File(path);
      if (!await file.exists()) return null;
      final resolved = await file.resolveSymbolicLinks();
      final docs = await _documents();
      final documentsRoot = await docs.resolveSymbolicLinks();
      var allowed = false;
      for (final name in [_subDir, _avatarSubDir]) {
        final directory = Directory('$documentsRoot${Platform.pathSeparator}$name');
        if (await directory.exists()) {
          final root = await directory.resolveSymbolicLinks();
          if (root == directory.path && resolved.startsWith('$root${Platform.pathSeparator}')) allowed = true;
        }
      }
      // Public avatar/job references must never become a bypass for the
      // account-private verification reader, including traversal/symlinks.
      final proof = Directory('${docs.path}${Platform.pathSeparator}$_verificationSubDir');
      if (await proof.exists() && resolved.startsWith('${await proof.resolveSymbolicLinks()}${Platform.pathSeparator}')) return null;
      if (!allowed) return null;
      return await file.readAsBytes();
    } catch (_) { return null; }
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
    if (!await docs.exists()) await docs.create(recursive: true);
    final documentsRoot = await docs.resolveSymbolicLinks();
    final root = Directory('$documentsRoot${Platform.pathSeparator}$_verificationSubDir');
    if (await FileSystemEntity.isLink(root.path)) throw StateError('Verification directory must not be a symlink.');
    if (!await root.exists()) await root.create(recursive: true);
    final encodedUid = base64Url.encode(utf8.encode(uid)).replaceAll('=', '');
    final dir = Directory('${root.path}${Platform.pathSeparator}$encodedUid');
    if (await FileSystemEntity.isLink(dir.path)) throw StateError('Account verification directory must not be a symlink.');
    if (!await dir.exists()) await dir.create(recursive: true);
    if (await dir.resolveSymbolicLinks() != dir.path) throw StateError('Verification directory escaped its account.');
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
  Future<Uint8List?> readVerificationImage(String uid, String path) async {
    try {
      if (!await hasVerificationImage(uid, path)) return null;
      // Deliberately not readImage(): public avatar/job readers reject proof.
      final resolved = await File(path).resolveSymbolicLinks();
      return await File(resolved).readAsBytes();
    } catch (_) { return null; }
  }

  Future<void> clearVerificationImages(String uid) async {
    final directory = await _verificationDir(uid);
    if (await directory.exists()) await directory.delete(recursive: true);
  }

  /// Legacy job/avatar caches are app-wide (not UID-namespaced). Clearing them
  /// never deletes camera/gallery originals or another UID's verification folder.
  Future<void> clearAccountImages(String uid) async {
    final docs = await _documents();
    for (final name in [_subDir, _avatarSubDir]) {
      final directory = Directory('${docs.path}${Platform.pathSeparator}$name');
      if (await directory.exists()) await directory.delete(recursive: true);
    }
    await clearVerificationImages(uid);
  }

  String _extensionOf(String path) {
    final dot = path.lastIndexOf('.');
    if (dot == -1 || dot == path.length - 1) return '.jpg';
    final ext = path.substring(dot).toLowerCase();
    return ext.length <= 5 ? ext : '.jpg';
  }
}
