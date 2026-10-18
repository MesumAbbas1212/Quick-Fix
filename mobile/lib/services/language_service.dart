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
  bool? _usedFallback;
  /// Null before resolving a catalog, true only for the explicitly limited fallback.
  bool? get usedFallback => _usedFallback;

  LanguageService({FirebaseFirestore? firestore, http.Client? client})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _client = client ?? http.Client();

  /// True when a translation proxy is configured (dynamic backend list).
  bool get hasProxy => _proxyUrl.isNotEmpty;

  /// The last successfully resolved list, if any.
  List<AppLanguage>? get cached => _cached;

  /// Forgets the cached list so the next fetch re-reads the sources.
  void clearCache() { _cached = null; _usedFallback = null; }

  /// Returns the languages a user may pick the app language from,
  /// sorted by English name.
  Future<List<AppLanguage>> getAvailableLanguages() async {
    final cached = _cached;
    if (cached != null) return cached;

    final lookup = await _fetchCatalog();
    _usedFallback = lookup.languages.isEmpty;
    final languages = lookup.languages.isEmpty ? fallbackLanguages : lookup.languages;
    _cached = List<AppLanguage>.unmodifiable(languages);
    return _cached!;
  }

  /// Dynamic spoken-language choices. Unlike sign-up's last-resort fallback,
  /// a failed lookup is an error that the filter UI can retry; no fixed language
  /// list is presented as if it came from the backend.
  Future<List<AppLanguage>> getSpokenLanguages() async {
    final lookup = await _fetchCatalog();
    if (!lookup.loaded) throw StateError('Language catalog unavailable.');
    return List.unmodifiable(lookup.languages);
  }

  Future<_LanguageLookup> _fetchCatalog() async {
    final merged = <String, AppLanguage>{};
    final disabled = <String>{};
    var loaded = false;
    try {
      final snapshot = await _firestore.collection('languages').orderBy('englishName')
          .get().timeout(const Duration(seconds: 6));
      loaded = true;
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final language = AppLanguage.fromMap(data);
        if (language.code.isEmpty) continue;
        if (data['isActive'] == false) { disabled.add(language.code.toLowerCase()); continue; }
        merged[language.code.toLowerCase()] = language;
      }
    } catch (_) { /* The optional proxy may still supply real catalog data. */ }
    if (_proxyUrl.isNotEmpty) {
      try {
        final response = await _client.get(Uri.parse('$_proxyUrl/languages'))
            .timeout(const Duration(seconds: 6));
        if (response.statusCode == 200) {
          final body = jsonDecode(response.body);
          if (body is List) {
            loaded = true;
            for (final item in body) {
              if (item is! Map) continue;
              final code = (item['code'] ?? '').toString();
              if (code.isEmpty || disabled.contains(code.toLowerCase())) continue;
              merged.putIfAbsent(code.toLowerCase(), () => AppLanguage(code: code,
                nativeName: (item['nativeName'] ?? '').toString(),
                englishName: (item['englishName'] ?? '').toString()));
            }
          }
        }
      } catch (_) { /* Expose failure to strict callers if no source loaded. */ }
    }
    final languages = merged.values.toList()..sort((a, b) => a.englishName.compareTo(b.englishName));
    return _LanguageLookup(languages, loaded);
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

class _LanguageLookup {
  final List<AppLanguage> languages;
  final bool loaded;
  const _LanguageLookup(this.languages, this.loaded);
}
