import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quickfix/models/job_model.dart';
import 'package:quickfix/models/user_model.dart';
import 'package:quickfix/models/worker_profile.dart';
import 'package:quickfix/services/chat_service.dart';
import 'package:quickfix/services/profile_service.dart';
import 'package:quickfix/views/chat/chat_screen.dart';
import 'package:quickfix/views/chat/new_chat_screen.dart';

class MockProfileService extends Mock implements ProfileService {}

class MockChatService extends Mock implements ChatService {}

UserModel _user() {
  return UserModel(
    uid: 'u1',
    email: 'client@quickfix.com',
    fullName: 'Test User',
    phone: '03001234567',
    role: UserRole.user,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );
}

WorkerProfile _worker(String uid, String name) {
  return WorkerProfile(
    uid: uid,
    fullName: name,
    email: '$uid@quickfix.com',
    professions: const [JobCategory.plumbing],
    languages: const ['Urdu', 'English'],
    rating: 4.5,
    completedJobs: 27,
    reviews: 31,
    isAvailable: true,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );
}

void main() {
  late MockProfileService profileService;
  late MockChatService chatService;

  setUp(() {
    profileService = MockProfileService();
    chatService = MockChatService();
  });

  Future<void> pumpNewChat(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: NewChatScreen(
        user: _user(),
        profileService: profileService,
        chatService: chatService,
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('lists workers from search', (tester) async {
    when(() => profileService.searchWorkers()).thenAnswer((_) async => [
          _worker('w1', 'Imran Khan'),
          _worker('w2', 'Ali Worker'),
        ]);

    await pumpNewChat(tester);

    expect(find.text('Imran Khan'), findsOneWidget);
    expect(find.text('Ali Worker'), findsOneWidget);
  });

  testWidgets('typing in search filters workers by name', (tester) async {
    when(() => profileService.searchWorkers()).thenAnswer((_) async => [
          _worker('w1', 'Imran Khan'),
          _worker('w2', 'Ali Worker'),
        ]);

    await pumpNewChat(tester);

    await tester.enterText(find.byType(TextField), 'ali');
    await tester.pumpAndSettle();

    expect(find.text('Ali Worker'), findsOneWidget);
    expect(find.text('Imran Khan'), findsNothing);
  });

  testWidgets('tapping a worker opens the chat screen', (tester) async {
    when(() => profileService.searchWorkers()).thenAnswer((_) async => [
          _worker('w2', 'Ali Worker'),
        ]);
    when(() => chatService.watchMessages(user1: 'u1', user2: 'w2'))
        .thenAnswer((_) => Stream.value(const []));

    await pumpNewChat(tester);

    await tester.tap(find.text('Ali Worker'));
    await tester.pumpAndSettle();

    expect(find.byType(ChatScreen), findsOneWidget);
    expect(find.text('Ali Worker'), findsWidgets);
  });
}