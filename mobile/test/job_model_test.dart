import 'package:flutter_test/flutter_test.dart';
import 'package:quickfix/shared/models/job_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() {
  group('JobModel', () {
    test('fromMap creates JobModel with all fields', () {
      final map = {
        'userId': 'user123',
        'workerId': 'worker456',
        'title': 'Fix leaking pipe',
        'description': 'Kitchen sink leaking',
        'category': 'plumbing',
        'address': '123 Main St, Karachi',
        'location': GeoPoint(24.8607, 67.0011),
        'budgetMin': 1500,
        'budgetMax': 3000,
        'preferredDate': Timestamp.fromDate(DateTime(2024, 6, 15)),
        'preferredTime': Timestamp.fromDate(DateTime(2024, 6, 15, 10, 0)),
        'images': ['img1.jpg', 'img2.jpg'],
        'status': 'assigned',
        'rating': 4.5,
        'review': 'Great work!',
        'createdAt': Timestamp.fromDate(DateTime(2024, 6, 1)),
        'updatedAt': Timestamp.fromDate(DateTime(2024, 6, 10)),
        'assignedAt': Timestamp.fromDate(DateTime(2024, 6, 2)),
        'completedAt': Timestamp.fromDate(DateTime(2024, 6, 12)),
      };

      final job = JobModel.fromMap(map, 'job789');

      expect(job.id, 'job789');
      expect(job.userId, 'user123');
      expect(job.workerId, 'worker456');
      expect(job.title, 'Fix leaking pipe');
      expect(job.description, 'Kitchen sink leaking');
      expect(job.category, JobCategory.plumbing);
      expect(job.address, '123 Main St, Karachi');
      expect(job.location.latitude, 24.8607);
      expect(job.location.longitude, 67.0011);
      expect(job.budgetMin, 1500);
      expect(job.budgetMax, 3000);
      expect(job.preferredDate, DateTime(2024, 6, 15));
      expect(job.preferredTime, DateTime(2024, 6, 15, 10, 0));
      expect(job.images, ['img1.jpg', 'img2.jpg']);
      expect(job.status, JobStatus.assigned);
      expect(job.rating, 4.5);
      expect(job.review, 'Great work!');
      expect(job.createdAt, DateTime(2024, 6, 1));
      expect(job.updatedAt, DateTime(2024, 6, 10));
      expect(job.assignedAt, DateTime(2024, 6, 2));
      expect(job.completedAt, DateTime(2024, 6, 12));
    });

    test('fromMap defaults category to other when invalid', () {
      final map = {
        'userId': 'user123',
        'title': 'Test Job',
        'description': 'Test',
        'category': 'invalid_category',
        'address': '123 St',
        'location': GeoPoint(0, 0),
        'budgetMin': 1000,
        'budgetMax': 2000,
        'preferredDate': Timestamp.fromDate(DateTime.now()),
      };

      final job = JobModel.fromMap(map, 'job1');
      expect(job.category, JobCategory.other);
    });

    test('fromMap defaults status to open when invalid', () {
      final map = {
        'userId': 'user123',
        'title': 'Test Job',
        'description': 'Test',
        'category': 'cleaning',
        'address': '123 St',
        'location': GeoPoint(0, 0),
        'budgetMin': 1000,
        'budgetMax': 2000,
        'preferredDate': Timestamp.fromDate(DateTime.now()),
        'status': 'invalid_status',
      };

      final job = JobModel.fromMap(map, 'job1');
      expect(job.status, JobStatus.open);
    });

    test('fromMap handles missing optional fields', () {
      final map = {
        'userId': 'user123',
        'title': 'Test Job',
        'description': 'Test',
        'category': 'cleaning',
        'address': '123 St',
        'location': GeoPoint(0, 0),
        'budgetMin': 1000,
        'budgetMax': 2000,
        'preferredDate': Timestamp.fromDate(DateTime.now()),
      };

      final job = JobModel.fromMap(map, 'job1');
      expect(job.workerId, isNull);
      expect(job.images, isEmpty);
      expect(job.rating, isNull);
      expect(job.review, isNull);
      expect(job.assignedAt, isNull);
      expect(job.completedAt, isNull);
    });

    test('toMap returns correct map', () {
      final job = JobModel(
        id: 'job789',
        userId: 'user123',
        workerId: 'worker456',
        title: 'Fix leaking pipe',
        description: 'Kitchen sink leaking',
        category: JobCategory.plumbing,
        address: '123 Main St, Karachi',
        location: GeoPoint(24.8607, 67.0011),
        budgetMin: 1500,
        budgetMax: 3000,
        preferredDate: DateTime(2024, 6, 15),
        preferredTime: DateTime(2024, 6, 15, 10, 0),
        images: ['img1.jpg', 'img2.jpg'],
        status: JobStatus.assigned,
        rating: 4.5,
        review: 'Great work!',
        createdAt: DateTime(2024, 6, 1),
        updatedAt: DateTime(2024, 6, 10),
        assignedAt: DateTime(2024, 6, 2),
        completedAt: DateTime(2024, 6, 12),
      );

      final map = job.toMap();

      expect(map['userId'], 'user123');
      expect(map['workerId'], 'worker456');
      expect(map['title'], 'Fix leaking pipe');
      expect(map['description'], 'Kitchen sink leaking');
      expect(map['category'], 'plumbing');
      expect(map['address'], '123 Main St, Karachi');
      expect(map['location'], isA<GeoPoint>());
      expect(map['budgetMin'], 1500);
      expect(map['budgetMax'], 3000);
      expect(map['preferredDate'], isA<Timestamp>());
      expect(map['preferredTime'], isA<Timestamp>());
      expect(map['images'], ['img1.jpg', 'img2.jpg']);
      expect(map['status'], 'assigned');
      expect(map['rating'], 4.5);
      expect(map['review'], 'Great work!');
      expect(map['createdAt'], isA<Timestamp>());
      expect(map['updatedAt'], isA<Timestamp>());
      expect(map['assignedAt'], isA<Timestamp>());
      expect(map['completedAt'], isA<Timestamp>());
    });

    test('toMap handles null optional fields', () {
      final job = JobModel(
        id: 'job1',
        userId: 'user123',
        title: 'Test Job',
        description: 'Test',
        category: JobCategory.cleaning,
        address: '123 St',
        location: GeoPoint(0, 0),
        budgetMin: 1000,
        budgetMax: 2000,
        preferredDate: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final map = job.toMap();

      expect(map['workerId'], isNull);
      expect(map['preferredTime'], isNull);
      expect(map['images'], isEmpty);
      expect(map['rating'], isNull);
      expect(map['review'], isNull);
      expect(map['assignedAt'], isNull);
      expect(map['completedAt'], isNull);
    });

    test('copyWith updates only specified fields', () {
      final job = JobModel(
        id: 'job1',
        userId: 'user123',
        title: 'Original Title',
        description: 'Original',
        category: JobCategory.cleaning,
        address: '123 St',
        location: GeoPoint(0, 0),
        budgetMin: 1000,
        budgetMax: 2000,
        preferredDate: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final updated = job.copyWith(
        title: 'Updated Title',
        status: JobStatus.assigned,
        workerId: 'worker456',
        budgetMax: 5000,
      );

      expect(updated.title, 'Updated Title');
      expect(updated.status, JobStatus.assigned);
      expect(updated.workerId, 'worker456');
      expect(updated.budgetMax, 5000);
      expect(updated.description, 'Original'); // unchanged
      expect(updated.category, JobCategory.cleaning); // unchanged
      expect(updated.budgetMin, 1000); // unchanged
    });
  });
}