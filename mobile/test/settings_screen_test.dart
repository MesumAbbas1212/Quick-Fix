import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quickfix/models/app_language.dart';
import 'package:quickfix/models/user_model.dart';
import 'package:quickfix/services/auth_service.dart';
import 'package:quickfix/services/language_service.dart';
import 'package:quickfix/views/settings/language_picker_screen.dart';
import 'package:quickfix/views/settings/settings_screen.dart';
class MockLanguages extends Mock implements LanguageService {}
class MockAuth extends Mock implements AuthService {}
void main() {
  final user = UserModel(uid: 'client', fullName: 'Client', email: 'c@example.com', phone: '', role: UserRole.user, createdAt: DateTime(2026), updatedAt: DateTime(2026));
  testWidgets('Settings opens the full dynamic picker and shows the saved choice', (tester) async {
    final languages = MockLanguages(); final auth = MockAuth();
    when(() => languages.getAvailableLanguages()).thenAnswer((_) async => const [AppLanguage(code: 'en', nativeName: 'English'), AppLanguage(code: 'bft', nativeName: 'Balti')]);
    when(() => auth.updateProfile(uid: 'client', preferredLanguage: 'bft')).thenAnswer((_) async {});
    tester.view.physicalSize = const Size(600, 900); tester.view.devicePixelRatio = 1; addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: SettingsScreen(user: user, languageService: languages, authService: auth)));
    expect(find.text('Settings'), findsOneWidget); expect(find.text('Rating'), findsNothing);
    await tester.tap(find.byKey(const Key('settings-language'))); await tester.pumpAndSettle();
    expect(find.byType(LanguagePickerScreen), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('language-bft'))); await tester.tap(find.byKey(const Key('language-bft'))); await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('language-save'))); await tester.pumpAndSettle();
    expect(find.text('Balti'), findsOneWidget); verify(() => auth.updateProfile(uid: 'client', preferredLanguage: 'bft')).called(1);
  });
}
