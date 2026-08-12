import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quickfix/models/user_model.dart';
import 'package:quickfix/services/auth_service.dart';
import 'package:quickfix/services/chat_service.dart';
import 'package:quickfix/services/profile_service.dart';
import 'package:quickfix/views/chat/chat_screen.dart';
import 'package:quickfix/views/chat/conversations_screen.dart';
import 'package:quickfix/views/chat/new_chat_screen.dart';

class MockChatService extends Mock implements ChatService {}

class MockAuthService extends Mock implements AuthService {}

class MockProfileService extends Mock implements ProfileService {}

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

UserModel _peer() {
  return UserModel(
    uid: 'w2',
    email: 'ali@quickfix.com',
    fullName: 'Ali Worker',
    phone: '03001234567',
    role: UserRole.worker,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );
}

void main() {
  late MockChatService chatService;
  late MockAuthService authService;
  late MockProfileService profileService;

  setUp(() {
    chatService = MockChatService();
    authService = MockAuthService();
    profileService = MockProfileService();
    when(() => profileService.searchWorkers())
        .thenAnswer((_) async => const []);
  });

  Future<void> pumpConversations(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: ConversationsScreen(
        user: _user(),
        chatService: chatService,
        authService: authService,
        profileService: profileService,
      ),
    ));
    await tester.pump();
  }

  testWidgets('shows empty state when no conversations', (tester) async {
    when(() => chatService.watchConversations('u1'))
        .thenAnswer((_) => Stream.value(const <ConversationPreview>[]));

    await pumpConversations(tester);

    expect(find.text('No conversations yet'), findsOneWidget);
  });

  testWidgets('lists conversations with peer name and last message',
      (tester) async {
    when(() => chatService.watchConversations('u1')).thenAnswer((_) =>
        Stream.value([
          ConversationPreview(
            id: 'u1_w2',
            participants: const ['u1', 'w2'],
            lastMessage: 'hi there',
            lastMessageAt: DateTime.now(),
            lastSenderId: 'w2',
            unreadCount: 2,
          ),
        ]));
    when(() => authService.getUserProfile('w2')).thenAnswer((_) async => _peer());
    when(() => chatService.watchMessages(user1: 'u1', user2: 'w2'))
        .thenAnswer((_) => Stream.value(const []));

    await pumpConversations(tester);
    await tester.pumpAndSettle();

    expect(find.text('Ali Worker'), findsOneWidget);
    expect(find.text('hi there'), findsOneWidget);

    await tester.tap(find.text('Ali Worker'));
    await tester.pumpAndSettle();
    expect(find.byType(ChatScreen), findsOneWidget);
    expect(find.text('Ali Worker'), findsWidgets);
  });

  testWidgets('New Chat opens worker search', (tester) async {
    when(() => chatService.watchConversations('u1'))
        .thenAnswer((_) => Stream.value(const <ConversationPreview>[]));

    await pumpConversations(tester);

    await tester.tap(find.text('New Chat').first);
    await tester.pumpAndSettle();

    expect(find.byType(NewChatScreen), findsOneWidget);
  });
}