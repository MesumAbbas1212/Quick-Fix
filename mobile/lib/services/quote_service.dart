import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quickfix/models/job_model.dart';
import 'package:quickfix/models/location_selection.dart';
import 'package:quickfix/models/quote_inquiry.dart';
import 'package:quickfix/models/worker_profile.dart';
import 'package:quickfix/services/job_service.dart';
import 'package:quickfix/services/location_service.dart';
import 'package:quickfix/services/network_status_service.dart';
import 'package:quickfix/services/notification_service.dart';
import 'package:quickfix/services/profile_service.dart';

/// Server feature flag defaults OFF until A1–A4 are validated. This is not
/// production quote delivery: recipients come from the existing bounded pool.
class QuoteService {
  final FirebaseFirestore? _injectedFirestore;
  final ProfileService? _injectedProfiles;
  final JobService? _injectedJobs;
  final NetworkStatusService _network;
  QuoteService({FirebaseFirestore? firestore, ProfileService? profileService, JobService? jobService, NetworkStatusService? networkStatusService})
    : _injectedFirestore = firestore, _injectedProfiles = profileService, _injectedJobs = jobService, _network = networkStatusService ?? NetworkStatusService.instance;
  late final FirebaseFirestore _firestore = _injectedFirestore ?? FirebaseFirestore.instance;
  late final ProfileService _profiles = _injectedProfiles ?? ProfileService(firestore: _firestore);
  late final JobService _jobs = _injectedJobs ?? JobService(firestore: _firestore);
  String newInquiryId() => _firestore.collection('quoteRequests').doc().id;
  Future<bool> isEnabled() async {
    try { return (await _firestore.collection('config').doc('features').get(const GetOptions(source: Source.server)).timeout(const Duration(seconds: 3))).data()?['quotesEnabled'] == true; }
    catch (_) { return false; }
  }
  Future<void> _requireEnabled() async { if (!await isEnabled()) throw StateError('Quotes are gated until operator validation.'); }
  static String quoteId(String requestId, String workerId) => base64Url.encode(utf8.encode(jsonEncode([requestId, workerId]))).replaceAll('=', '');
  static GeoPoint approximate(GeoPoint exact) => GeoPoint(double.parse(exact.latitude.toStringAsFixed(2)), double.parse(exact.longitude.toStringAsFixed(2)));
  Future<List<WorkerProfile>> candidates({required String clientId, required JobCategory category, required GeoPoint location, required double radiusKm}) async {
    if (!LocationSelection.valid(location) || !radiusKm.isFinite || radiusKm < 1 || radiusKm > 100) throw ArgumentError('Choose a pin and radius.');
    final workers = (await _profiles.searchWorkers(profession: category, fromLocation: location, maxDistanceKm: radiusKm, onlyAvailable: true, limit: 500).timeout(const Duration(seconds: 12)))
      .where((worker) => worker.uid != clientId && worker.location != null && worker.isAvailable && worker.professions.contains(category) && (LocationService.distanceKm(worker.location, location) ?? double.infinity) <= radiusKm).toList();
    workers.sort((a, b) => LocationService.distanceKm(a.location, location)!.compareTo(LocationService.distanceKm(b.location, location)!));
    return workers.take(10).toList(); // Atomic invite writes stay within Rules access budgets.
  }
  Future<String> create({required String clientId, required JobCategory category, required String description, required List<String> images,
    required LocationSelection location, required double radiusKm, required List<String> expectedRecipients, String? requestId}) async {
    await _requireEnabled();
    if (description.trim().length < 20 || description.length > 2000 || images.length > 5 || location.address.trim().isEmpty || location.address.length > 500) throw ArgumentError('Describe the work and use up to five photos.');
    final ref = _firestore.collection('quoteRequests').doc(requestId);
    if (requestId != null) {
      final previous = await ref.get(const GetOptions(source: Source.server)).timeout(const Duration(seconds: 8));
      if (previous.exists) { if (previous.data()?['clientId'] != clientId) throw StateError('Foreign inquiry.'); return ref.id; }
    }
    final recipients = (await candidates(clientId: clientId, category: category, location: location.location, radiusKm: radiusKm)).map((worker) => worker.uid).toList();
    if (recipients.isEmpty || recipients.length != expectedRecipients.toSet().length || !recipients.every(expectedRecipients.contains)) throw StateError('Recipient availability changed. Refresh the count and confirm again.');
    await _firestore.runTransaction<void>((transaction) async {
      final previous = await transaction.get(ref);
      if (previous.exists) { if (previous.data()?['clientId'] != clientId) throw StateError('Foreign inquiry.'); return; }
      transaction.set(ref, {'clientId': clientId, 'category': category.name, 'description': description.trim(), 'images': images,
        'location': approximate(location.location), 'radiusKm': radiusKm, 'recipientIds': recipients, 'status': 'open', 'createdAt': FieldValue.serverTimestamp()});
      transaction.set(ref.collection('private').doc('location'), {'address': location.address, 'location': location.location});
      for (final uid in recipients) { NotificationService(firestore: _firestore).addToTransaction(transaction, userId: uid, type: 'quote', refId: ref.id,
        title: 'Quote request nearby', body: 'You were invited to reply with a price. Open the request for shared work details.'); }
    }).timeout(const Duration(seconds: 12)); return ref.id;
  }
  Stream<List<QuoteInquiry>> watchOwned(String uid) => _firestore.collection('quoteRequests').where('clientId', isEqualTo: uid).orderBy('createdAt', descending: true).limit(50).snapshots().trackNetwork(status: _network)
    .map((snapshot) => snapshot.docs.map((doc) => QuoteInquiry.fromMap(doc.data(), doc.id)).toList());
  Stream<List<QuoteInquiry>> watchInvites(String uid) => _firestore.collection('quoteRequests').where('recipientIds', arrayContains: uid).orderBy('createdAt', descending: true).limit(50).snapshots().trackNetwork(status: _network)
    .map((snapshot) => snapshot.docs.map((doc) => QuoteInquiry.fromMap(doc.data(), doc.id)).toList());
  Stream<QuoteInquiry?> watchRequest(String id) => _firestore.collection('quoteRequests').doc(id).snapshots().trackNetwork(status: _network).map((snapshot) => snapshot.exists ? QuoteInquiry.fromMap(snapshot.data()!, snapshot.id) : null);
  Stream<List<WorkerQuote>> watchQuotes(String requestId, String uid, {required bool owner}) {
    Query<Map<String, dynamic>> query = _firestore.collection('quotes').where('requestId', isEqualTo: requestId);
    if (!owner) query = query.where('workerId', isEqualTo: uid);
    return query.snapshots().trackNetwork(status: _network).map((snapshot) => snapshot.docs.map((doc) => WorkerQuote.fromMap(doc.data(), doc.id)).toList()..sort((a, b) => a.amount.compareTo(b.amount)));
  }
  Future<void> reply({required String requestId, required String workerId, required double amount, required String message}) async {
    await _requireEnabled();
    if (!amount.isFinite || amount <= 0 || amount > 1000000000 || ((amount * 100).round() - amount * 100).abs() > .0001 || message.trim().length < 5 || message.length > 1000) throw ArgumentError('Check price and message.');
    final requestRef = _firestore.collection('quoteRequests').doc(requestId); final quoteRef = _firestore.collection('quotes').doc(quoteId(requestId, workerId));
    await _firestore.runTransaction<void>((transaction) async {
      final data = (await transaction.get(requestRef)).data(); final previous = await transaction.get(quoteRef);
      if (data == null || data['status'] != 'open' || !(data['recipientIds'] as List).contains(workerId) || data['clientId'] == workerId) throw StateError('Invitation no longer open.');
      if (previous.exists) return;
      transaction.set(quoteRef, {'requestId': requestId, 'workerId': workerId, 'clientId': data['clientId'], 'amount': amount, 'amountPaisa': (amount * 100).round(), 'message': message.trim(), 'status': 'pending', 'createdAt': FieldValue.serverTimestamp()});
      NotificationService(firestore: _firestore).addToTransaction(transaction, userId: data['clientId'] as String, type: 'quote', refId: requestId,
        title: 'Quote reply received', body: 'A worker submitted a price. Open comparison before choosing.');
    }).timeout(const Duration(seconds: 12));
  }
  Future<String> accept({required String requestId, required String quoteId, required String clientId, required String title, required DateTime date, DateTime? time}) async {
    await _requireEnabled();
    if (title.trim().isEmpty || title.length > 120 || !JobService.validSchedule(date, time, DateTime.now())) throw ArgumentError('Choose a title and future schedule.');
    final reqRef = _firestore.collection('quoteRequests').doc(requestId); final replyRef = _firestore.collection('quotes').doc(quoteId); final jobRef = _firestore.collection('jobs').doc();
    return await _firestore.runTransaction<String>((transaction) async {
      final data = (await transaction.get(reqRef)).data(); final quote = (await transaction.get(replyRef)).data(); final pin = (await transaction.get(reqRef.collection('private').doc('location'))).data();
      if (data == null || data['clientId'] != clientId || quote == null || quote['requestId'] != requestId || quote['clientId'] != clientId) throw StateError('Only the requesting client can book this quote.');
      if (data['status'] == 'accepted' && data['acceptedQuoteId'] == quoteId && data['jobId'] is String) return data['jobId'] as String;
      if (data['status'] != 'open' || quote['status'] != 'pending' || pin == null || pin['location'] is! GeoPoint) throw StateError('Quote selection has changed.');
      final workerId = quote['workerId'] as String; final worker = await transaction.get(_firestore.collection('workers').doc(workerId));
      if (!worker.exists || worker.data()?['blocked'] == true) throw StateError('Worker is unavailable.');
      final amount = (quote['amount'] as num).toDouble(); final now = DateTime.now();
      final job = JobModel(id: jobRef.id, userId: clientId, workerId: workerId, title: title.trim(), description: data['description'] as String,
        category: JobCategory.values.firstWhere((category) => category.name == data['category'], orElse: () => JobCategory.other), address: pin['address'] as String? ?? '', location: pin['location'] as GeoPoint,
        budgetMin: amount, budgetMax: amount, preferredDate: DateTime(date.year, date.month, date.day), preferredTime: time == null ? null : DateTime(date.year, date.month, date.day, time.hour, time.minute),
        images: (data['images'] as List).whereType<String>().toList(), status: JobStatus.assigned, createdAt: now, updatedAt: now, assignedAt: now);
      _jobs.writeQuotedBooking(transaction, job: job, requestId: requestId, quoteId: quoteId);
      transaction.update(reqRef, {'status': 'accepted', 'acceptedQuoteId': quoteId, 'acceptedWorkerId': workerId, 'jobId': job.id, 'updatedAt': FieldValue.serverTimestamp()});
      transaction.update(replyRef, {'status': 'accepted'});
      NotificationService(firestore: _firestore).addToTransaction(transaction, userId: workerId, type: 'job', refId: job.id, title: 'Quote selected for a booking', body: 'The client chose your price and proposed a schedule. Confirm timing in Chat.');
      return job.id;
    }).timeout(const Duration(seconds: 15));
  }
}
