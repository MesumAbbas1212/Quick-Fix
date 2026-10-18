import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
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
  test('English input is sent to ML for the chosen non-English target', () async {
    Map<String, dynamic>? request;
    final client = MockClient((req) async {
      request = jsonDecode(req.body) as Map<String, dynamic>;
      return http.Response(jsonEncode({'translated': 'کارکن وقت پر آیا۔'}), 200, headers: {'content-type': 'application/json; charset=utf-8'});
    });
    final translator = TranslationService(client: client, proxyUrl: 'https://translation.test/translate');
    expect(await translator.translate('The worker arrived on time.', 'ur'), 'کارکن وقت پر آیا۔');
    expect(request?['target'], 'ur'); expect(request?['q'], 'The worker arrived on time.');
  });
  test('ASCII is not treated as proof of English or a no-op target', () async {
    var calls = 0;
    final translator = TranslationService(proxyUrl: 'https://translation.test/translate', client: MockClient((req) async {
      calls++; return http.Response('{"translated":"Good work"}', 200);
    }));
    expect(await translator.translate('Bon travail', 'en'), 'Good work'); expect(calls, 1);
  });
  test('server errors and malformed results preserve the original honestly', () async {
    for (final response in [http.Response('unavailable', 503), http.Response('bad-json', 200), http.Response('{"translated":""}', 200)]) {
      final translator = TranslationService(proxyUrl: 'https://translation.test/translate', client: MockClient((_) async => response));
      expect(await translator.translate('Good work', 'ur'), 'Good work');
    }
  });
  test('transport exceptions preserve the original instead of throwing into submit', () async {
    final translator = TranslationService(proxyUrl: 'https://translation.test/translate', client: MockClient((_) async => throw Exception('network')));
    expect(await translator.translate('Good work', 'bft'), 'Good work');
  });

}