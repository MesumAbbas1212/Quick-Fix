import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quickfix/models/user_model.dart';
import 'package:quickfix/services/auth_service.dart';
import 'package:quickfix/services/local_image_store.dart';
import 'package:quickfix/views/profile/edit_profile_screen.dart';

class MockAuthService extends Mock implements AuthService {}
class MockImageStore extends Mock implements LocalImageStore {}

/// 1x1 transparent PNG, valid image data for widget preview tests.
final Uint8List _validPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);

UserModel _user({String? avatarUrl}) {
  return UserModel(
    uid: 'u1',
    email: 'test@quickfix.com',
    fullName: 'Test User',
    phone: '03001234567',
    role: UserRole.user,
    avatarUrl: avatarUrl,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );
}

void main() {
  late MockAuthService auth;
  late MockImageStore imageStore;

  setUp(() {
    auth = MockAuthService();
    imageStore = MockImageStore();
    when(() => auth.updateProfile(
          uid: any(named: 'uid'),
          fullName: any(named: 'fullName'),
          phone: any(named: 'phone'),
          avatarUrl: any(named: 'avatarUrl'),
        )).thenAnswer((_) async {});
  });

  Future<void> openEditScreen(
    WidgetTester tester, {
    Future<String?> Function()? pickAvatar,
  }) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => EditProfileScreen(
                    user: _user(),
                    authService: auth,
                    imageStore: imageStore,
                    pickAvatar: pickAvatar,
                  ),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('prefills name and phone fields', (tester) async {
    await openEditScreen(tester);

    expect(find.widgetWithText(TextFormField, 'Test User'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '03001234567'), findsOneWidget);
  });

  testWidgets('validates required name', (tester) async {
    await openEditScreen(tester);

    await tester.enterText(find.byType(TextFormField).at(0), '');
    await tester.tap(find.text('Save'));
    await tester.pump();

    expect(find.text('Name is required'), findsOneWidget);
    verifyNever(() => auth.updateProfile(
          uid: any(named: 'uid'),
          fullName: any(named: 'fullName'),
          phone: any(named: 'phone'),
          avatarUrl: any(named: 'avatarUrl'),
        ));
  });

  testWidgets('saves edited name and phone then pops', (tester) async {
    await openEditScreen(tester);

    await tester.enterText(find.byType(TextFormField).at(0), 'Ahmed Khan');
    await tester.enterText(find.byType(TextFormField).at(1), '03112223344');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    verify(() => auth.updateProfile(
      uid: 'u1',
      fullName: 'Ahmed Khan',
      phone: '03112223344',
      avatarUrl: any(named: 'avatarUrl'),
    )).called(1);
    expect(find.byType(EditProfileScreen), findsNothing);
  });

  testWidgets('picking avatar shows local preview and saves avatarUrl',
      (tester) async {
    when(() => imageStore.readImage(any())).thenAnswer(
      (_) async => _validPng,
    );

    await openEditScreen(
      tester,
      pickAvatar: () async => 'C:\\avatars\\u1.jpg',
    );

    await tester.tap(find.byKey(const Key('edit-avatar')));
    await tester.pumpAndSettle();

    expect(find.byType(Image), findsOneWidget);
    expect(find.byKey(const Key('edit-avatar-preview')), findsOneWidget);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    verify(() => auth.updateProfile(
      uid: 'u1',
      fullName: 'Test User',
      phone: '03001234567',
      avatarUrl: 'C:\\avatars\\u1.jpg',
    )).called(1);
  });

  testWidgets('existing local avatar renders from bytes, not network',
      (tester) async {
    when(() => imageStore.readImage('/data/avatars/a.png'))
        .thenAnswer((_) async => _validPng);

    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: EditProfileScreen(
        user: _user(avatarUrl: '/data/avatars/a.png'),
        authService: auth,
        imageStore: imageStore,
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(Image), findsOneWidget);
    expect(find.byIcon(Icons.person), findsNothing);
  });

  testWidgets('cancel pops without saving', (tester) async {
    await openEditScreen(tester);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.byType(EditProfileScreen), findsNothing);
    verifyNever(() => auth.updateProfile(
          uid: any(named: 'uid'),
          fullName: any(named: 'fullName'),
          phone: any(named: 'phone'),
          avatarUrl: any(named: 'avatarUrl'),
        ));
  });
}
