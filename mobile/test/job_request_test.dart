import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quickfix/models/job_request.dart';

void main() {
  group('JobRequest', () {
    test('fromMap creates JobRequest with all fields', () {
      final map = {
        'jobId': 'job1',
        'workerId': 'worker1',
        'userId': 'user1',
        'status': 'accepted',
        'message': 'I can fix this!',
        'createdAt': Timestamp.fromDate(DateTime(2024, 6, 1, 10, 0)),
        'respondedAt': Timestamp.fromDate(DateTime(2024, 6, 1, 10, 5)),
      };

      final req = JobRequest.fromMap(map, 'req1');

      expect(req.id, 'req1');
      expect(req.jobId, 'job1');
      expect(req.workerId, 'worker1');
      expect(req.userId, 'user1');
      expect(req.status, JobRequestStatus.accepted);
      expect(req.message, 'I can fix this!');
      expect(req.createdAt, DateTime(2024, 6, 1, 10, 0));
      expect(req.respondedAt, DateTime(2024, 6, 1, 10, 5));
    });

    test('fromMap defaults status to pending and handles missing fields', () {
      final map = {
        'jobId': 'job1',
        'workerId': 'worker1',
        'userId': 'user1',
      };

      final req = JobRequest.fromMap(map, 'req1');

      expect(req.status, JobRequestStatus.pending);
      expect(req.message, isNull);
      expect(req.respondedAt, isNull);
    });

    test('fromMap defaults invalid status to pending', () {
      final map = {
        'jobId': 'job1',
        'workerId': 'worker1',
        'userId': 'user1',
        'status': 'invalid_status',
      };

      final req = JobRequest.fromMap(map, 'req1');
      expect(req.status, JobRequestStatus.pending);
    });

    test('toMap returns correct map', () {
      final req = JobRequest(
        id: 'req1',
        jobId: 'job1',
        workerId: 'worker1',
        userId: 'user1',
        status: JobRequestStatus.declined,
        message: 'Sorry, busy',
        createdAt: DateTime(2024, 6, 1, 10, 0),
        respondedAt: DateTime(2024, 6, 1, 10, 5),
      );

      final map = req.toMap();

      expect(map['jobId'], 'job1');
      expect(map['workerId'], 'worker1');
      expect(map['userId'], 'user1');
      expect(map['status'], 'declined');
      expect(map['message'], 'Sorry, busy');
      expect(map['createdAt'], isA<Timestamp>());
      expect(map['respondedAt'], isA<Timestamp>());
    });

    test('copyWith updates only specified fields', () {
      final req = JobRequest(
        id: 'req1',
        jobId: 'job1',
        workerId: 'worker1',
        userId: 'user1',
        createdAt: DateTime.now(),
      );

      final updated = req.copyWith(
        status: JobRequestStatus.accepted,
        respondedAt: DateTime(2024, 6, 2),
      );

      expect(updated.status, JobRequestStatus.accepted);
      expect(updated.respondedAt, DateTime(2024, 6, 2));
      expect(updated.jobId, 'job1'); // unchanged
      expect(updated.workerId, 'worker1'); // unchanged
    });
  });
}