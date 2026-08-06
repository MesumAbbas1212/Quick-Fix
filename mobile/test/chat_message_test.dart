import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quickfix/shared/models/chat_message.dart';

void main() {
  group('ChatMessage', () {
    test('fromMap creates ChatMessage with all fields', () {
      final map = {
        'senderId': 'user1',
        'receiverId': 'user2',
        'text': 'Hello!',
        'attachmentUrl': 'https://example.com/img.jpg',
        'attachmentType': 'image',
        'isRead': true,
        'createdAt': Timestamp.fromDate(DateTime(2024, 6, 1, 10, 30)),
      };

      final msg = ChatMessage.fromMap(map, 'msg1');

      expect(msg.id, 'msg1');
      expect(msg.senderId, 'user1');
      expect(msg.receiverId, 'user2');
      expect(msg.text, 'Hello!');
      expect(msg.attachmentUrl, 'https://example.com/img.jpg');
      expect(msg.attachmentType, 'image');
      expect(msg.isRead, true);
      expect(msg.createdAt, DateTime(2024, 6, 1, 10, 30));
    });

    test('fromMap defaults isRead to false', () {
      final map = {
        'senderId': 'user1',
        'receiverId': 'user2',
        'text': 'Hi',
        'createdAt': Timestamp.fromDate(DateTime.now()),
      };

      final msg = ChatMessage.fromMap(map, 'msg1');
      expect(msg.isRead, false);
      expect(msg.attachmentUrl, isNull);
      expect(msg.attachmentType, isNull);
    });

    test('toMap returns correct map', () {
      final msg = ChatMessage(
        id: 'msg1',
        senderId: 'user1',
        receiverId: 'user2',
        text: 'Hello!',
        attachmentUrl: 'https://example.com/img.jpg',
        attachmentType: 'image',
        isRead: true,
        createdAt: DateTime(2024, 6, 1, 10, 30),
      );

      final map = msg.toMap();

      expect(map['senderId'], 'user1');
      expect(map['receiverId'], 'user2');
      expect(map['text'], 'Hello!');
      expect(map['attachmentUrl'], 'https://example.com/img.jpg');
      expect(map['attachmentType'], 'image');
      expect(map['isRead'], true);
      expect(map['createdAt'], isA<Timestamp>());
    });

    test('copyWith updates only specified fields', () {
      final msg = ChatMessage(
        id: 'msg1',
        senderId: 'user1',
        receiverId: 'user2',
        text: 'Hello',
        createdAt: DateTime.now(),
      );

      final updated = msg.copyWith(
        text: 'Updated',
        isRead: true,
      );

      expect(updated.text, 'Updated');
      expect(updated.isRead, true);
      expect(updated.senderId, 'user1'); // unchanged
      expect(updated.receiverId, 'user2'); // unchanged
    });
  });
}