import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quickfix/shared/models/job_model.dart';
import 'package:quickfix/services/matching_service.dart';

void main() {
  group('MatchingService', () {
    late MatchingService service;

    setUp(() {
      service = MatchingService();
    });

    test('calculateDistance returns correct km', () {
      final point1 = GeoPoint(24.8607, 67.0011); // Karachi
      final point2 = GeoPoint(24.8607, 67.0011); // Same point
      
      final distance = service.calculateDistance(point1, point2);
      expect(distance, 0.0);
    });

    test('scoreJobForWorker returns high score for perfect match', () {
      final workerLocation = GeoPoint(24.8607, 67.0011);
      final jobLocation = GeoPoint(24.8607, 67.0011); // 0 km away
      
      final score = service.scoreJobForWorker(
        workerLocation: workerLocation,
        jobLocation: jobLocation,
        workerCategory: JobCategory.plumbing,
        jobCategory: JobCategory.plumbing,
        workerMinBudget: 1000,
        workerMaxBudget: 5000,
        jobBudgetMin: 1500,
        jobBudgetMax: 3000,
        workerRating: 5.0,
      );
      
      // Distance=1.0, Category=1.0, Budget overlap=0.375, Rating=1.0
      // Weighted: 0.4*1 + 0.3*1 + 0.2*0.375 + 0.1*1 = 0.875
      expect(score, closeTo(0.875, 0.01));
    });

    test('scoreJobForWorker returns low score for far distance', () {
      final workerLocation = GeoPoint(24.8607, 67.0011); // Karachi
      final jobLocation = GeoPoint(33.6844, 73.0479); // Islamabad ~1100km
      
      final score = service.scoreJobForWorker(
        workerLocation: workerLocation,
        jobLocation: jobLocation,
        workerCategory: JobCategory.plumbing,
        jobCategory: JobCategory.plumbing,
        workerMinBudget: 1000,
        workerMaxBudget: 5000,
        jobBudgetMin: 1500,
        jobBudgetMax: 3000,
        workerRating: 5.0,
      );
      
      // Distance > maxDistance (50km) => distanceScore = 0
      // Category=1.0, Budget=0.375, Rating=1.0
      // Weighted: 0.4*0 + 0.3*1 + 0.2*0.375 + 0.1*1 = 0.475
      expect(score, closeTo(0.475, 0.01));
    });

    test('scoreJobForWorker returns 0 category score for mismatch', () {
      final workerLocation = GeoPoint(24.8607, 67.0011);
      final jobLocation = GeoPoint(24.8607, 67.0011);
      
      final score = service.scoreJobForWorker(
        workerLocation: workerLocation,
        jobLocation: jobLocation,
        workerCategory: JobCategory.plumbing,
        jobCategory: JobCategory.electrical, // Different category
        workerMinBudget: 1000,
        workerMaxBudget: 5000,
        jobBudgetMin: 1500,
        jobBudgetMax: 3000,
        workerRating: 5.0,
      );
      
      // Distance=1.0, Category=0, Budget=0.375, Rating=1.0
      // Weighted: 0.4*1 + 0.3*0 + 0.2*0.375 + 0.1*1 = 0.575
      expect(score, closeTo(0.575, 0.01));
    });

    test('scoreJobForWorker handles budget mismatch', () {
      final workerLocation = GeoPoint(24.8607, 67.0011);
      final jobLocation = GeoPoint(24.8607, 67.0011);
      
      final score = service.scoreJobForWorker(
        workerLocation: workerLocation,
        jobLocation: jobLocation,
        workerCategory: JobCategory.plumbing,
        jobCategory: JobCategory.plumbing,
        workerMinBudget: 1000,
        workerMaxBudget: 1500, // Too low for job
        jobBudgetMin: 5000,
        jobBudgetMax: 10000,
        workerRating: 5.0,
      );
      
      // Budget ranges don't overlap => budgetScore = 0
      // Weighted: 0.4*1 + 0.3*1 + 0.2*0 + 0.1*1 = 0.8
      expect(score, closeTo(0.8, 0.01));
    });

    test('WorkerMatch holds correct data', () {
      const match = WorkerMatch(
        workerId: 'worker123',
        workerName: 'John Doe',
        workerRating: 4.5,
        distanceKm: 5.2,
        score: 0.85,
      );
      
      expect(match.workerId, 'worker123');
      expect(match.workerName, 'John Doe');
      expect(match.workerRating, 4.5);
      expect(match.distanceKm, 5.2);
      expect(match.score, 0.85);
    });
  });
}