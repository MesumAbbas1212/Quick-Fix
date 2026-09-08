import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quickfix/models/app_language.dart';
import 'package:quickfix/models/user_model.dart';
import 'package:quickfix/services/auth_service.dart';
import 'package:quickfix/services/language_service.dart';
import 'package:quickfix/views/auth/signup_screen.dart';

class MockAuthService extends Mock implements AuthService {}

class MockLanguageService extends Mock implements LanguageService {}

class MockUserCredential extends Mock implements UserCredential {}

class MockFirebaseUser extends Mock implements User {}

void main() {
  late MockAuthService auth;
  late MockLanguageService languageService;

  List<AppLanguage> get _languages => const [
        AppLanguage(code: 'en', nativeName: 'English', englishName: 'English'),
        AppLanguage(code: 'ur', nativeName: 'اردو', englishName: 'Urdu'),
        AppLanguage(code: 'fr', nativeName: 'Français', englishName: 'French'),
      ];

  setUp(() {
    auth = MockAuthService();
    languageService = MockLanguageService();
    when(() => languageService.getAvailableLanguages())
        .thenAnswer((_) async => _languages);
  });

  Future<void> pumpSignup(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: SignUpScreen(
        languageService: languageService,
        authService: auth,
      ),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> fillForm(WidgetTester tester) async {
    await tester.enterText(find.byType(TextFormField).at(0), 'Test User');
    await tester.enterText(find.byType(TextFormField).at(1), 'a@b.co');
    await tester.enterText(find.byType(TextFormField).at(2), '03001234567');
    await tester.enterText(find.byType(TextFormField).at(3), 'secret123');
    await tester.enterText(find.byType(TextFormField).at(4), 'secret123');
    await tester.pump();
  }

  testWidgets('lists app languages from the language service',
      (tester) async {
    await pumpSignup(tester);

    expect(
      find.text('Choose the language you want the app to show'),
      findsOneWidget,
    );
    // English is selected by default.
    expect(find.text('English'), findsOneWidget);

    await tester.tap(find.byKey(const Key('app-language-dropdown')));
    await tester.pumpAndSettle();

    // The options come from the injected (dynamic) list, not hard-coded UI.
    expect(find.text('English'), findsWidgets);
    expect(find.text('اردو (Urdu)'), findsOneWidget);
    expect(find.text('Français (French)'), findsOneWidget);
  });

  testWidgets('signup submits the language the user selected',
      (tester) async {
    final credential = MockUserCredential();
    final user = MockFirebaseUser();
    when(() => credential.user).thenReturn(user);
    when(() => user.uid).thenReturn('u1');
    when(() => auth.registerWithEmailAndPassword(
          email: any(named: 'email'),
          password: any(named: 'password'),
          fullName: any(named: 'fullName'),
          phone: any(named: 'phone'),
          role: any(named: 'role'),
          language: any(named: 'language'),
        )).thenAnswer((_) async => credential);

    await pumpSignup(tester);

    // Pick Urdu from the dropdown.
    await tester.tap(find.byKey(const Key('app-language-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('اردو (Urdu)'));
    await tester.pumpAndSettle();

    await fillForm(tester);
    await tester.tap(find.text('Create Account'));
    await tester.pumpAndSettle();

    verify(() => auth.registerWithEmailAndPassword(
          email: 'a@b.co',
          password: 'secret123',
          fullName: 'Test User',
          phone: '03001234567',
          role: UserRole.user,
          language: 'ur',
        )).called(1);
  });

  testWidgets('defaults to English when the list loads', (tester) async {
    await pumpSignup(tester);
    final dropdown =
        tester.widget<DropdownButton<AppLanguage>>(
          find.byKey(const Key('app-language-dropdown')),
        );
    expect(dropdown.value?.code, 'en');
  });
}
