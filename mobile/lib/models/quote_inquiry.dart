import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quickfix/models/job_model.dart';
class QuoteInquiry {
  final String id, clientId, description, status;
  final JobCategory category;
  final List<String> images, recipientIds;
  final String? jobId, acceptedQuoteId, acceptedWorkerId;
  final GeoPoint? approximateLocation;
  const QuoteInquiry({required this.id, required this.clientId, required this.description, required this.status, required this.category,
    this.images = const [], this.recipientIds = const [], this.jobId, this.acceptedQuoteId, this.acceptedWorkerId, this.approximateLocation});
  factory QuoteInquiry.fromMap(Map<String, dynamic> data, String id) => QuoteInquiry(id: id, clientId: data['clientId'] as String? ?? '', description: data['description'] as String? ?? '',
    status: data['status'] as String? ?? 'open', category: JobCategory.values.firstWhere((category) => category.name == data['category'], orElse: () => JobCategory.other),
    images: (data['images'] is List ? data['images'] as List : const []).whereType<String>().toList(), recipientIds: (data['recipientIds'] is List ? data['recipientIds'] as List : const []).whereType<String>().toList(),
    jobId: data['jobId'] as String?, acceptedQuoteId: data['acceptedQuoteId'] as String?, acceptedWorkerId: data['acceptedWorkerId'] as String?, approximateLocation: data['location'] as GeoPoint?);
}
class WorkerQuote {
  final String id, requestId, workerId, clientId, message, status;
  final double amount;
  const WorkerQuote({required this.id, required this.requestId, required this.workerId, required this.clientId, required this.message, required this.status, required this.amount});
  factory WorkerQuote.fromMap(Map<String, dynamic> data, String id) => WorkerQuote(id: id, requestId: data['requestId'] as String? ?? '', workerId: data['workerId'] as String? ?? '', clientId: data['clientId'] as String? ?? '',
    message: data['message'] as String? ?? '', status: data['status'] as String? ?? 'pending', amount: (data['amount'] as num?)?.toDouble() ?? 0);
}
