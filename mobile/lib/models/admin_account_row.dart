import 'package:cloud_firestore/cloud_firestore.dart';

class AdminAccountRow {
  final String uid;
  final String name;
  final String email;
  final String role;
  final String? avatarUrl;
  final bool blocked;
  final bool approved;
  final double rating;
  final int completedJobs;
  final int completedInYear;
  final String verificationStatus;
  final DateTime? createdAt;
  const AdminAccountRow({required this.uid, required this.name, required this.email, required this.role, this.avatarUrl, this.blocked = false, this.approved = false, this.rating = 0, this.completedJobs = 0, this.completedInYear = 0, this.verificationStatus = 'notStarted', this.createdAt});
  factory AdminAccountRow.fromMaps(String uid, Map<String, dynamic> user, {Map<String, dynamic>? worker, int completedInYear = 0}) => AdminAccountRow(
    uid: uid, name: (user['fullName'] ?? worker?['fullName'] ?? '').toString(), email: (user['email'] ?? worker?['email'] ?? '').toString(),
    role: (user['role'] ?? 'worker').toString(), avatarUrl: (user['avatarUrl'] ?? worker?['avatarUrl'])?.toString(),
    blocked: user['blocked'] == true || worker?['blocked'] == true, approved: worker?['approved'] == true,
    rating: ((worker?['rating'] ?? user['rating']) as num?)?.toDouble() ?? 0,
    completedJobs: ((worker?['completedJobs'] ?? user['completedJobs']) as num?)?.toInt() ?? 0,
    completedInYear: completedInYear,
    verificationStatus: ((worker?['verification'] is Map ? worker?['verification']['status'] : null) ?? 'notStarted').toString(),
    createdAt: user['createdAt'] is Timestamp ? (user['createdAt'] as Timestamp).toDate() : worker?['createdAt'] is Timestamp ? (worker?['createdAt'] as Timestamp).toDate() : null,
  );
}
