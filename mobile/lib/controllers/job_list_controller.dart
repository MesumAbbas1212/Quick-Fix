import 'package:flutter/foundation.dart';
import 'package:quickfix/models/job_model.dart';

/// Holds the currently displayed job list (find-jobs feed).
class JobListController extends ChangeNotifier {
  List<JobModel> _jobs = [];
  bool _isLoading = false;

  List<JobModel> get jobs => _jobs;
  bool get isLoading => _isLoading;

  void setJobs(List<JobModel> jobs) {
    _jobs = jobs;
    notifyListeners();
  }

  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
}