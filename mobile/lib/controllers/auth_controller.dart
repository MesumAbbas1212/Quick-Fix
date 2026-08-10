import 'package:flutter/foundation.dart';

/// Minimal app-level auth state holder (spec deliverable: /lib/controllers).
class AuthController extends ChangeNotifier {
  String? _userId;
  String? _role;
  bool _isAuthenticated = false;

  String? get userId => _userId;
  String? get role => _role;
  bool get isAuthenticated => _isAuthenticated;

  void setSession({required String userId, required String role}) {
    _userId = userId;
    _role = role;
    _isAuthenticated = true;
    notifyListeners();
  }

  void clearSession() {
    _userId = null;
    _role = null;
    _isAuthenticated = false;
    notifyListeners();
  }
}