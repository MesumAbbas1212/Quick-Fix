import 'package:quickfix/services/network_status_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:quickfix/models/job_model.dart';
import 'package:quickfix/models/worker_profile.dart';

class ProfileService {
  final FirebaseFirestore _firestore;
  final NetworkStatusService _network;

  ProfileService({FirebaseFirestore? firestore, NetworkStatusService? networkStatusService})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _network = networkStatusService ?? NetworkStatusService.instance;

  CollectionReference<Map<String, dynamic>> get _workersCollection =>
      _firestore.collection('workers');

  // Create or update worker profile
  Future<void> saveWorkerProfile(WorkerProfile profile) async {
    final fields = profile.toMap();
    // Identity/profile edits must never overwrite server/admin-owned trust or
    // aggregate fields copied from an older screen snapshot.
    for (final key in ['verification', 'rating', 'reviews', 'completedJobs']) { fields.remove(key); }
    await _workersCollection.doc(profile.uid).set(fields, SetOptions(merge: true));
  }

  /// Keeps the worker-facing identity fields (name, avatar, phone) in the
  /// `workers` collection in sync with edits made in `users`, so screens
  /// reading the workers collection never show a stale name or photo.
  Future<void> syncWorkerIdentity({
    required String uid,
    String? fullName,
    String? avatarUrl,
    String? phone,
  }) async {
    final updates = <String, dynamic>{
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    };
    if (fullName != null) updates['fullName'] = fullName;
    if (avatarUrl != null) updates['avatarUrl'] = avatarUrl;
    if (phone != null) updates['phone'] = phone;
    await _workersCollection.doc(uid).set(updates, SetOptions(merge: true));
  }

  // Get worker profile
  Future<WorkerProfile?> getWorkerProfile(String uid) async {
    final doc = await _workersCollection.doc(uid).get();
    if (!doc.exists) return null;
    return WorkerProfile.fromMap(doc.data()!, doc.id);
  }

  // Live worker profile stream
  Stream<WorkerProfile?> watchWorkerProfile(String uid) {
    return _workersCollection
        .doc(uid)
        .snapshots().trackNetwork(status: _network)
        .map((doc) =>
            doc.exists ? WorkerProfile.fromMap(doc.data()!, doc.id) : null);
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
    bool onlyAvailable = false,
    int limit = 20,
  }) async {
    Query<Map<String, dynamic>> query = _workersCollection;

    if (profession != null) {
      query = query.where('professions', arrayContains: profession.name);
    }

    final snapshot = await query.limit(limit).get();

    var workers = snapshot.docs
        .map((doc) => WorkerProfile.fromMap(doc.data(), doc.id))
        .toList();

    if (onlyAvailable) {
      workers = workers.where((w) => w.isAvailable).toList();
    }

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