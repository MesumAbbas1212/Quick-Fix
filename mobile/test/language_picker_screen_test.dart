import 'helpers/visible.dart' as test_viewport;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quickfix/core/widgets/loading_list.dart';
import 'package:quickfix/models/app_language.dart';
import 'package:quickfix/models/user_model.dart';
import 'package:quickfix/services/auth_service.dart';
import 'package:quickfix/services/language_service.dart';
import 'package:quickfix/services/translation_service.dart';
import 'package:quickfix/views/settings/language_picker_screen.dart';

class MockLanguages extends Mock implements LanguageService {}
class MockTranslation extends Mock implements TranslationService {}
class MockAuth extends Mock implements AuthService {}
void main() {
  late MockLanguages languages; late MockTranslation translation; late MockAuth auth;
  AppLanguage? result;
  const catalog = [AppLanguage(code: 'en', nativeName: 'English', englishName: 'English'),
    AppLanguage(code: 'ur', nativeName: 'اردو', englishName: 'Urdu'),
    AppLanguage(code: 'bft', nativeName: 'بلتی', englishName: 'Balti'),
    AppLanguage(code: 'hi', nativeName: 'हिन्दी', englishName: 'Hindi')];
  setUp(() {
    result = null; languages = MockLanguages(); translation = MockTranslation(); auth = MockAuth();
    when(() => languages.getAvailableLanguages()).thenAnswer((_) async => catalog);
    when(() => translation.translate(any(), any())).thenAnswer((invocation) async => invocation.positionalArguments.first as String);
    when(() => auth.updateProfile(uid: any(named: 'uid'), preferredLanguage: any(named: 'preferredLanguage'))).thenAnswer((_) async {});
  });
  Future<void> pump(WidgetTester tester, {UserModel? user, String initial = 'en'}) async {
    tester.view.physicalSize = const Size(600, 1000); tester.view.devicePixelRatio = 1; addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) => Scaffold(body: ElevatedButton(onPressed: () async {
      result = await Navigator.of(context).push<AppLanguage>(MaterialPageRoute(builder: (_) => LanguagePickerScreen(initialCode: initial,
        user: user, languageService: languages, translationService: translation, authService: auth)));
    }, child: const Text('Open'))))));
    await tester.tap(find.text('Open')); await tester.pumpAndSettle();
  }
  Future<void> choose(WidgetTester tester, String code) async {
    await tester.enterText(find.byKey(const Key('language-search')), code); await tester.pump();
    await test_viewport.reveal(tester, find.byKey(Key('language-$code'))); await tester.tap(find.byKey(Key('language-$code'))); await tester.pumpAndSettle();
  }
  testWidgets('catalog is dynamic and searches native, English names and codes', (tester) async {
    await pump(tester); await tester.enterText(find.byKey(const Key('language-search')), 'Balti'); await tester.pump();
    expect(find.text('بلتی'), findsOneWidget); expect(find.descendant(of: find.byKey(const Key('language-bft')), matching: find.text('Balti')), findsOneWidget);
    expect(find.byKey(const Key('language-ur')), findsNothing);
    await tester.enterText(find.byKey(const Key('language-search')), 'اردو'); await tester.pump();
    expect(find.byKey(const Key('language-ur')), findsOneWidget);
  });
  testWidgets('chosen target drives ML preview and RTL alignment', (tester) async {
    when(() => translation.translate(any(), 'ur')).thenAnswer((_) async => 'کارکن وقت پر آیا اور مرمت واضح کی۔');
    await pump(tester); await choose(tester, 'ur');
    final text = tester.widget<Text>(find.byKey(const Key('language-preview-text')));
    expect(text.textDirection, TextDirection.rtl); expect(text.textAlign, TextAlign.right);
    verify(() => translation.translate(any(), 'ur')).called(1);
    await tester.tap(find.byKey(const Key('language-save'))); await tester.pumpAndSettle();
    expect(result?.code, 'ur'); verifyNever(() => auth.updateProfile(uid: any(named: 'uid'), preferredLanguage: any(named: 'preferredLanguage')));
  });
  testWidgets('Hindi preview is non-Latin but LTR', (tester) async {
    when(() => translation.translate(any(), 'hi')).thenAnswer((_) async => 'कर्मचारी समय पर आया और मरम्मत समझाई।');
    await pump(tester); await choose(tester, 'hi');
    expect(tester.widget<Text>(find.byKey(const Key('language-preview-text'))).textDirection, TextDirection.ltr);
  });
  testWidgets('an unavailable proxy is not disguised as a successful translation', (tester) async {
    await pump(tester); await choose(tester, 'bft');
    expect(find.textContaining('Machine translation preview is unavailable.'), findsOneWidget);
    when(() => translation.translate(any(), 'bft')).thenAnswer((_) async => 'ترجمہ');
    await tester.tap(find.byKey(const Key('language-preview-retry'))); await tester.pumpAndSettle();
    expect(find.byKey(const Key('language-preview-text')), findsOneWidget);
  });
  testWidgets('empty search has a working clear action', (tester) async {
    await pump(tester); await tester.enterText(find.byKey(const Key('language-search')), 'no-such-language'); await tester.pumpAndSettle();
    expect(find.text('No matching languages'), findsOneWidget);
    await test_viewport.reveal(tester, find.byKey(const Key('language-empty-clear'))); await tester.tap(find.byKey(const Key('language-empty-clear'))); await tester.pumpAndSettle();
    expect(find.byKey(const Key('language-en')), findsOneWidget);
  });
  testWidgets('failed catalogs show a limited fallback with working retry', (tester) async {
    when(() => languages.getAvailableLanguages()).thenThrow(StateError('offline'));
    await pump(tester); expect(find.textContaining('Showing a limited fallback'), findsOneWidget);
    when(() => languages.getAvailableLanguages()).thenAnswer((_) async => catalog);
    await tester.tap(find.byKey(const Key('language-catalog-retry'))); await tester.pumpAndSettle();
    expect(find.textContaining('Showing a limited fallback'), findsNothing); expect(find.byKey(const Key('language-bft')), findsOneWidget);
  });
  testWidgets('save failure keeps the selection and can retry profile persistence', (tester) async {
    final user = UserModel(uid: 'u', fullName: 'Client', email: 'c@example.com', phone: '', role: UserRole.user, createdAt: DateTime(2026), updatedAt: DateTime(2026));
    when(() => auth.updateProfile(uid: 'u', preferredLanguage: 'bft')).thenThrow(StateError('offline'));
    await pump(tester, user: user); await choose(tester, 'bft');
    await tester.tap(find.byKey(const Key('language-save'))); await tester.pumpAndSettle();
    expect(find.textContaining('Could not save this language.'), findsOneWidget); expect(result, isNull);
    when(() => auth.updateProfile(uid: 'u', preferredLanguage: 'bft')).thenAnswer((_) async {});
    await tester.tap(find.byKey(const Key('language-save'))); await tester.pumpAndSettle(); expect(result?.code, 'bft');
  });
  testWidgets('unknown stored language is not silently replaced by English', (tester) async {
    await pump(tester, initial: 'retired-code');
    expect(tester.widget<ElevatedButton>(find.byKey(const Key('language-save'))).onPressed, isNull);
    await choose(tester, 'bft'); expect(tester.widget<ElevatedButton>(find.byKey(const Key('language-save'))).onPressed, isNotNull);
  });
  testWidgets('a pending catalog has a real loading state', (tester) async {
    final pending = Completer<List<AppLanguage>>(); when(() => languages.getAvailableLanguages()).thenAnswer((_) => pending.future);
    await pump(tester); expect(find.byType(LoadingList), findsOneWidget);
    pending.complete(catalog); await tester.pumpAndSettle(); expect(find.byKey(const Key('language-en')), findsOneWidget);
  });
}
