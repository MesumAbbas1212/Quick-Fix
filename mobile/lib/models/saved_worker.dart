import 'package:quickfix/models/worker_profile.dart';

/// Keep the ID even when a worker was removed so the stale bookmark is removable.
class SavedWorker {
  final String uid;
  final WorkerProfile? profile;
  const SavedWorker({required this.uid, this.profile});
}
