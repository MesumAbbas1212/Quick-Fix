import 'package:flutter_test/flutter_test.dart';
import 'package:quickfix/services/translation_service.dart';

void main() {
  test('isNonLatin detects Urdu script', () {
    expect(TranslationService.isNonLatin('بہت اچھا کام'), isTrue);
    expect(TranslationService.isNonLatin('great work'), isFalse);
    expect(TranslationService.isNonLatin(''), isFalse);
  });

  test('isUrdu detects Urdu characters', () {
    expect(TranslationService.isUrdu('بہت اچھا'), isTrue);
    expect(TranslationService.isUrdu('great work'), isFalse);
  });

  test('local fallback passes through English text', () async {
    final t = TranslationService();
    expect(await t.translate('great work', 'en'), 'great work');
  });

  test('local fallback keeps non-Latin text when no proxy configured',
      () async {
    final t = TranslationService();
    final result = await t.translate('بہت اچھا کام', 'en');
    expect(result, 'بہت اچھا کام');
  });

  test('translate returns text unchanged for empty input', () async {
    final t = TranslationService();
    expect(await t.translate('', 'en'), '');
  });
}