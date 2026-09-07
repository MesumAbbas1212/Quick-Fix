import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:quickfix/models/chat_message.dart';
import 'package:quickfix/services/chat_service.dart';
import 'package:quickfix/services/location_provider.dart';
import 'package:quickfix/services/location_service.dart';
import 'package:quickfix/services/map_launcher.dart';
import 'package:quickfix/views/chat/chat_screen.dart';

class _DeniedProvider implements LocationProvider {
  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.denied;

  @override
  Future<LocationPermission> requestPermission() async =>
      LocationPermission.denied;

  @override
  Future<Position> getCurrentPosition() async => throw UnimplementedError();
}

class _GrantedProvider implements LocationProvider {
  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.whileInUse;

  @override
  Future<LocationPermission> requestPermission() async =>
      LocationPermission.whileInUse;

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

class _FakeChatService extends ChatService {
  final _controller = StreamController<List<ChatMessage>>.broadcast();
  final sentMessages = <Map<String, dynamic>>[];
  final markedRead = <String>[];

  void emit(List<ChatMessage> messages) => _controller.add(messages);

  @override
  Stream<List<ChatMessage>> watchMessages({
    required String user1,
    required String user2,
  }) =>
      _controller.stream;

  @override
  Future<void> sendMessage({
    required String senderId,
    required String receiverId,
    required String text,
    String? attachmentUrl,
    String? attachmentType,
  }) async {
    sentMessages.add({
      'senderId': senderId,
      'receiverId': receiverId,
      'text': text,
      'attachmentUrl': attachmentUrl,
      'attachmentType': attachmentType,
    });
  }

  @override
  Future<void> markAsRead({
    required String conversationId,
    required String userId,
  }) async {
    markedRead.add('$conversationId/$userId');
  }
}

/// Records opened URLs instead of launching a real external app.
class _RecordingUrlLauncher implements UrlLauncher {
  final List<String> openedUrls;

  _RecordingUrlLauncher(this.openedUrls);

  @override
  Future<bool> open(String url) async {
    openedUrls.add(url);
    return true;
  }

  @override
  Future<bool> openLocation(double latitude, double longitude) async {
    final coords = '${latitude.toStringAsFixed(5)},'
        '${longitude.toStringAsFixed(5)}';
    return open('https://www.google.com/maps/search/?api=1&query=$coords');
  }
}

void main() {
  testWidgets('chat shows empty state when no messages', (tester) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final chat = _FakeChatService();

    await tester.pumpWidget(MaterialApp(
      home: ChatScreen(
        peerName: 'Worker',
        peerId: 'peer-1',
        myId: 'me-1',
        chatService: chat,
      ),
    ));
    await tester.pump();
    chat.emit([]);
    await tester.pump();

    expect(find.text('No messages yet - say hi!'), findsOneWidget);
  });

  testWidgets('sending a message pushes it through ChatService',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final chat = _FakeChatService();

    await tester.pumpWidget(MaterialApp(
      home: ChatScreen(
        peerName: 'Worker',
        peerId: 'peer-1',
        myId: 'me-1',
        chatService: chat,
      ),
    ));
    await tester.pump();
    chat.emit([]);
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'I am on my way');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();

    expect(chat.sentMessages, hasLength(1));
    expect(chat.sentMessages.single['text'], 'I am on my way');
    expect(chat.sentMessages.single['senderId'], 'me-1');
    expect(chat.sentMessages.single['receiverId'], 'peer-1');
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty);
  });

  testWidgets('location message renders as a map pin bubble', (tester) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final chat = _FakeChatService();

    await tester.pumpWidget(MaterialApp(
      home: ChatScreen(
        peerName: 'Worker',
        peerId: 'peer-1',
        myId: 'me-1',
        chatService: chat,
      ),
    ));
    await tester.pump();
    chat.emit([
      ChatMessage(
        id: '1',
        senderId: 'peer-1',
        receiverId: 'me-1',
        text: 'Shared my location',
        attachmentType: 'location',
        attachmentUrl: '31.5204, 74.3587',
        createdAt: DateTime(2026, 8, 11, 14, 30),
      ),
    ]);
    await tester.pump();

    expect(find.text('Shared Location'), findsOneWidget);
    expect(find.text('31.5204, 74.3587'), findsOneWidget);
    expect(find.text('📍'), findsOneWidget);
  });

  testWidgets('tapping a location message opens Google Maps',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final chat = _FakeChatService();
    final openedUrls = <String>[];
    final launcher = _RecordingUrlLauncher(openedUrls);

    await tester.pumpWidget(MaterialApp(
      home: ChatScreen(
        peerName: 'Worker',
        peerId: 'peer-1',
        myId: 'me-1',
        chatService: chat,
        urlLauncher: launcher,
      ),
    ));
    await tester.pump();
    chat.emit([
      ChatMessage(
        id: '1',
        senderId: 'peer-1',
        receiverId: 'me-1',
        text: 'Shared my location',
        attachmentType: 'location',
        attachmentUrl: '31.5204, 74.3587',
        createdAt: DateTime(2026, 8, 11, 14, 30),
      ),
    ]);
    await tester.pump();

    await tester.tap(find.text('Shared Location'));
    await tester.pumpAndSettle();

    expect(openedUrls, hasLength(1));
    expect(
      openedUrls.single,
      contains('google.com/maps/search/?api=1&query=31.52040,74.35870'),
    );
  });

  testWidgets('location bubble shows hint to open in Google Maps',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final chat = _FakeChatService();

    await tester.pumpWidget(MaterialApp(
      home: ChatScreen(
        peerName: 'Worker',
        peerId: 'peer-1',
        myId: 'me-1',
        chatService: chat,
      ),
    ));
    await tester.pump();
    chat.emit([
      ChatMessage(
        id: '1',
        senderId: 'peer-1',
        receiverId: 'me-1',
        text: 'Shared my location',
        attachmentType: 'location',
        attachmentUrl: '31.5204, 74.3587',
        createdAt: DateTime(2026, 8, 11, 14, 30),
      ),
    ]);
    await tester.pump();

    expect(find.text('Tap to open in Google Maps'), findsOneWidget);
  });

  testWidgets('location share blocked with snackbar when permission denied',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final chat = _FakeChatService();

    await tester.pumpWidget(MaterialApp(
      home: ChatScreen(
        peerName: 'Worker',
        peerId: 'peer-1',
        myId: 'me-1',
        chatService: chat,
        locationService: LocationService(provider: _DeniedProvider()),
      ),
    ));
    await tester.pump();
    chat.emit([]);
    await tester.pump();

    await tester.tap(find.byIcon(Icons.location_on));
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.textContaining('Location permission is required'),
        findsOneWidget);
    expect(chat.sentMessages, isEmpty);
  });

  testWidgets('location share sends a location attachment when permitted',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final chat = _FakeChatService();

    await tester.pumpWidget(MaterialApp(
      home: ChatScreen(
        peerName: 'Worker',
        peerId: 'peer-1',
        myId: 'me-1',
        chatService: chat,
        locationService: LocationService(provider: _GrantedProvider()),
      ),
    ));
    await tester.pump();
    chat.emit([]);
    await tester.pump();

    await tester.tap(find.byIcon(Icons.location_on));
    await tester.pumpAndSettle();

    expect(chat.sentMessages, hasLength(1));
    expect(chat.sentMessages.single['attachmentType'], 'location');
    expect(chat.sentMessages.single['attachmentUrl'], '31.52040, 74.35870');
    expect(chat.sentMessages.single['text'], 'Shared my location');
  });

  testWidgets('opening a chat marks the conversation as read',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final chat = _FakeChatService();

    await tester.pumpWidget(MaterialApp(
      home: ChatScreen(
        peerName: 'Worker',
        peerId: 'peer-1',
        myId: 'me-1',
        chatService: chat,
      ),
    ));
    await tester.pump();
    chat.emit([
      ChatMessage(
        id: '1',
        senderId: 'peer-1',
        receiverId: 'me-1',
        text: 'hello',
        createdAt: DateTime.now(),
      ),
    ]);
    await tester.pumpAndSettle();

    expect(chat.markedRead, contains('me-1_peer-1/me-1'));
  });
}
