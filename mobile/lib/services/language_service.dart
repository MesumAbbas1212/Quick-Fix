import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:quickfix/models/app_language.dart';

/// Resolves the list of languages the app can be shown in.
///
/// The list is intentionally NOT hard-coded in app code. Sources, in order:
///  1. The `languages` collection in Firestore — an admin-curated list
///     (populated by the seed script; admins can edit it at any time).
///  2. The translation proxy's `GET /languages` — the languages the backend
///     translation engine actually supports — merged in by code so the two
///     sources never disagree about availability.
///  3. A tiny last-resort fallback so sign-up still works when the device
///     is fully offline and nothing is cached.
class LanguageService {
  final FirebaseFirestore _firestore;
  final http.Client _client;

  static const String _proxyUrl =
      String.fromEnvironment('TRANSLATE_PROXY_URL');

  /// Last-resort list, used only when neither Firestore nor the proxy
  /// responds. It is a demo fallback, not the source of truth.
  static const List<AppLanguage> fallbackLanguages = [
    AppLanguage(code: 'en', nativeName: 'English', englishName: 'English'),
    AppLanguage(code: 'ur', nativeName: 'اردو', englishName: 'Urdu'),
  ];

  List<AppLanguage>? _cached;

  LanguageService({FirebaseFirestore? firestore, http.Client? client})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _client = client ?? http.Client();

  /// True when a translation proxy is configured (dynamic backend list).
  bool get hasProxy => _proxyUrl.isNotEmpty;

  /// The last successfully resolved list, if any.
  List<AppLanguage>? get cached => _cached;

  /// Forgets the cached list so the next fetch re-reads the sources.
  void clearCache() => _cached = null;

  /// Returns the languages a user may pick the app language from,
  /// sorted by English name.
  Future<List<AppLanguage>> getAvailableLanguages() async {
    final cached = _cached;
    if (cached != null) return cached;

    final merged = <String, AppLanguage>{};

    // 1) Curated Firestore list (wins on label conflicts).
    try {
      final snapshot = await _firestore
          .collection('languages')
          .orderBy('englishName')
          .get();
      for (final doc in snapshot.docs) {
        final lang = AppLanguage.fromMap(doc.data());
        if (lang.code.isNotEmpty) merged[lang.code] = lang;
      }
    } catch (_) {
      // Firestore unavailable — continue with proxy / fallback.
    }

    // 2) Translation proxy's supported languages (dynamic backend list).
    if (_proxyUrl.isNotEmpty) {
      try {
        final resp = await _client.get(Uri.parse('$_proxyUrl/languages'));
        if (resp.statusCode == 200) {
          final body = jsonDecode(resp.body);
          if (body is List) {
            for (final item in body) {
              if (item is! Map) continue;
              final code = (item['code'] ?? '').toString();
              if (code.isEmpty) continue;
              merged.putIfAbsent(code, () => AppLanguage(
                    code: code,
                    nativeName: (item['nativeName'] ?? '').toString(),
                    englishName: (item['englishName'] ?? '').toString(),
                  ));
            }
          }
        }
      } catch (_) {
        // Proxy unavailable — continue with whatever Firestore gave us.
      }
    }

    var languages = merged.values.toList()
      ..sort((a, b) => a.englishName.compareTo(b.englishName));
    if (languages.isEmpty) {
      languages = List<AppLanguage>.from(fallbackLanguages);
    }
    _cached = List<AppLanguage>.unmodifiable(languages);
    return _cached!;
  }

  /// Resolves a stored language code to its display name (for menus).
  /// Returns [fallbackName] when the code is unknown or lookups fail.
  Future<String> displayNameFor(
    String code, {
    String fallbackName = 'English',
  }) async {
    try {
      final languages = await getAvailableLanguages();
      for (final lang in languages) {
        if (lang.code == code) return lang.displayName;
      }
    } catch (_) {
      // fall through
    }
    return fallbackName;
  }
}
