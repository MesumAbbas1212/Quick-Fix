import 'package:flutter_test/flutter_test.dart';
import 'package:quickfix/models/app_language.dart';

void main() {
  group('AppLanguage', () {
    test('fromMap reads code and names', () {
      final lang = AppLanguage.fromMap({
        'code': 'ur',
        'nativeName': 'اردو',
        'englishName': 'Urdu',
      });
      expect(lang.code, 'ur');
      expect(lang.nativeName, 'اردو');
      expect(lang.englishName, 'Urdu');
      expect(lang.displayName, 'اردو');
    });

    test('toMap round-trips through fromMap', () {
      final lang =
          AppLanguage(code: 'fr', nativeName: 'Français', englishName: 'French');
      final back = AppLanguage.fromMap(lang.toMap());
      expect(back, lang);
      expect(back.code, 'fr');
      expect(back.nativeName, 'Français');
      expect(back.englishName, 'French');
    });

    test('equality is by code', () {
      expect(
        AppLanguage(code: 'en', englishName: 'English'),
        AppLanguage(code: 'en', englishName: 'English'),
      );
      expect(
        AppLanguage(code: 'en', englishName: 'English') ==
            AppLanguage(code: 'ur', englishName: 'Urdu'),
        isFalse,
      );
    });

    test('displayName falls back to englishName then code', () {
      expect(
        AppLanguage(code: 'en', nativeName: '', englishName: 'English')
            .displayName,
        'English',
      );
      expect(
        AppLanguage(code: 'en', nativeName: '', englishName: '').displayName,
        'en',
      );
    });

    test('fromMap tolerates missing fields', () {
      final lang = AppLanguage.fromMap({});
      expect(lang.code, isEmpty);
      expect(lang.nativeName, isEmpty);
      expect(lang.englishName, isEmpty);
    });
  });
}
