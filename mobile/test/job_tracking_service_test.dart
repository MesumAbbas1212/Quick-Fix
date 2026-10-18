// ignore_for_file: subtype_of_sealed_class
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quickfix/models/chat_message.dart';
import 'package:quickfix/models/job_model.dart';
import 'package:quickfix/services/chat_service.dart';
import 'package:quickfix/services/job_service.dart';

class MockFirestore extends Mock implements FirebaseFirestore {}
class MockCollection extends Mock implements CollectionReference<Map<String, dynamic>> {}
class MockReference extends Mock implements DocumentReference<Map<String, dynamic>> {}
class MockSnapshot extends Mock implements DocumentSnapshot<Map<String, dynamic>> {}
class MockTransaction extends Mock implements Transaction {}

// Also a regression for lazy Firebase defaults in existing test subclasses.
class MessagesChatService extends ChatService {
  final Stream<List<ChatMessage>> messages;
  MessagesChatService(this.messages);
  @override
  Stream<List<ChatMessage>> watchMessages({required String user1, required String user2}) => messages;
}

ChatMessage _message(String id, String? coordinates, {String sender = 'w1', String receiver = 'me',
  String type = 'location', DateTime? date}) => ChatMessage(id: id, senderId: sender,
  receiverId: receiver, text: 'Shared my location', attachmentType: type,
  attachmentUrl: coordinates, createdAt: date ?? DateTime(2026, 10, 18));

void main() {
  group('explicit shared location selection', () {
    test('empty or text-only messages have no location', () {
      expect(ChatService.latestSharedLocation([], senderId: 'w1', receiverId: 'me'), isNull);
      expect(ChatService.latestSharedLocation([_message('a', '33, 73', type: 'image')],
        senderId: 'w1', receiverId: 'me'), isNull);
    });
    test('valid coordinates are parsed with surrounding spaces', () {
      final value = ChatService.latestSharedLocation([_message('a', ' 33.60, 72.50 ')],
        senderId: 'w1', receiverId: 'me')!;
      expect(value.latitude, 33.6);
      expect(value.longitude, 72.5);
      expect(value.messageId, 'a');
    });
    test('own messages and messages addressed to somebody else are ignored', () {
      expect(ChatService.latestSharedLocation([
        _message('a', '33, 73', sender: 'me', receiver: 'w1'),
        _message('b', '33, 73', receiver: 'another-client'),
      ], senderId: 'w1', receiverId: 'me'), isNull);
    });
    test('rejects malformed, non-finite and out-of-bounds coordinates', () {
      for (final raw in [null, '', '33', '1,2,3', 'x, y', 'NaN, 2', '1, Infinity', '91, 0', '0, -181']) {
        expect(ChatService.latestSharedLocation([_message('a', raw)], senderId: 'w1', receiverId: 'me'), isNull,
          reason: 'Invalid position $raw');
      }
    });
    test('boundary coordinates are legal', () {
      expect(ChatService.latestSharedLocation([_message('a', '-90, 180')],
        senderId: 'w1', receiverId: 'me'), isNotNull);
    });
    test('filters earlier assignments but includes the assignment timestamp', () {
      final since = DateTime(2026, 10, 18);
      expect(ChatService.latestSharedLocation([_message('old', '33, 73', date: since.subtract(const Duration(seconds: 1)))],
        senderId: 'w1', receiverId: 'me', since: since), isNull);
      expect(ChatService.latestSharedLocation([_message('current', '33, 73', date: since)],
        senderId: 'w1', receiverId: 'me', since: since)?.messageId, 'current');
    });
    test('chooses latest valid message regardless of query order', () {
      final value = ChatService.latestSharedLocation([
        _message('new', '34, 73'), _message('bad', '200, 0', date: DateTime(2026, 10, 19)),
        _message('old', '32, 70', date: DateTime(2026, 10, 17)),
      ], senderId: 'w1', receiverId: 'me');
      expect(value?.messageId, 'new');
    });
    test('equal timestamps use a deterministic id tie-break', () {
      expect(ChatService.latestSharedLocation([_message('b', '34, 73'), _message('a', '32, 70')],
        senderId: 'w1', receiverId: 'me')?.messageId, 'b');
    });
    test('stream updates positions without polling or Firebase initialization', () async {
      final service = MessagesChatService(Stream.fromIterable([
        <ChatMessage>[], [_message('shared', '33, 73')],
      ]));
      final values = await service.watchLatestSharedLocation('me', 'w1', senderId: 'w1').toList();
      expect(values.first, isNull);
      expect(values.last?.latitude, 33);
    });
  });

  group('transaction-guarded tracking writes', () {
    late MockFirestore firestore;
    late MockCollection jobs;
    late MockReference reference;
    late MockSnapshot snapshot;
    late MockTransaction transaction;
    late JobService service;
    setUpAll(() { registerFallbackValue((Transaction _) async {}); });
    setUp(() {
      firestore = MockFirestore(); jobs = MockCollection(); reference = MockReference();
      snapshot = MockSnapshot(); transaction = MockTransaction();
      service = JobService(firestore: firestore);
      when(() => firestore.collection('jobs')).thenReturn(jobs);
      when(() => jobs.doc('j1')).thenReturn(reference);
      when(() => transaction.get(reference)).thenAnswer((_) async => snapshot);
      when(() => transaction.update(reference, any())).thenReturn(transaction);
      when(() => snapshot.exists).thenReturn(true);
      when(() => reference.update(any())).thenAnswer((_) async {});
      when(() => firestore.runTransaction<void>(any())).thenAnswer((invocation) async {
        await (invocation.positionalArguments.single as Future<void> Function(Transaction))(transaction);
      });
    });
    void stub(String status, {String worker = 'w1', String owner = 'me'}) {
      when(() => snapshot.data()).thenReturn({'status': status, 'workerId': worker, 'userId': owner});
    }
    Future<void> advance(JobStatus status) => service.advanceJobStatus(jobId: 'j1', workerId: 'w1', status: status);
    test('starts only an assigned job and preserves assignedAt', () async {
      stub('assigned'); await advance(JobStatus.inProgress);
      final data = verify(() => transaction.update(reference, captureAny())).captured.single as Map;
      expect(data['status'], 'inProgress'); expect(data['updatedAt'], isA<Timestamp>());
      expect(data.containsKey('assignedAt'), isFalse); expect(data.containsKey('completedAt'), isFalse);
    });
    test('completion stores its timestamp in the same transaction', () async {
      stub('inProgress'); await advance(JobStatus.completed);
      final data = verify(() => transaction.update(reference, captureAny())).captured.single as Map;
      expect(data['status'], 'completed'); expect(data['completedAt'], isA<Timestamp>());
      expect(data['completedAt'], data['updatedAt']);
    });
    test('does not let an unassigned worker update a job', () async {
      stub('assigned', worker: 'another-worker');
      await expectLater(advance(JobStatus.inProgress), throwsStateError);
      verifyNever(() => transaction.update(reference, any()));
    });
    test('rejects illegal transition targets before opening a transaction', () async {
      await expectLater(advance(JobStatus.cancelled), throwsArgumentError);
      verifyNever(() => firestore.runTransaction<void>(any()));
    });
    test('rejects completion before start and start after cancellation', () async {
      stub('assigned'); await expectLater(advance(JobStatus.completed), throwsStateError);
      stub('cancelled'); await expectLater(advance(JobStatus.inProgress), throwsStateError);
      verifyNever(() => transaction.update(reference, any()));
    });
    test('acknowledged transitions can be retried without another write', () async {
      stub('inProgress'); await advance(JobStatus.inProgress);
      stub('completed'); await advance(JobStatus.completed);
      verifyNever(() => transaction.update(reference, any()));
    });
    test('missing jobs cannot be mutated', () async {
      when(() => snapshot.exists).thenReturn(false);
      when(() => snapshot.data()).thenReturn(null);
      await expectLater(advance(JobStatus.inProgress), throwsStateError);
      await expectLater(service.cancelAssignedJob('j1', 'me'), throwsStateError);
    });
    test('client cancellation only changes an assigned job status and update time', () async {
      stub('assigned'); await service.cancelAssignedJob('j1', 'me');
      final data = verify(() => transaction.update(reference, captureAny())).captured.single as Map;
      expect(data['status'], 'cancelled'); expect(data['updatedAt'], isA<Timestamp>());
      expect(data.keys, unorderedEquals(['status', 'updatedAt']));
    });
    test('a different client cannot cancel', () async {
      stub('assigned', owner: 'another-client');
      await expectLater(service.cancelAssignedJob('j1', 'me'), throwsStateError);
      verifyNever(() => transaction.update(reference, any()));
    });
    test('a cancellation racing start is rejected', () async {
      stub('inProgress'); await expectLater(service.cancelAssignedJob('j1', 'me'), throwsStateError);
      verifyNever(() => transaction.update(reference, any()));
    });
    test('cancel retry is idempotent for the same client', () async {
      stub('cancelled'); await service.cancelAssignedJob('j1', 'me');
      verifyNever(() => transaction.update(reference, any()));
    });
    test('legacy status helper no longer overwrites acceptance on start', () async {
      await service.updateJobStatus('j1', JobStatus.inProgress);
      final data = verify(() => reference.update(captureAny())).captured.single as Map;
      expect(data['status'], 'inProgress'); expect(data.containsKey('assignedAt'), isFalse);
    });
  });
}
