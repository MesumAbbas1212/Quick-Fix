import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quickfix/shared/models/chat_message.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _conversationId(String user1, String user2) {
    final ids = [user1, user2]..sort();
    return '${ids[0]}_${ids[1]}';
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
        .orderBy('createdAt')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ChatMessage.fromMap(doc.data(), doc.id))
            .toList());
  }

  // Get conversation list for a user
  Stream<List<ConversationPreview>> watchConversations(String userId) {
    return _firestore
        .collection('conversations')
        .where('participants', arrayContains: userId)
        .orderBy('lastMessageAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ConversationPreview.fromMap(doc.data(), doc.id))
            .toList());
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

class ConversationPreview {
  final String id;
  final List<String> participants;
  final String lastMessage;
  final DateTime lastMessageAt;
  final String? lastSenderId;
  final int unreadCount;

  ConversationPreview({
    required this.id,
    required this.participants,
    required this.lastMessage,
    required this.lastMessageAt,
    this.lastSenderId,
    this.unreadCount = 0,
  });

  factory ConversationPreview.fromMap(Map<String, dynamic> map, String id) {
    return ConversationPreview(
      id: id,
      participants: List<String>.from(map['participants'] ?? []),
      lastMessage: map['lastMessage'] ?? '',
      lastMessageAt: (map['lastMessageAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastSenderId: map['lastSenderId'],
      unreadCount: (map['unreadCount'] ?? 0),
    );
  }
}