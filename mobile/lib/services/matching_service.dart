import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:quickfix/shared/models/job_model.dart';
import 'package:quickfix/services/job_service.dart';

class MatchingService {
  static const double _maxDistanceKm = 50.0;
  static const double _distanceWeight = 0.4;
  static const double _categoryWeight = 0.3;
  static const double _budgetWeight = 0.2;
  static const double _ratingWeight = 0.1;

  // Classify image using ML Kit
  Future<List<ImageLabel>> classifyImage(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final labeler = ImageLabeler(options: ImageLabelerOptions());
    final labels = await labeler.processImage(inputImage);
    await labeler.close();
    return labels;
  }

  // Calculate distance between two GeoPoints in km
  double calculateDistance(GeoPoint point1, GeoPoint point2) {
    return Geolocator.distanceBetween(
      point1.latitude,
      point1.longitude,
      point2.latitude,
      point2.longitude,
    ) / 1000; // Convert to km
  }

  // Score a job for a worker based on multiple factors
  double scoreJobForWorker({
    required GeoPoint workerLocation,
    required GeoPoint jobLocation,
    required JobCategory workerCategory,
    required JobCategory jobCategory,
    required double workerMinBudget,
    required double workerMaxBudget,
    required double jobBudgetMin,
    required double jobBudgetMax,
    required double workerRating,
  }) {
    final distanceKm = calculateDistance(workerLocation, jobLocation);
    
    // Distance score (closer is better, max 50km)
    double distanceScore = 0;
    if (distanceKm <= _maxDistanceKm) {
      distanceScore = 1.0 - (distanceKm / _maxDistanceKm);
    }

    // Category match score
    double categoryScore = workerCategory == jobCategory ? 1.0 : 0.0;

    // Budget match score
    double budgetScore = 0;
    if (jobBudgetMax >= workerMinBudget && jobBudgetMin <= workerMaxBudget) {
      final overlap = (jobBudgetMax - jobBudgetMin).abs();
      final range = (workerMaxBudget - workerMinBudget).abs();
      budgetScore = overlap / range;
      budgetScore = budgetScore.clamp(0.0, 1.0);
    }

    // Rating score (normalized to 0-1)
    double ratingScore = (workerRating / 5.0).clamp(0.0, 1.0);

    // Weighted total
    return (distanceScore * _distanceWeight) +
        (categoryScore * _categoryWeight) +
        (budgetScore * _budgetWeight) +
        (ratingScore * _ratingWeight);
  }

  // Find best matching workers for a job
  Future<List<WorkerMatch>> findMatchingWorkers({
    required String jobId,
    required GeoPoint jobLocation,
    required JobCategory jobCategory,
    required double jobBudgetMin,
    required double jobBudgetMax,
    int limit = 10,
  }) async {
    final firestore = FirebaseFirestore.instance;
    
    // Query workers with matching category
    final workersQuery = await firestore
        .collection('users')
        .where('role', isEqualTo: 'worker')
        .where('preferredCategories', arrayContains: jobCategory.name)
        .limit(50)
        .get();

    final matches = <WorkerMatch>[];

    for (final doc in workersQuery.docs) {
      final data = doc.data();
      final location = data['location'] as GeoPoint?;
      final minBudget = (data['minBudget'] ?? 0).toDouble();
      final maxBudget = (data['maxBudget'] ?? 100000).toDouble();
      final rating = (data['rating'] ?? 0.0).toDouble();

      if (location == null) continue;

      final score = scoreJobForWorker(
        workerLocation: location,
        jobLocation: jobLocation,
        workerCategory: jobCategory,
        jobCategory: jobCategory,
        workerMinBudget: minBudget,
        workerMaxBudget: maxBudget,
        jobBudgetMin: jobBudgetMin,
        jobBudgetMax: jobBudgetMax,
        workerRating: rating,
      );

      if (score > 0.1) { // Minimum threshold
        matches.add(WorkerMatch(
          workerId: doc.id,
          workerName: data['fullName'] ?? 'Worker',
          workerRating: rating,
          distanceKm: calculateDistance(location, jobLocation),
          score: score,
        ));
      }
    }

    // Sort by score descending
    matches.sort((a, b) => b.score.compareTo(a.score));
    return matches.take(limit).toList();
  }

  // Auto-assign job to best available worker
  Future<String?> autoAssignJob(String jobId) async {
    final jobService = JobService();
    final job = await jobService.getJob(jobId);
    if (job == null || job.status != JobStatus.open) return null;

    final matches = await findMatchingWorkers(
      jobId: jobId,
      jobLocation: job.location,
      jobCategory: job.category,
      jobBudgetMin: job.budgetMin,
      jobBudgetMax: job.budgetMax,
      limit: 1,
    );

    if (matches.isNotEmpty) {
      final bestWorker = matches.first;
      await jobService.assignJob(jobId, bestWorker.workerId);
      return bestWorker.workerId;
    }

    return null;
  }
}

class WorkerMatch {
  final String workerId;
  final String workerName;
  final double workerRating;
  final double distanceKm;
  final double score;

  const WorkerMatch({
    required this.workerId,
    required this.workerName,
    required this.workerRating,
    required this.distanceKm,
    required this.score,
  });
}