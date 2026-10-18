import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quickfix/models/worker_verification.dart';
import 'package:quickfix/services/local_image_store.dart';

class VerificationException implements Exception {
  final String message;
  const VerificationException(this.message);
  @override
  String toString() => message;
}
class VerificationService {
  final FirebaseFirestore? _injectedFirestore;
  final LocalImageStore? _injectedImageStore;
  VerificationService({FirebaseFirestore? firestore, LocalImageStore? imageStore})
      : _injectedFirestore = firestore, _injectedImageStore = imageStore;
  late final FirebaseFirestore _firestore = _injectedFirestore ?? FirebaseFirestore.instance;
  late final LocalImageStore _images = _injectedImageStore ?? const LocalImageStore();
  Future<WorkerVerification?> getVerification(String uid) async {
    final data = (await _firestore.collection('workerVerifications').doc(uid).get().timeout(const Duration(seconds: 10))).data();
    return data == null ? null : WorkerVerification.fromMap(data);
  }
  Future<void> submit({required String uid, required String cnicFrontPath, required String cnicBackPath,
    required String selfiePath, required bool consent}) async {
    if (!consent) throw const VerificationException('Please read and accept the verification consent first.');
    if (uid.isEmpty || [cnicFrontPath, cnicBackPath, selfiePath].any((path) => path.isEmpty)) {
      throw const VerificationException('Capture the CNIC front, CNIC back and selfie before submitting.');
    }
    final available = await Future.wait([for (final path in [cnicFrontPath, cnicBackPath, selfiePath])
      _images.hasVerificationImage(uid, path)]).timeout(const Duration(seconds: 5));
    if (available.any((value) => !value)) throw const VerificationException('One or more photos are missing on this device. Please recapture them.');
    final privateRef = _firestore.collection('workerVerifications').doc(uid);
    final workerRef = _firestore.collection('workers').doc(uid);
    await _firestore.runTransaction<void>((transaction) async {
      final private = await transaction.get(privateRef);
      final worker = await transaction.get(workerRef);
      if (!worker.exists) throw const VerificationException('Complete your worker profile before submitting verification.');
      final previous = private.data() == null ? const WorkerVerification() : WorkerVerification.fromMap(private.data()!);
      final publicStatus = (worker.data()?['verification'] as Map?)?['status'];
      if (!previous.canSubmit || publicStatus == 'verified' || publicStatus == 'pending') {
        throw const VerificationException('Verification is already pending or verified. Refresh its status before trying again.');
      }
      final submittedAt = FieldValue.serverTimestamp();
      transaction.set(privateRef, {
        'status': 'pending', 'cnicFrontPath': cnicFrontPath, 'cnicBackPath': cnicBackPath, 'selfiePath': selfiePath,
        'submittedAt': submittedAt, 'consent': true, 'consentVersion': '2026-10-local-demo-v1',
      });
      transaction.update(workerRef, {'verification': {'status': 'pending', 'submittedAt': submittedAt}, 'updatedAt': submittedAt});
    }).timeout(const Duration(seconds: 10));
  }
}
