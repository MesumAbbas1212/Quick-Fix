import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quickfix/models/app_release_config.dart';
import 'package:quickfix/services/preferences_service.dart';
import 'package:url_launcher/url_launcher.dart';

class AppReleaseService {
  // No package_info dependency. Release builds must pass the SAME numeric build
  // as pubspec/--build-number via --dart-define=APP_BUILD_NUMBER=<number>.
  static const currentBuildNumber = int.fromEnvironment('APP_BUILD_NUMBER', defaultValue: 1);
  final FirebaseFirestore? _injectedFirestore;
  final PreferencesService? _injectedPreferences;
  final Future<bool> Function(Uri)? _openUrl;
  final int currentBuild;
  AppReleaseService({FirebaseFirestore? firestore, PreferencesService? preferencesService,
    Future<bool> Function(Uri)? openUrl, this.currentBuild = currentBuildNumber})
      : _injectedFirestore = firestore, _injectedPreferences = preferencesService, _openUrl = openUrl;
  late final FirebaseFirestore _firestore = _injectedFirestore ?? FirebaseFirestore.instance;
  late final PreferencesService _preferences = _injectedPreferences ?? PreferencesService();

  Future<AppReleaseConfig?> fetchConfig() async {
    final data = (await _firestore.collection('config').doc('app').get()).data();
    return data == null ? null : AppReleaseConfig.fromMap(data);
  }
  Future<AppReleaseDecision> checkForUpdate() async {
    AppReleaseConfig? config;
    try { config = await fetchConfig().timeout(const Duration(seconds: 3)); }
    catch (_) { return AppReleaseDecision(currentBuild: currentBuild); }
    if (config == null) return AppReleaseDecision(currentBuild: currentBuild);
    int? previous;
    try {
      previous = await _preferences.lastSeenBuild().timeout(const Duration(seconds: 1));
      await _preferences.rememberBuild(currentBuild).timeout(const Duration(seconds: 1));
    } catch (_) { /* Local storage must not prevent launch or override minBuild. */ }
    // Never use max(previousBuild, installedBuild): downgrades still need gating.
    return AppReleaseDecision(config: config, currentBuild: currentBuild, previousBuild: previous);
  }
  Future<bool> openStore(String url) async {
    final uri = AppReleaseConfig.safeStoreUri(url);
    if (uri == null) throw StateError('The update link is not a supported HTTPS app-store link.');
    return await (_openUrl != null ? _openUrl!(uri) : launchUrl(uri, mode: LaunchMode.externalApplication))
      .timeout(const Duration(seconds: 8));
  }
}
