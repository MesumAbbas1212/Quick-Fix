// ignore_for_file: subtype_of_sealed_class
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quickfix/models/app_notification.dart';
import 'package:quickfix/services/notification_service.dart';
class MockDB extends Mock implements FirebaseFirestore {}
class MockCollection extends Mock implements CollectionReference<Map<String, dynamic>> {}
class MockRef extends Mock implements DocumentReference<Map<String, dynamic>> {}
class MockSnapshot extends Mock implements DocumentSnapshot<Map<String, dynamic>> {}
class MockTransaction extends Mock implements Transaction {}
void main() {
  setUpAll(() { registerFallbackValue((Transaction _) async {}); });
  test('preferences filter counts, not message contents or push permissions', () {
    const items = [AppNotification(id: '1', userId: 'u', type: 'chat', title: '', body: '', refId: 'c'), AppNotification(id: '2', userId: 'u', type: 'job', title: '', body: '', refId: 'j'),
      AppNotification(id: '3', userId: 'u', type: 'promotion', title: '', body: '', refId: 'x'), AppNotification(id: '4', userId: 'u', type: 'job', title: '', body: '', refId: 'j', isRead: true)];
    expect(NotificationService.unreadCount(items, const NotificationPrefs()), 2);
    expect(NotificationService.unreadCount(items, const NotificationPrefs(messages: false)), 1);
    expect(NotificationPrefs.fromMap(null).promotions, isFalse); expect(NotificationPrefs.fromMap({'jobUpdates': false}).shows('request'), isFalse);
  });
  test('notification data carries a source reference, not captured private content', () {
    final data = NotificationService.event(userId: 'u', type: 'chat', refId: 'c', title: 'New message', body: 'Open conversation');
    expect(data['isRead'], isFalse); expect(data['createdAt'], isA<FieldValue>()); expect(data.keys.toSet(), {'userId', 'type', 'refId', 'title', 'body', 'isRead', 'createdAt'});
    expect(AppNotification.fromMap({'userId': 'u'}, 'n').createdAt, isNull);
  });
  test('mark read rejects a foreign record before writing', () async {
    final db = MockDB(); final collection = MockCollection(); final ref = MockRef(); final snapshot = MockSnapshot(); final transaction = MockTransaction();
    when(() => db.collection('notifications')).thenReturn(collection); when(() => collection.doc('n')).thenReturn(ref); when(() => snapshot.exists).thenReturn(true);
    when(() => snapshot.data()).thenReturn({'userId': 'other'}); when(() => transaction.get(ref)).thenAnswer((_) async => snapshot);
    when(() => db.runTransaction<void>(any())).thenAnswer((call) async { await (call.positionalArguments.first as Future<void> Function(Transaction))(transaction); });
    await expectLater(NotificationService(firestore: db).markRead('u', 'n'), throwsStateError); verifyNever(() => transaction.update(ref, any()));
  });
}
