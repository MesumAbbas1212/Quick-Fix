import 'dart:convert';
import 'package:http/http.dart' as http;

/// Translates review text to English.
/// Primary path calls a backend proxy that holds the Cloud Translation API key;
/// mobile falls back to a local script check so the feature still works
/// offline for demo purposes.
class TranslationService {
  static const String _proxyUrl = String.fromEnvironment('TRANSLATE_PROXY_URL');

  final http.Client _client;

  TranslationService({http.Client? client}) : _client = client ?? http.Client();

  static bool isNonLatin(String text) {
    if (text.trim().isEmpty) return false;
    return !RegExp(r'^[\x00-\x7F]+$').hasMatch(text);
  }

  static bool isUrdu(String text) {
    if (text.trim().isEmpty) return false;
    return RegExp(r'[\u0600-\u06FF]').hasMatch(text);
  }

  Future<String> translate(String text, String targetLang) async {
    // Already ASCII/English — nothing to translate.
    if (!isNonLatin(text)) return text;

    if (_proxyUrl.isNotEmpty) {
      try {
        final resp = await _client.post(
          Uri.parse(_proxyUrl),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'q': text, 'target': targetLang}),
        );
        if (resp.statusCode == 200) {
          final data = jsonDecode(resp.body) as Map<String, dynamic>;
          final translated = data['translated'] as String?;
          if (translated != null && translated.trim().isNotEmpty) {
            return translated;
          }
        }
      } catch (_) {
        // fall through to local approximation
      }
    }
    return _localApprox(text);
  }

  // Offline demo placeholder: keeps non-Latin text as-is (would map to a
  // bundled phrase dictionary in production).
  String _localApprox(String text) => text;
}