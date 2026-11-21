import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quickfix/services/auth_service.dart';
import 'package:quickfix/views/auth/profile_missing_screen.dart';

class _MockAuthService extends Mock implements AuthService {}

void main() {
  testWidgets('missing-profile state shows the UID, provisioning guidance and retries', (tester) async {
    final auth = _MockAuthService();
    when(() => auth.getUserProfile('uid-admin', serverOnly: true)).thenAnswer((_) async => null);
    await tester.pumpWidget(MaterialApp(home: ProfileMissingScreen(uid: 'uid-admin', authService: auth)));
    expect(find.text('Your profile is missing'), findsOneWidget);
    expect(find.text('UID: uid-admin'), findsOneWidget);
    await tester.tap(find.text('What to do'));
    await tester.pumpAndSettle();
    expect(find.textContaining('users/uid-admin'), findsOneWidget);
    await tester.tap(find.byKey(const Key('profile-missing-retry')));
    await tester.pumpAndSettle();
    verify(() => auth.getUserProfile('uid-admin', serverOnly: true)).called(1);
  });

  testWidgets('network variant explains the failure and retry is available', (tester) async {
    final auth = _MockAuthService();
    when(() => auth.getUserProfile('uid-1', serverOnly: true)).thenAnswer((_) async => null);
    await tester.pumpWidget(MaterialApp(home: ProfileMissingScreen(uid: 'uid-1', authService: auth, initialNetworkError: true)));
    expect(find.text("Can't reach Firestore"), findsOneWidget);
    await tester.tap(find.byKey(const Key('profile-missing-retry')));
    await tester.pumpAndSettle();
    expect(find.text('Your profile is missing'), findsOneWidget);
    verify(() => auth.getUserProfile('uid-1', serverOnly: true)).called(1);
  });
}
