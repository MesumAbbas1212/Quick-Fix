/// Cleanup deliberately uses replacement maps (not merge) so unknown legacy
/// free-text/identity fields cannot survive anonymization by accident.
class AccountDeletionPolicy {
  static const deletedAccount = 'deleted-account';
  static bool isActiveJob(Map<String, dynamic> data) => const {'assigned', 'inProgress'}.contains(data['status']);
  static Map<String, dynamic>? retainedJob(Map<String, dynamic> data, String uid) {
    if (data['userId'] != uid && data['workerId'] != uid) throw ArgumentError('Not a participant.');
    if (isActiveJob(data)) throw StateError('Active work must be completed or cancelled first.');
    final other = data['userId'] == uid ? data['workerId'] : data['userId'];
    if (data['status'] != 'completed' || other is! String || other.isEmpty || other == uid || other == deletedAccount) return null;
    return {
      'userId': data['userId'] == uid ? deletedAccount : data['userId'],
      'workerId': data['workerId'] == uid ? deletedAccount : data['workerId'],
      'title': 'Completed job', 'status': 'completed', 'anonymized': true,
      for (final key in ['category', 'budgetMin', 'budgetMax', 'preferredDate', 'preferredTime', 'createdAt', 'updatedAt', 'assignedAt', 'completedAt', 'paymentStatus'])
        if (data.containsKey(key)) key: data[key],
    };
  }
  static Map<String, dynamic> retainedPayout(Map<String, dynamic> data, String uid) {
    if (data['workerId'] != uid) throw ArgumentError('Not your withdrawal.');
    return {'workerId': deletedAccount, 'anonymized': true, for (final key in ['amount', 'amountPaisa', 'method', 'status', 'createdAt']) if (data.containsKey(key)) key: data[key]};
  }
  static Map<String, dynamic> retainedReceipt(Map<String, dynamic> data, String uid) {
    if (data['payerId'] != uid && data['workerId'] != uid) throw ArgumentError('Not a receipt participant.');
    return {
      'payerId': data['payerId'] == uid ? deletedAccount : data['payerId'],
      'workerId': data['workerId'] == uid ? deletedAccount : data['workerId'],
      'anonymized': true,
      for (final key in ['jobId', 'amount', 'status', 'method', 'createdAt']) if (data.containsKey(key)) key: data[key],
    };
  }
}

class AccountDeletionException implements Exception {
  final String message;
  const AccountDeletionException(this.message);
  @override
  String toString() => message;
}
