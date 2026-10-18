import 'package:quickfix/services/network_status_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quickfix/models/chat_message.dart';
import 'package:quickfix/models/shared_location.dart';

class ChatService {
  final FirebaseFirestore? _injectedFirestore;
  // Preserve lazy defaults: test subclasses need not initialize Firebase.
  final NetworkStatusService _network;
  ChatService({FirebaseFirestore? firestore, NetworkStatusService? networkStatusService})
      : _injectedFirestore = firestore, _network = networkStatusService ?? NetworkStatusService.instance;
  late final FirebaseFirestore _firestore =
      _injectedFirestore ?? FirebaseFirestore.instance;

  String _conversationId(String user1, String user2) {
    final ids = [user1, user2]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  /// Public conversation-id helper for callers that need the same
  /// deterministic id used to route messages.
  String conversationIdFor(String user1, String user2) =>
      _conversationId(user1, user2);

  /// Uses the existing conversation query; it never requests device location.
  Stream<SharedLocation?> watchLatestSharedLocation(
    String user1,
    String user2, {
    required String senderId,
    DateTime? since,
  }) => watchMessages(user1: user1, user2: user2).map((messages) => latestSharedLocation(
    messages, senderId: senderId,
    receiverId: senderId == user1 ? user2 : user1, since: since,
  ));

  /// Pure selection/validation, shared with tests. Ignore unrelated messages,
  /// old assignments, malformed coordinates and locations we sent ourselves.
  static SharedLocation? latestSharedLocation(
    Iterable<ChatMessage> messages, {
    required String senderId,
    required String receiverId,
    DateTime? since,
  }) {
    SharedLocation? latest;
    for (final message in messages) {
      if (message.senderId != senderId || message.receiverId != receiverId ||
          message.attachmentType != 'location' ||
          (since != null && message.createdAt.isBefore(since))) continue;
      final parts = message.attachmentUrl?.split(',');
      if (parts == null || parts.length != 2) continue;
      final latitude = double.tryParse(parts[0].trim());
      final longitude = double.tryParse(parts[1].trim());
      if (latitude == null || longitude == null ||
          !latitude.isFinite || !longitude.isFinite ||
          latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) continue;
      if (latest == null || message.createdAt.isAfter(latest.sharedAt) ||
          (message.createdAt.isAtSameMomentAs(latest.sharedAt) && message.id.compareTo(latest.messageId) > 0)) {
        latest = SharedLocation(messageId: message.id, latitude: latitude,
          longitude: longitude, sharedAt: message.createdAt);
      }
    }
    return latest;
  }

  // Send a message
  Future<void> sendMessage({
    required String senderId,
    required String receiverId,
    required String text,
    String? attachmentUrl,
    String? attachmentType,
  }) async {
    final conversationId = _conversationId(senderId, receiverId);

    final message = ChatMessage(
      id: '',
      senderId: senderId,
      receiverId: receiverId,
      text: text,
      attachmentUrl: attachmentUrl,
      attachmentType: attachmentType,
      createdAt: DateTime.now(),
    );

    await _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .add(message.toMap());

    // Update conversation metadata
    await _firestore.collection('conversations').doc(conversationId).set({
      'participants': [senderId, receiverId],
      'lastMessage': text,
      'lastMessageAt': Timestamp.fromDate(DateTime.now()),
      'lastSenderId': senderId,
      'unreadCount': FieldValue.increment(1),
    }, SetOptions(merge: true));
  }

  // Stream messages for a conversation
  Stream<List<ChatMessage>> watchMessages({
    required String user1,
    required String user2,
  }) {
    final conversationId = _conversationId(user1, user2);

    return _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .snapshots().trackNetwork(status: _network)
        .map((snapshot) {
          final messages = snapshot.docs
              .map((doc) => ChatMessage.fromMap(doc.data(), doc.id))
              .toList();
          messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
          return messages;
        });
  }

  // Get conversation list for a user
  Stream<List<ConversationPreview>> watchConversations(String userId) {
    return _firestore
        .collection('conversations')
        .where('participants', arrayContains: userId)
        .snapshots().trackNetwork(status: _network)
        .map((snapshot) {
          final conversations = snapshot.docs
              .map((doc) => ConversationPreview.fromMap(doc.data(), doc.id))
              .toList();
          conversations.sort(
              (a, b) => b.lastMessageAt.compareTo(a.lastMessageAt));
          return conversations;
        });
  }

  // Mark messages as read
  Future<void> markAsRead({
    required String conversationId,
    required String userId,
  }) async {
    final unreadQuery = await _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .where('receiverId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .limit(100)
        .get();

    final batch = _firestore.batch();
    for (final doc in unreadQuery.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();

    await _firestore.collection('conversations').doc(conversationId).set({
      'unreadCount': 0,
    }, SetOptions(merge: true));
  }
}

/// Lightweight summary of a conversation for list screens.
class ConversationPreview {
  final String id;
  final List<String> participants;
  final String lastMessage;
  final DateTime lastMessageAt;
  final String? lastSenderId;
  final int unreadCount;

  const ConversationPreview({
    required this.id,
    required this.participants,
    required this.lastMessage,
    required this.lastMessageAt,
    required this.lastSenderId,
    required this.unreadCount,
  });

  factory ConversationPreview.fromMap(Map<String, dynamic> map, String id) {
    return ConversationPreview(
      id: id,
      participants: List<String>.from(map['participants'] ?? const []),
      lastMessage: (map['lastMessage'] as String?) ?? '',
      lastMessageAt: (map['lastMessageAt'] as Timestamp).toDate(),
      lastSenderId: map['lastSenderId'] as String?,
      unreadCount: (map['unreadCount'] as num?)?.toInt() ?? 0,
    );
  }
}