// ignore_for_file: subtype_of_sealed_class
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quickfix/services/chat_service.dart';
class MockFirestore extends Mock implements FirebaseFirestore {}
class MockCollection extends Mock implements CollectionReference<Map<String, dynamic>> {}
class MockDocument extends Mock implements DocumentReference<Map<String, dynamic>> {}
class MockSnapshot extends Mock implements DocumentSnapshot<Map<String, dynamic>> {}
class MockTransaction extends Mock implements Transaction {}
class MockBatch extends Mock implements WriteBatch {}
void main() {
  setUpAll(() { registerFallbackValue((Transaction _) async {}); });
  late MockFirestore firestore; late MockCollection conversations; late MockCollection messages; late MockDocument parent; late MockDocument message;
  late MockBatch batch; late MockTransaction transaction; late MockSnapshot snapshot; late ChatService service;
  setUp(() {
    firestore = MockFirestore(); conversations = MockCollection(); messages = MockCollection(); parent = MockDocument(); message = MockDocument();
    batch = MockBatch(); transaction = MockTransaction(); snapshot = MockSnapshot();
    when(() => firestore.collection('conversations')).thenReturn(conversations); when(() => conversations.doc(any())).thenReturn(parent);
    when(() => parent.collection('messages')).thenReturn(messages); when(() => messages.doc()).thenReturn(message);
    when(() => firestore.batch()).thenReturn(batch); when(() => batch.commit()).thenAnswer((_) async {});
    when(() => transaction.get(parent)).thenAnswer((_) async => snapshot);
    when(() => transaction.set<Map<String, dynamic>>(parent, any(), any())).thenReturn(transaction);
    when(() => firestore.runTransaction<void>(any())).thenAnswer((invocation) async {
      await (invocation.positionalArguments.first as Future<void> Function(Transaction))(transaction);
    });
    service = ChatService(firestore: firestore);
  });
  test('first message creates the participant parent and the child in one transaction', () async {
    when(() => snapshot.exists).thenReturn(false);
    when(() => transaction.set<Map<String, dynamic>>(parent, any())).thenReturn(transaction);
    when(() => transaction.set<Map<String, dynamic>>(message, any())).thenReturn(transaction);
    await service.sendMessage(senderId: 'b', receiverId: 'a', text: 'Hello');
    final metadata = verify(() => transaction.set<Map<String, dynamic>>(parent, captureAny())).captured.single as Map<String, dynamic>;
    final content = verify(() => transaction.set<Map<String, dynamic>>(message, captureAny())).captured.single as Map<String, dynamic>;
    expect(metadata['participants'], ['b', 'a']);
    expect(content['senderId'], 'b'); expect(content['receiverId'], 'a'); expect(content['text'], 'Hello');
    verify(() => conversations.doc('a_b')).called(1);
  });

  test('a reply updates metadata only and never rewrites participants', () async {
    // The update rule allows only lastMessage/lastMessageAt/lastSenderId/unreadCount;
    // re-sending participants is what produced permission-denied on every reply.
    when(() => snapshot.exists).thenReturn(true);
    when(() => transaction.update(parent, any())).thenReturn(transaction);
    when(() => transaction.set<Map<String, dynamic>>(message, any())).thenReturn(transaction);
    await service.sendMessage(senderId: 'a', receiverId: 'b', text: 'Reply');
    final metadata = verify(() => transaction.update(parent, captureAny())).captured.single as Map<String, dynamic>;
    expect(metadata.containsKey('participants'), isFalse);
    expect(metadata['lastSenderId'], 'a');
    verifyNever(() => transaction.set<Map<String, dynamic>>(parent, any()));
  });
  test('missing parent bootstraps transactionally before a private listener', () async {
    when(() => snapshot.exists).thenReturn(false); await service.ensureConversation('a', 'b');
    final metadata = verify(() => transaction.set<Map<String, dynamic>>(parent, captureAny(), any())).captured.single as Map<String, dynamic>;
    expect(metadata['participants'], ['a', 'b']); expect(metadata['lastMessage'], ''); expect(metadata['unreadCount'], 0);
  });
  test('existing parent is not reset if the first message won the race', () async {
    when(() => snapshot.exists).thenReturn(true); await service.ensureConversation('a', 'b');
    verifyNever(() => transaction.set<Map<String, dynamic>>(parent, any(), any()));
  });
  test('self-conversations are rejected without writes', () async {
    await expectLater(service.sendMessage(senderId: 'a', receiverId: 'a', text: 'Hello'), throwsArgumentError);
    verifyNever(() => firestore.runTransaction<void>(any()));
  });
}
