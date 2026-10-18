import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quickfix/models/app_release_config.dart';
import 'package:quickfix/services/app_release_service.dart';
import 'package:quickfix/services/preferences_service.dart';

class MockPreferences extends Mock implements PreferencesService {}
class _ConfigService extends AppReleaseService {
  final AppReleaseConfig? value;
  final bool fail;
  _ConfigService(this.value, {required super.preferencesService, super.currentBuild, this.fail = false});
  @override
  Future<AppReleaseConfig?> fetchConfig() async { if (fail) throw StateError('offline'); return value; }
}
const _url = 'https://play.google.com/store/apps/details?id=pk.quickfix.app';
const _config = AppReleaseConfig(minBuild: 2, latestBuild: 5, message: 'A safer release is ready.', storeUrl: _url);
void main() {
  late MockPreferences preferences;
  setUp(() { preferences = MockPreferences();
    when(() => preferences.lastSeenBuild()).thenAnswer((_) async => null);
    when(() => preferences.rememberBuild(any())).thenAnswer((_) async {});
  });
  test('only the installed build below minBuild hard-blocks', () async {
    final result = await _ConfigService(_config, preferencesService: preferences, currentBuild: 1).checkForUpdate();
    expect(result.requiresUpdate, isTrue); expect(result.hasSoftUpdate, isFalse);
    verify(() => preferences.rememberBuild(1)).called(1);
  });
  test('latestBuild is non-blocking at and above the minimum', () async {
    final result = await _ConfigService(_config, preferencesService: preferences, currentBuild: 2).checkForUpdate();
    expect(result.requiresUpdate, isFalse); expect(result.hasSoftUpdate, isTrue);
    final latest = await _ConfigService(_config, preferencesService: preferences, currentBuild: 5).checkForUpdate();
    expect(latest.hasSoftUpdate, isFalse);
  });
  test('a remembered newer build cannot bypass the minimum after downgrade', () async {
    when(() => preferences.lastSeenBuild()).thenAnswer((_) async => 99);
    final result = await _ConfigService(_config, preferencesService: preferences, currentBuild: 1).checkForUpdate();
    expect(result.previousBuild, 99); expect(result.requiresUpdate, isTrue);
  });
  test('missing and failed config fail open', () async {
    for (final service in [_ConfigService(null, preferencesService: preferences), _ConfigService(_config, preferencesService: preferences, fail: true)]) {
      expect((await service.checkForUpdate()).requiresUpdate, isFalse);
    }
    verifyNever(() => preferences.lastSeenBuild());
  });
  test('preferences failure cannot override a valid minimum', () async {
    when(() => preferences.lastSeenBuild()).thenThrow(StateError('disk'));
    expect((await _ConfigService(_config, preferencesService: preferences, currentBuild: 1).checkForUpdate()).requiresUpdate, isTrue);
  });
  test('parses integral numeric builds and defaults a missing message', () {
    final config = AppReleaseConfig.fromMap({'minBuild': 2.0, 'latestBuild': 3, 'storeUrl': _url});
    expect(config?.minBuild, 2); expect(config?.message, isNotEmpty);
  });
  test('invalid config is not a launch blocker', () {
    for (final map in <Map<String, dynamic>>[
      {}, {'minBuild': -1, 'latestBuild': 2, 'storeUrl': _url},
      {'minBuild': 2.5, 'latestBuild': 3, 'storeUrl': _url},
      {'minBuild': 3, 'latestBuild': 2, 'storeUrl': _url},
      {'minBuild': 1, 'latestBuild': '2', 'storeUrl': _url},
      {'minBuild': 1, 'latestBuild': 2, 'storeUrl': 'javascript:alert(1)'},
    ]) { expect(AppReleaseConfig.fromMap(map), isNull); }
  });
  test('store URLs reject arbitrary hosts, credentials and insecure schemes', () {
    for (final url in ['http://play.google.com/store/apps/details?id=x', 'https://play.google.com.evil.test/store/apps/details?id=x',
      'https://name@play.google.com/store/apps/details?id=x', 'https://play.google.com:444/store/apps/details?id=x', 'https://play.google.com/']) {
      expect(AppReleaseConfig.safeStoreUri(url), isNull);
    }
    expect(AppReleaseConfig.safeStoreUri('https://apps.apple.com/pk/app/quickfix/id12345'), isNotNull);
  });
  test('awaits and returns a failed launcher result', () async {
    Uri? opened;
    final service = AppReleaseService(openUrl: (uri) async { opened = uri; return false; });
    expect(await service.openStore(_url), isFalse); expect(opened?.host, 'play.google.com');
  });
  test('invalid links never reach the launcher', () async {
    var opened = false;
    final service = AppReleaseService(openUrl: (_) async { opened = true; return true; });
    await expectLater(service.openStore('file:///private'), throwsStateError); expect(opened, isFalse);
  });
}
