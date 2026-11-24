import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quickfix/models/chat_message.dart';
import 'package:quickfix/services/chat_service.dart';
import 'package:quickfix/services/location_provider.dart';
import 'package:quickfix/services/location_service.dart';
import 'package:quickfix/views/chat/chat_screen.dart';

/// Fails every send with whatever the test hands it, so the screen's error
/// path — not the transport — is what is under test here.
class _FailingChatService extends ChatService {
  _FailingChatService(this.failure);

  final Object failure;

  @override
  Stream<List<ChatMessage>> watchMessages({
    required String user1,
    required String user2,
  }) => Stream.value(const []);

  @override
  Future<void> sendMessage({
    required String senderId,
    required String receiverId,
    required String text,
    String? attachmentUrl,
    String? attachmentType,
  }) async {
    throw failure;
  }

  @override
  Future<void> markAsRead({
    required String conversationId,
    required String userId,
  }) async {}
}

/// Grants location so _shareLocation reaches the send call.
class _GrantedProvider implements LocationProvider {
  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.always;

  @override
  Future<LocationPermission> requestPermission() async =>
      LocationPermission.always;

  @override
  Future<Position> getCurrentPosition() async => Position(
    latitude: 31.5204,
    longitude: 74.3587,
    timestamp: DateTime.now(),
    accuracy: 5,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
  );
}

void main() {
  group('ChatService.describeFailure', () {
    test('permission-denied says permission, never connection', () {
      final message = ChatService.describeFailure(
        FirebaseException(
          plugin: 'cloud_firestore',
          code: 'permission-denied',
          message: 'Missing or insufficient permissions.',
        ),
      );

      expect(message, "You don't have permission to message this user.");
      expect(message.toLowerCase(), isNot(contains('offline')));
      expect(message.toLowerCase(), isNot(contains('connection')));
    });

    test('unavailable and deadline-exceeded read as offline', () {
      for (final code in ['unavailable', 'deadline-exceeded']) {
        expect(
          ChatService.describeFailure(
            FirebaseException(plugin: 'cloud_firestore', code: code),
          ),
          'You appear to be offline. The message will send when you reconnect.',
        );
      }
    });

    test('not-found names the missing conversation', () {
      expect(
        ChatService.describeFailure(
          FirebaseException(plugin: 'cloud_firestore', code: 'not-found'),
        ),
        'This conversation no longer exists.',
      );
    });

    test('an unmapped code is surfaced verbatim', () {
      expect(
        ChatService.describeFailure(
          FirebaseException(
            plugin: 'cloud_firestore',
            code: 'resource-exhausted',
          ),
        ),
        'Could not send message. Error code: resource-exhausted',
      );
    });

    test('a timeout is treated as offline', () {
      expect(
        ChatService.describeFailure(TimeoutException('slow')),
        'You appear to be offline. The message will send when you reconnect.',
      );
    });

    test('sharing location maps permissions and stays location-specific', () {
      final denied = ChatService.describeFailure(
        FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'),
        sharingLocation: true,
      );
      expect(denied, contains('permission'));
      expect(denied, contains('location'));

      final offline = ChatService.describeFailure(
        FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
        sharingLocation: true,
      );
      expect(offline, contains('offline'));
      expect(offline, contains('location'));
    });
  });

  group('ChatScreen surfaces the mapped message', () {
    Future<void> pumpChat(WidgetTester tester, ChatService chat) async {
      tester.view.physicalSize = const Size(1000, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: ChatScreen(
          peerName: 'Imran',
          peerId: 'them',
          myId: 'me',
          chatService: chat,
          locationService: LocationService(provider: _GrantedProvider()),
        ),
      ));
      await tester.pump();
      await tester.pump();
    }

    Future<void> tapSend(WidgetTester tester) async {
      await tester.enterText(find.byType(TextField), 'Hello');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.send));
      await tester.pump();
      await tester.pump();
    }

    testWidgets('a denied send says permission, not connection', (tester) async {
      await pumpChat(
        tester,
        _FailingChatService(
          FirebaseException(
            plugin: 'cloud_firestore',
            code: 'permission-denied',
          ),
        ),
      );

      await tapSend(tester);

      expect(
        find.text("You don't have permission to message this user."),
        findsOneWidget,
      );
      expect(find.textContaining('Check your connection'), findsNothing);
      expect(find.textContaining('Failed to send message'), findsNothing);
    });

    testWidgets('an offline send says so', (tester) async {
      await pumpChat(
        tester,
        _FailingChatService(
          FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
        ),
      );

      await tapSend(tester);

      expect(find.textContaining('You appear to be offline'), findsOneWidget);
    });

    testWidgets('a denied location share is explained as a permission', (
      tester,
    ) async {
      await pumpChat(
        tester,
        _FailingChatService(
          FirebaseException(
            plugin: 'cloud_firestore',
            code: 'permission-denied',
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.location_on));
      await tester.pump();
      // Consent sheet, when shown, leads straight into the share attempt.
      if (find.byKey(const Key('allow-location-button')).evaluate().isNotEmpty) {
        await tester.tap(find.byKey(const Key('allow-location-button')));
      }
      await tester.pump();
      await tester.pump();

      expect(find.textContaining('permission'), findsOneWidget);
      expect(find.textContaining('Could not share location. Check'), findsNothing);
    });
  });

  group('rules parity for the send path', () {
    // No emulator is available to this workspace, so this asserts the two rule
    // predicates the diagnosis depends on still exist in the shipped rules. If
    // either is removed, this fails loudly instead of letting a
    // permission-denied send become unexplainable again.
    test('notBlocked and livePair still gate message create', () {
      final candidates = [
        File('docs/firestore/firestore.rules'),
        File('../docs/firestore/firestore.rules'),
      ];
      final rules = candidates.where((file) => file.existsSync()).firstOrNull;
      if (rules == null) {
        // Running from a directory where the rules file is not reachable:
        // skip rather than fail the suite.
        return;
      }
      final text = rules.readAsStringSync();
      expect(text, contains('function notBlocked(uid)'));
      expect(text, contains('function livePair(participants)'));
      expect(
        text,
        contains(
          'allow create: if signedIn() && notBlocked(request.auth.uid)',
        ),
      );
      expect(text, contains('livePair(getAfter('));
    });
  });
}
