import 'package:cloud_firestore/cloud_firestore.dart';

enum VerificationStatus { notStarted, pending, verified, rejected }
extension VerificationStatusLabel on VerificationStatus {
  String get label => switch (this) {
    VerificationStatus.notStarted => 'Not started', VerificationStatus.pending => 'Pending',
    VerificationStatus.verified => 'Verified', VerificationStatus.rejected => 'Rejected',
  };
}
VerificationStatus _status(Object? value) => VerificationStatus.values.firstWhere((status) => status.name == value,
  orElse: () => VerificationStatus.notStarted);
DateTime? _date(Object? value) => value is Timestamp ? value.toDate() : value is DateTime ? value : null;

/// Public worker data: never contains photo paths, CNIC numbers or review notes.
class VerificationSummary {
  final VerificationStatus status;
  final DateTime? submittedAt;
  final DateTime? reviewedAt;
  const VerificationSummary({this.status = VerificationStatus.notStarted, this.submittedAt, this.reviewedAt});
  factory VerificationSummary.fromMap(Map<String, dynamic> map) => VerificationSummary(
    status: _status(map['status']), submittedAt: _date(map['submittedAt']), reviewedAt: _date(map['reviewedAt']));
  Map<String, dynamic> toMap() => {'status': status.name,
    if (submittedAt != null) 'submittedAt': Timestamp.fromDate(submittedAt!),
    if (reviewedAt != null) 'reviewedAt': Timestamp.fromDate(reviewedAt!)};
}

/// Owner/admin-only document at workerVerifications/{uid}. Images themselves
/// remain in this device's app directory; remote admins cannot open these paths.
class WorkerVerification {
  final VerificationStatus status;
  final String? cnicFrontPath;
  final String? cnicBackPath;
  final String? selfiePath;
  final String? note;
  final DateTime? submittedAt;
  final DateTime? reviewedAt;
  const WorkerVerification({this.status = VerificationStatus.notStarted, this.cnicFrontPath,
    this.cnicBackPath, this.selfiePath, this.note, this.submittedAt, this.reviewedAt});
  bool get canSubmit => status == VerificationStatus.notStarted || status == VerificationStatus.rejected;
  factory WorkerVerification.fromMap(Map<String, dynamic> map) => WorkerVerification(
    status: _status(map['status']), cnicFrontPath: map['cnicFrontPath'] as String?,
    cnicBackPath: map['cnicBackPath'] as String?, selfiePath: map['selfiePath'] as String?, note: map['note'] as String?,
    submittedAt: _date(map['submittedAt']), reviewedAt: _date(map['reviewedAt']));
}
