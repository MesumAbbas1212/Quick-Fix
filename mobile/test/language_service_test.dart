// ignore_for_file: subtype_of_sealed_class
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:quickfix/models/app_language.dart';
import 'package:quickfix/services/language_service.dart';

class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}

class MockCollectionReference
    extends Mock implements CollectionReference<Map<String, dynamic>> {}

class MockQuery extends Mock implements Query<Map<String, dynamic>> {}

class MockQuerySnapshot
    extends Mock implements QuerySnapshot<Map<String, dynamic>> {}

class MockQueryDocSnapshot
    extends Mock implements QueryDocumentSnapshot<Map<String, dynamic>> {}

class MockHttpClient extends Mock implements http.Client {}

void main() {
  late MockFirebaseFirestore firestore;
  late MockCollectionReference collection;
  late MockQuery query;
  late MockQuerySnapshot snapshot;
  late MockHttpClient client;

  setUp(() {
    firestore = MockFirebaseFirestore();
    collection = MockCollectionReference();
    query = MockQuery();
    snapshot = MockQuerySnapshot();
    client = MockHttpClient();
    when(() => firestore.collection('languages')).thenReturn(collection);
    when(() => collection.orderBy('englishName')).thenReturn(query);
  });

  MockQueryDocSnapshot _docOf(AppLanguage lang) {
    final doc = MockQueryDocSnapshot();
    when(() => doc.data()).thenReturn(lang.toMap());
    return doc;
  }

  void mockFirestoreLanguages(List<AppLanguage> languages) {
    when(() => query.get()).thenAnswer((_) async => snapshot);
    when(() => snapshot.docs)
        .thenReturn(languages.map(_docOf).toList(growable: false));
  }

  group('LanguageService.getAvailableLanguages', () {
    test('returns the curated Firestore languages sorted by English name',
        () async {
      mockFirestoreLanguages([
        AppLanguage(code: 'ur', nativeName: 'اردو', englishName: 'Urdu'),
        AppLanguage(code: 'en', nativeName: 'English', englishName: 'English'),
        AppLanguage(code: 'fr', nativeName: 'Français', englishName: 'French'),
      ]);

      final service = LanguageService(firestore: firestore, client: client);
      final languages = await service.getAvailableLanguages();

      expect(languages.map((l) => l.code).toList(), ['en', 'fr', 'ur']);
      expect(languages.first.nativeName, 'English');
    });

    test('caches the first successful fetch', () async {
      mockFirestoreLanguages([
        AppLanguage(code: 'en', englishName: 'English'),
      ]);
      final service = LanguageService(firestore: firestore, client: client);

      await service.getAvailableLanguages();

      // A later failing fetch must not change the cached result.
      when(() => query.get()).thenThrow(Exception('offline'));
      final again = await service.getAvailableLanguages();

      expect(again.map((l) => l.code).toList(), ['en']);
      expect(service.cached, isNotNull);
    });

    test('clearCache forces a re-fetch', () async {
      mockFirestoreLanguages([
        AppLanguage(code: 'en', englishName: 'English'),
      ]);
      final service = LanguageService(firestore: firestore, client: client);
      await service.getAvailableLanguages();

      service.clearCache();
      mockFirestoreLanguages([
        AppLanguage(code: 'en', englishName: 'English'),
        AppLanguage(code: 'ar', nativeName: 'العربية', englishName: 'Arabic'),
      ]);

      final languages = await service.getAvailableLanguages();
      expect(languages.map((l) => l.code).toList(), contains('ar'));
    });

    test('falls back to the built-in list when Firestore is unreachable',
        () async {
      when(() => query.get()).thenThrow(Exception('offline'));
      final service = LanguageService(firestore: firestore, client: client);

      final languages = await service.getAvailableLanguages();

      // Last-resort list must include English so sign-up is never blank.
      expect(languages.any((l) => l.code == 'en'), isTrue);
      expect(languages.any((l) => l.code == 'ur'), isTrue);
    });

    test('ignores documents with an empty code', () async {
      final emptyDoc = MockQueryDocSnapshot();
      when(() => emptyDoc.data()).thenReturn({
        'code': '',
        'nativeName': '',
        'englishName': '',
      });
      when(() => query.get()).thenAnswer((_) async => snapshot);
      when(() => snapshot.docs).thenReturn([emptyDoc]);

      final service = LanguageService(firestore: firestore, client: client);
      final languages = await service.getAvailableLanguages();

      // Empty Firestore result falls back to the built-in list.
      expect(languages.any((l) => l.code.isEmpty), isFalse);
    });
  });

  group('LanguageService.displayNameFor', () {
    test('resolves a known code to its display name', () async {
      mockFirestoreLanguages([
        AppLanguage(code: 'ur', nativeName: 'اردو', englishName: 'Urdu'),
      ]);
      final service = LanguageService(firestore: firestore, client: client);

      expect(await service.displayNameFor('ur'), 'اردو');
    });

    test('returns the fallback name for unknown codes', () async {
      mockFirestoreLanguages([
        AppLanguage(code: 'en', nativeName: 'English', englishName: 'English'),
      ]);
      final service = LanguageService(firestore: firestore, client: client);

      expect(await service.displayNameFor('zz', fallbackName: 'Fallback'),
          'Fallback');
    });
  });
}
