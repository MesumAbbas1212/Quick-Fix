import 'package:shared_preferences/shared_preferences.dart';

/// Local preferences only. No authentication data or verification images.
class PreferencesService {
  final Future<SharedPreferences> Function()? _loader;
  PreferencesService({Future<SharedPreferences> Function()? loader}) : _loader = loader;
  Future<SharedPreferences> _preferences() => (_loader ?? SharedPreferences.getInstance)();

  Future<bool> hasSeenOnboarding() async => (await _preferences()).getBool('onboarding_seen') ?? false;
  Future<void> markOnboardingSeen() async {
    if (!await (await _preferences()).setBool('onboarding_seen', true)) throw StateError('Preferences were not saved.');
  }
  Future<int?> lastSeenBuild() async => (await _preferences()).getInt('last_seen_build');
  Future<void> rememberBuild(int build) async {
    if (!await (await _preferences()).setInt('last_seen_build', build)) throw StateError('Build preference was not saved.');
  }
  Future<void> clearAccountCache() async {
    final preferences = await _preferences();
    // Device-wide onboarding/build flags are deliberately retained.
    for (final key in ['cached_jobs', 'cached_categories']) {
      if (!await preferences.remove(key)) throw StateError('Cached app data could not be removed.');
    }
  }
}
