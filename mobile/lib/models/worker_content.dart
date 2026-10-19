import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quickfix/models/job_model.dart';
class PortfolioWork {
  final String id, imagePath, caption;
  final JobCategory category;
  final DateTime? createdAt;
  const PortfolioWork({required this.id, required this.imagePath, required this.caption, required this.category, this.createdAt});
  factory PortfolioWork.fromMap(Map<String, dynamic> data, String fallback) => PortfolioWork(id: data['id'] as String? ?? fallback,
    imagePath: data['imagePath'] as String? ?? '', caption: data['caption'] as String? ?? '', category: JobCategory.values.firstWhere((category) => category.name == data['category'], orElse: () => JobCategory.other), createdAt: (data['createdAt'] as Timestamp?)?.toDate());
  Map<String, dynamic> toMap() => {'id': id, 'imagePath': imagePath, 'caption': caption, 'category': category.name, if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!)};
}
class WorkerCertificate {
  final String id, title, issuer, imagePath;
  final int year;
  const WorkerCertificate({required this.id, required this.title, required this.issuer, required this.year, this.imagePath = ''});
  factory WorkerCertificate.fromMap(Map<String, dynamic> data, String fallback) => WorkerCertificate(id: data['id'] as String? ?? fallback, title: data['title'] as String? ?? '',
    issuer: data['issuer'] as String? ?? '', year: (data['year'] as num?)?.toInt() ?? 0, imagePath: data['imagePath'] as String? ?? '');
  bool valid(int currentYear) => title.trim().isNotEmpty && title.length <= 120 && issuer.trim().isNotEmpty && issuer.length <= 120 && year >= 1970 && year <= currentYear;
  Map<String, dynamic> toMap() => {'id': id, 'title': title.trim(), 'issuer': issuer.trim(), 'year': year, 'imagePath': imagePath};
}
