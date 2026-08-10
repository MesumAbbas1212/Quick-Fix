import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quickfix/models/job_model.dart';
import 'package:quickfix/models/worker_profile.dart';

void main() {
  group('WorkerProfile', () {
    test('fromMap creates WorkerProfile with all fields', () {
      final map = {
        'fullName': 'John Worker',
        'email': 'worker@example.com',
        'phone': '+923001234567',
        'about': 'Expert plumber with 5 years experience',
        'professions': ['plumbing', 'electrical'],
        'languages': ['Urdu', 'English'],
        'location': GeoPoint(24.8607, 67.0011),
        'minBudget': 500,
        'maxBudget': 5000,
        'rating': 4.5,
        'completedJobs': 27,
        'reviews': 23,
        'isAvailable': true,
        'avatarUrl': 'https://example.com/avatar.jpg',
        'createdAt': Timestamp.fromDate(DateTime(2024, 1, 1)),
        'updatedAt': Timestamp.fromDate(DateTime(2024, 6, 1)),
      };

      final wp = WorkerProfile.fromMap(map, 'wp123');

      expect(wp.uid, 'wp123');
      expect(wp.fullName, 'John Worker');
      expect(wp.email, 'worker@example.com');
      expect(wp.phone, '+923001234567');
      expect(wp.about, 'Expert plumber with 5 years experience');
      expect(wp.professions, [JobCategory.plumbing, JobCategory.electrical]);
      expect(wp.languages, ['Urdu', 'English']);
      expect(wp.location, GeoPoint(24.8607, 67.0011));
      expect(wp.minBudget, 500);
      expect(wp.maxBudget, 5000);
      expect(wp.rating, 4.5);
      expect(wp.completedJobs, 27);
      expect(wp.reviews, 23);
      expect(wp.isAvailable, true);
      expect(wp.avatarUrl, 'https://example.com/avatar.jpg');
      expect(wp.createdAt, DateTime(2024, 1, 1));
      expect(wp.updatedAt, DateTime(2024, 6, 1));
    });

    test('fromMap handles missing optional fields', () {
      final map = {
        'fullName': 'John Worker',
        'email': 'worker@example.com',
      };

      final wp = WorkerProfile.fromMap(map, 'wp123');

      expect(wp.phone, isNull);
      expect(wp.about, isNull);
      expect(wp.professions, isEmpty);
      expect(wp.languages, isEmpty);
      expect(wp.location, isNull);
      expect(wp.minBudget, 0);
      expect(wp.maxBudget, 0);
      expect(wp.rating, 0);
      expect(wp.completedJobs, 0);
      expect(wp.reviews, 0);
      expect(wp.isAvailable, true);
      expect(wp.avatarUrl, isNull);
    });

    test('fromMap defaults invalid professions to other', () {
      final map = {
        'fullName': 'John',
        'email': 'j@e.com',
        'professions': ['plumbing', 'invalid_profession'],
      };

      final wp = WorkerProfile.fromMap(map, 'wp123');

      expect(wp.professions.length, 2);
      expect(wp.professions.first, JobCategory.plumbing);
      expect(wp.professions.last, JobCategory.other);
    });

    test('toMap returns correct map', () {
      final wp = WorkerProfile(
        uid: 'wp123',
        fullName: 'John Worker',
        email: 'worker@example.com',
        phone: '+923001234567',
        about: 'Expert plumber',
        professions: [JobCategory.plumbing],
        languages: ['Urdu', 'English'],
        location: GeoPoint(24.8607, 67.0011),
        minBudget: 500,
        maxBudget: 5000,
        rating: 4.5,
        completedJobs: 27,
        reviews: 23,
        isAvailable: true,
        avatarUrl: 'https://example.com/avatar.jpg',
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 6, 1),
      );

      final map = wp.toMap();

      expect(map['fullName'], 'John Worker');
      expect(map['email'], 'worker@example.com');
      expect(map['phone'], '+923001234567');
      expect(map['about'], 'Expert plumber');
      expect(map['professions'], ['plumbing']);
      expect(map['languages'], ['Urdu', 'English']);
      expect(map['location'], isA<GeoPoint>());
      expect(map['minBudget'], 500);
      expect(map['maxBudget'], 5000);
      expect(map['rating'], 4.5);
      expect(map['completedJobs'], 27);
      expect(map['reviews'], 23);
      expect(map['isAvailable'], true);
      expect(map['avatarUrl'], 'https://example.com/avatar.jpg');
      expect(map['createdAt'], isA<Timestamp>());
      expect(map['updatedAt'], isA<Timestamp>());
    });

    test('copyWith updates only specified fields', () {
      final wp = WorkerProfile(
        uid: 'wp123',
        fullName: 'John',
        email: 'j@e.com',
        professions: [JobCategory.plumbing],
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );

      final updated = wp.copyWith(
        fullName: 'John Updated',
        isAvailable: false,
        rating: 5.0,
      );

      expect(updated.fullName, 'John Updated');
      expect(updated.isAvailable, false);
      expect(updated.rating, 5.0);
      expect(updated.email, 'j@e.com'); // unchanged
      expect(updated.professions, [JobCategory.plumbing]); // unchanged
    });
  });
}