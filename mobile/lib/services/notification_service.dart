import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quickfix/models/app_notification.dart';
import 'package:quickfix/services/network_status_service.dart';

class NotificationService {
  final FirebaseFirestore? _injectedFirestore;
  final NetworkStatusService _network;
  NotificationService({FirebaseFirestore? firestore, NetworkStatusService? networkStatusService}) : _injectedFirestore = firestore,
    _network = networkStatusService ?? NetworkStatusService.instance;
  late final FirebaseFirestore _firestore = _injectedFirestore ?? FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> get _items => _firestore.collection('notifications');
  /// Minimal generic copy, no message text, address, bank reference or image path.
  static Map<String, dynamic> event({required String userId, required String type, required String refId, required String title, required String body}) =>
    {'userId': userId, 'type': type, 'refId': refId, 'title': title, 'body': body, 'isRead': false, 'createdAt': FieldValue.serverTimestamp()};
  void addToTransaction(Transaction transaction, {required String userId, required String type, required String refId, required String title, required String body}) {
    transaction.set(_items.doc(), event(userId: userId, type: type, refId: refId, title: title, body: body));
  }
  void addToBatch(WriteBatch batch, {required String userId, required String type, required String refId, required String title, required String body}) {
    batch.set(_items.doc(), event(userId: userId, type: type, refId: refId, title: title, body: body));
  }
  Future<void> send({required String userId, required String type, required String refId, required String title, required String body}) async {
    await _items.add(event(userId: userId, type: type, refId: refId, title: title, body: body)).timeout(const Duration(seconds: 8));
  }
  /// Existing core operations must not fail or hang after their write already
  /// committed. Client-only delivery can be late/lost; no server guarantee/FCM.
  void sendBestEffort({required String userId, required String type, required String refId, required String title, required String body}) {
    unawaited(send(userId: userId, type: type, refId: refId, title: title, body: body).catchError((Object _) {}));
  }
  Stream<List<AppNotification>> watchItems(String uid) => _items.where('userId', isEqualTo: uid).orderBy('createdAt', descending: true).limit(200)
    .snapshots().trackNetwork(status: _network).map((snapshot) => snapshot.docs.map((doc) => AppNotification.fromMap(doc.data(), doc.id)).toList());
  static int unreadCount(Iterable<AppNotification> items, NotificationPrefs prefs) => items.where((item) => !item.isRead && prefs.shows(item.type)).length;
  Future<void> markRead(String uid, String id) async {
    final ref = _items.doc(id);
    await _firestore.runTransaction<void>((transaction) async {
      final snapshot = await transaction.get(ref);
      if (!snapshot.exists) return;
      if (snapshot.data()?['userId'] != uid) throw StateError('Not your notification.');
      transaction.update(ref, {'isRead': true});
    }).timeout(const Duration(seconds: 10));
  }
  Future<void> markAllRead(String uid) async {
    final clock = Stopwatch()..start(); var count = 0;
    while (true) {
      if (count >= 1000 || clock.elapsed > const Duration(seconds: 20)) throw StateError('Some updates were marked read. Repeat for the rest.');
      final snapshot = await _items.where('userId', isEqualTo: uid).where('isRead', isEqualTo: false).limit(100)
        .get(const GetOptions(source: Source.server)).timeout(const Duration(seconds: 8));
      if (snapshot.docs.isEmpty) return;
      final batch = _firestore.batch(); for (final doc in snapshot.docs) { batch.update(doc.reference, {'isRead': true}); }
      await batch.commit().timeout(const Duration(seconds: 8)); count += snapshot.docs.length;
    }
  }
}
