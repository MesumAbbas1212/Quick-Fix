import 'package:cloud_firestore/cloud_firestore.dart';
class DisputeCase {
  final String id, jobId, raisedBy, againstId, category, description, expectedResolution, status;
  final List<String> images;
  final DateTime? createdAt;
  final String? resolutionNote;
  const DisputeCase({required this.id, required this.jobId, required this.raisedBy, required this.againstId, required this.category,
    required this.description, required this.expectedResolution, required this.status, this.images = const [], this.resolutionNote, this.createdAt});
  static const categories = ['Work incomplete', 'Poor quality', 'Damaged property', 'Overcharged', 'No-show'];
  static const resolutions = ['Redo the work', 'Partial refund', 'Full refund', 'Other'];
  factory DisputeCase.fromMap(Map<String, dynamic> data, String id) => DisputeCase(id: id, jobId: data['jobId'] as String? ?? id,
    raisedBy: data['raisedBy'] as String? ?? '', againstId: data['againstId'] as String? ?? '', category: data['category'] as String? ?? '', description: data['description'] as String? ?? '',
    expectedResolution: data['expectedResolution'] as String? ?? '', status: data['status'] as String? ?? 'open', createdAt: (data['createdAt'] as Timestamp?)?.toDate(), images: (data['images'] is List ? data['images'] as List : const []).whereType<String>().toList(), resolutionNote: data['resolutionNote'] as String?);
}
