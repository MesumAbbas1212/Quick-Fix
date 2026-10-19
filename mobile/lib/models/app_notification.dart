import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationPrefs {
  final bool jobUpdates;
  final bool messages;
  final bool promotions;
  const NotificationPrefs({this.jobUpdates = true, this.messages = true, this.promotions = false});
  factory NotificationPrefs.fromMap(Object? data) {
    final map = data is Map ? data : const {};
    return NotificationPrefs(jobUpdates: map['jobUpdates'] != false, messages: map['messages'] != false, promotions: map['promotions'] == true);
  }
  Map<String, bool> toMap() => {'jobUpdates': jobUpdates, 'messages': messages, 'promotions': promotions};
  bool shows(String type) => type == 'chat' ? messages : type == 'promotion' ? promotions : jobUpdates;
}
class AppNotification {
  final String id;
  final String userId;
  final String type;
  final String title;
  final String body;
  final String refId;
  final bool isRead;
  final DateTime? createdAt;
  const AppNotification({required this.id, required this.userId, required this.type, required this.title, required this.body, required this.refId, this.isRead = false, this.createdAt});
  factory AppNotification.fromMap(Map<String, dynamic> data, String id) => AppNotification(id: id, userId: data['userId'] as String? ?? '',
    type: data['type'] as String? ?? '', title: data['title'] as String? ?? 'Update', body: data['body'] as String? ?? '', refId: data['refId'] as String? ?? '',
    isRead: data['isRead'] == true, createdAt: (data['createdAt'] as Timestamp?)?.toDate());
}
