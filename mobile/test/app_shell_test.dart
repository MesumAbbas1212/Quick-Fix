import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quickfix/models/job_model.dart';
import 'package:quickfix/models/review_model.dart';
import 'package:quickfix/services/auth_service.dart';
import 'package:quickfix/services/chat_service.dart';
import 'package:quickfix/services/job_service.dart';
import 'package:quickfix/services/review_service.dart';
import 'package:quickfix/views/auth/app_shell.dart';
import 'package:quickfix/views/client/client_shell.dart';
import 'package:quickfix/views/worker/worker_shell.dart';
import 'package:quickfix/models/user_model.dart';

class MockJobService extends Mock implements JobService {}

class MockChatService extends Mock implements ChatService {}

class MockReviewService extends Mock implements ReviewService {
  @override
  Stream<List<Review>> watchReviewsForWorker(String workerId) =>
      Stream.value(const <Review>[]);
}

class MockAuthService extends Mock implements AuthService {}

UserModel _user(UserRole role) {
  return UserModel(
    uid: 'u1',
    email: 'test@quickfix.com',
    fullName: 'Test User',
    phone: '03001234567',
    role: role,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );
}

void main() {
  late MockJobService jobService;
  late MockChatService chatService;

  setUp(() {
    jobService = MockJobService();
    when(() => jobService.watchUserJobs('u1'))
        .thenAnswer((_) => Stream.value(<JobModel>[]));
    when(() => jobService.watchOpenJobs())
        .thenAnswer((_) => Stream.value(<JobModel>[]));
    when(() => jobService.watchWorkerJobs('u1'))
        .thenAnswer((_) => Stream.value(<JobModel>[]));
    chatService = MockChatService();
    when(() => chatService.watchConversations('u1'))
        .thenAnswer((_) => Stream.value(const <ConversationPreview>[]));
  });

  Future<void> pumpShell(WidgetTester tester, UserModel user) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: AppShell(
          user: user,
          jobService: jobService,
          reviewService: MockReviewService(),
          chatService: chatService,
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('AppShell routes worker role to WorkerShell', (tester) async {
    await pumpShell(tester, _user(UserRole.worker));

    expect(find.byType(WorkerShell), findsOneWidget);
    expect(find.byType(ClientShell), findsNothing);
  });

  testWidgets('worker shell exposes Jobs/My Jobs/Messages/Profile tabs',
      (tester) async {
    await pumpShell(tester, _user(UserRole.worker));

    expect(find.text('Jobs'), findsWidgets);
    expect(find.text('My Jobs'), findsOneWidget);
    expect(find.text('Messages'), findsWidgets);
    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('Find Jobs'), findsNothing);
  });

  testWidgets('AppShell routes user role to ClientShell', (tester) async {
    await pumpShell(tester, _user(UserRole.user));

    expect(find.byType(ClientShell), findsOneWidget);
    expect(find.byType(WorkerShell), findsNothing);
  });

  testWidgets('client shell exposes Home/Workers/Messages/Profile tabs',
      (tester) async {
    await pumpShell(tester, _user(UserRole.user));

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Workers'), findsOneWidget);
    expect(find.text('Messages'), findsWidgets);
    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('Find Jobs'), findsNothing);
  });

  testWidgets('AppShell reflects user stream updates without re-login',
      (tester) async {
    final auth = MockAuthService();
    final updates = StreamController<UserModel>();
    when(() => auth.watchUser('u1')).thenAnswer((_) => updates.stream);

    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: AppShell(
        user: _user(UserRole.user),
        jobService: jobService,
        reviewService: MockReviewService(),
        authService: auth,
        chatService: chatService,
      ),
    ));
    await tester.pump();

    expect(find.text('Hi, Test!'), findsOneWidget);

    updates.add(_user(UserRole.user).copyWith(fullName: 'Renamed Person'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Hi, Renamed!'), findsOneWidget);
    expect(find.text('Hi, Test!'), findsNothing);
    addTearDown(updates.close);
  });

  testWidgets('client shell switches tabs by swiping horizontally',
      (tester) async {
    await pumpShell(tester, _user(UserRole.user));

    // Home tab is active first.
    expect(find.text('Dashboard'), findsOneWidget);

    // Swipe left -> moves to the Workers tab (next tab to the right).
    // The drag must cross half the 1000px page width to snap over.
    await tester.drag(
      find.byType(ClientShell),
      const Offset(-600, 0),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Find skilled professionals near you.'), findsOneWidget);
  });

  testWidgets('worker shell switches tabs by swiping horizontally',
      (tester) async {
    await pumpShell(tester, _user(UserRole.worker));

    // Jobs tab is active first.
    expect(find.text('Suggested Jobs For You'), findsOneWidget);

    // Swipe left -> moves to the My Jobs tab.
    await tester.drag(
      find.byType(WorkerShell),
      const Offset(-600, 0),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('My Jobs'), findsWidgets);
    expect(find.text('All'), findsOneWidget);
  });

  testWidgets('client shell swipes back to the previous tab',
      (tester) async {
    await pumpShell(tester, _user(UserRole.user));

    await tester.drag(
      find.byType(ClientShell),
      const Offset(-600, 0),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(seconds: 1));

    // Swipe right -> back to Home.
    await tester.drag(
      find.byType(ClientShell),
      const Offset(600, 0),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Dashboard'), findsOneWidget);
  });
}
