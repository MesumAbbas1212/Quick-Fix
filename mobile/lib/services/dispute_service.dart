import 'package:quickfix/services/notification_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quickfix/models/dispute_case.dart';
import 'package:quickfix/models/payment_model.dart';
import 'package:quickfix/services/network_status_service.dart';
class DisputeService {
  final FirebaseFirestore? _injectedFirestore;
  final NetworkStatusService _network;
  DisputeService({FirebaseFirestore? firestore, NetworkStatusService? networkStatusService}) : _injectedFirestore = firestore, _network = networkStatusService ?? NetworkStatusService.instance;
  late final FirebaseFirestore _firestore = _injectedFirestore ?? FirebaseFirestore.instance;
  Future<DisputeCase?> getForJob(String id) async {
    final snapshot = await _firestore.collection('disputes').doc(id).get().timeout(const Duration(seconds: 8));
    return snapshot.exists ? DisputeCase.fromMap(snapshot.data()!, snapshot.id) : null;
  }
  Stream<DisputeCase?> watchForJob(String id) => _firestore.collection('disputes').doc(id).snapshots().trackNetwork(status: _network)
    .map((snapshot) => snapshot.exists ? DisputeCase.fromMap(snapshot.data()!, snapshot.id) : null);
  static double paidTotal(Iterable<Payment> receipts) => receipts.where((payment) => payment.status == 'paid' && payment.amount.isFinite && payment.amount >= 0).fold(0, (total, payment) => total + payment.amount);
  Future<void> submit({required String jobId, required String raisedBy, required String category, required String description, required String expectedResolution, required List<String> images}) async {
    if (!DisputeCase.categories.contains(category) || !DisputeCase.resolutions.contains(expectedResolution) || description.trim().length < 20 || description.length > 2000 || images.length > 5) throw ArgumentError('Add the issue, resolution and meaningful details.');
    final caseRef = _firestore.collection('disputes').doc(jobId); final jobRef = _firestore.collection('jobs').doc(jobId); final reportRef = _firestore.collection('reports').doc();
    await _firestore.runTransaction<void>((transaction) async {
      final job = (await transaction.get(jobRef)).data(); final existing = await transaction.get(caseRef);
      if (job == null || job['anonymized'] == true || job['status'] != 'completed' || (job['userId'] != raisedBy && job['workerId'] != raisedBy)) throw StateError('Only a completed-job participant can open a case.');
      final against = job['userId'] == raisedBy ? job['workerId'] : job['userId'];
      if (against is! String || against.isEmpty || against == 'deleted-account' || against == raisedBy) throw StateError('The counterparty is unavailable.');
      if (existing.exists) return; // One case per job, never duplicate an uncertain submission.
      final created = FieldValue.serverTimestamp();
      transaction.set(caseRef, {'jobId': jobId, 'raisedBy': raisedBy, 'againstId': against, 'category': category, 'description': description.trim(),
        'expectedResolution': expectedResolution, 'images': images, 'reportId': reportRef.id, 'status': 'open', 'createdAt': created});
      transaction.set(reportRef, {'reporterId': raisedBy, 'reportedId': against, 'jobId': jobId, 'disputeId': jobId, 'reason': 'Dispute: $category',
        'details': '${description.trim()}\nRequested resolution: $expectedResolution', 'status': 'open', 'createdAt': created});
      NotificationService(firestore: _firestore).addToTransaction(transaction, userId: against, type: 'dispute', refId: jobId, title: 'Job dispute submitted', body: 'A participant opened a completed-job case for manual review.');
    }).timeout(const Duration(seconds: 12));
  }
}
