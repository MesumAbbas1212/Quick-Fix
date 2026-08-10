import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:quickfix/models/job_model.dart';
import 'package:quickfix/models/worker_profile.dart';

class ProfileService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _workersCollection =>
      _firestore.collection('workers');

  // Create or update worker profile
  Future<void> saveWorkerProfile(WorkerProfile profile) async {
    await _workersCollection.doc(profile.uid).set(profile.toMap());
  }

  // Get worker profile
  Future<WorkerProfile?> getWorkerProfile(String uid) async {
    final doc = await _workersCollection.doc(uid).get();
    if (!doc.exists) return null;
    return WorkerProfile.fromMap(doc.data()!, doc.id);
  }

  // Update worker availability
  Future<void> setAvailability(String uid, bool isAvailable) async {
    await _workersCollection.doc(uid).update({
      'isAvailable': isAvailable,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  // Update worker location
  Future<void> updateLocation(String uid, GeoPoint location) async {
    await _workersCollection.doc(uid).update({
      'location': location,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  // Get worker's current position
  Future<Position?> getCurrentPosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }

    return await Geolocator.getCurrentPosition();
  }

  // Update worker rating after a job completes
  Future<void> updateRating(String uid, double rating, int reviews) async {
    await _workersCollection.doc(uid).update({
      'rating': rating,
      'reviews': reviews,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  // Increment completed jobs count
  Future<void> incrementCompletedJobs(String uid) async {
    await _workersCollection.doc(uid).update({
      'completedJobs': FieldValue.increment(1),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  // Search workers by profession/category
  Future<List<WorkerProfile>> searchWorkers({
    JobCategory? profession,
    double? maxDistanceKm,
    GeoPoint? fromLocation,
    int limit = 20,
  }) async {
    Query<Map<String, dynamic>> query = _workersCollection;

    if (profession != null) {
      query = query.where('professions', arrayContains: profession.name);
    }

    if (fromLocation != null) {
      query = query.where('isAvailable', isEqualTo: true);
    }

    final snapshot = await query.limit(limit).get();

    final workers = snapshot.docs
        .map((doc) => WorkerProfile.fromMap(doc.data(), doc.id))
        .toList();

    // Filter by distance if requested
    if (maxDistanceKm != null && fromLocation != null) {
      return workers.where((worker) {
        if (worker.location == null) return false;
        final distance = Geolocator.distanceBetween(
          fromLocation.latitude,
          fromLocation.longitude,
          worker.location!.latitude,
          worker.location!.longitude,
        ) / 1000;
        return distance <= maxDistanceKm;
      }).toList();
    }

    return workers;
  }
}