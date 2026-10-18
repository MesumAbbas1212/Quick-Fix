import 'dart:convert';
import 'package:http/http.dart' as http;

/// Machine translation through the configured backend proxy. Credentials stay
/// server-side. An unavailable proxy returns the original, never a dictionary
/// approximation; callers must not label that fallback as a translation.
class TranslationService {
  static const String _proxyUrl = String.fromEnvironment('TRANSLATE_PROXY_URL');

  final http.Client _client;
  final String _endpoint;

  TranslationService({http.Client? client, String? proxyUrl})
      : _client = client ?? http.Client(), _endpoint = proxyUrl ?? _proxyUrl;

  static bool isNonLatin(String text) {
    if (text.trim().isEmpty) return false;
    return !RegExp(r'^[\x00-\x7F]+$').hasMatch(text);
  }

  static bool isUrdu(String text) {
    if (text.trim().isEmpty) return false;
    return RegExp(r'[\u0600-\u06FF]').hasMatch(text);
  }

  /// Heuristic: whether a BCP-47 language code belongs to a non-Latin
  /// script. Used to infer a review's original language from the
  /// reviewer's app language without full text analysis.
  static bool isNonLatinCode(String code) {
    switch (code) {
      case 'ur':
      case 'ar':
      case 'fa':
      case 'ps':
      case 'sd':
      case 'he':
      case 'hi':
      case 'bn':
      case 'ta':
      case 'te':
      case 'ml':
      case 'th':
      case 'el':
      case 'ru':
      case 'uk':
      case 'sr':
      case 'ka':
      case 'mn':
      case 'zh':
      case 'ja':
      case 'ko':
      case 'yi':
      case 'am':
      case 'hy':
        return true;
      default:
        return false;
    }
  }

  Future<String> translate(String text, String targetLang) async {
    if (text.trim().isEmpty) return text;
    // ASCII is not proof of English (or proof that targetLang is English).
    // Let the ML backend detect the source and honor the selected target.
    if (_endpoint.isNotEmpty) {
      try {
        // Hard timeout: an unreachable proxy must never hang the UI.
        final resp = await _client
            .post(
              Uri.parse(_endpoint),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'q': text, 'target': targetLang}),
            )
            .timeout(const Duration(seconds: 8));
        if (resp.statusCode == 200) {
          final data = jsonDecode(resp.body) as Map<String, dynamic>;
          final translated = data['translated'] as String?;
          if (translated != null && translated.trim().isNotEmpty) {
            return translated;
          }
        }
      } catch (_) {
        // The original text remains readable when ML translation is unavailable.
      }
    }
    return text;
  }
}
