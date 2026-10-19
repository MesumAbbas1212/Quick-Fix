import 'package:flutter/services.dart';
import 'package:quickfix/services/map_launcher.dart';

class SupportService {
  final String email;
  final UrlLauncher _launcher;
  final Future<void> Function(String)? _copy;
  SupportService({String? supportEmail, UrlLauncher? urlLauncher, Future<void> Function(String)? copyContact})
      : email = (supportEmail ?? const String.fromEnvironment('SUPPORT_EMAIL')).trim(),
        _launcher = urlLauncher ?? const MapLauncher(), _copy = copyContact;
  bool get isConfigured => RegExp(r'^[A-Za-z0-9.!#$%&\x27*+/=?^_`{|}~-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$').hasMatch(email);
  Future<bool> contact() async {
    if (!isConfigured) throw StateError('Support contact is not configured.');
    final uri = Uri(scheme: 'mailto', path: email, queryParameters: {'subject': 'QuickFix support',
      'body': 'Describe the issue. Do not include passwords, CNIC photos, banking secrets or precise home locations.'});
    return await _launcher.open(uri.toString()).timeout(const Duration(seconds: 8));
  }
  Future<void> copyContact() async {
    if (!isConfigured) throw StateError('No configured contact.');
    await (_copy != null ? _copy(email) : Clipboard.setData(ClipboardData(text: email))).timeout(const Duration(seconds: 5));
  }
}
