import 'package:quickfix/models/job_model.dart';
import 'package:quickfix/models/review_model.dart';
class ClientJobActivity {
  final JobCategory category;
  final JobStatus status;
  final DateTime date;
  const ClientJobActivity({required this.category, required this.status, required this.date});
}
/// Public view projection deliberately has no email, phone, address, pin,
/// description or job title (free-text titles can contain exact addresses).
class ClientActivity {
  final String uid, name;
  final String? avatar;
  final DateTime since;
  final int posted, completed, cancelled;
  final double? averageGiven;
  final List<ClientJobActivity> jobs;
  final List<Review> reviews;
  const ClientActivity({required this.uid, required this.name, this.avatar, required this.since, required this.posted, required this.completed,
    required this.cancelled, this.averageGiven, this.jobs = const [], this.reviews = const []});
}
