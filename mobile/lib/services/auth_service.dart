import 'package:quickfix/models/app_notification.dart';
import 'package:quickfix/models/account_deletion_policy.dart';
import 'package:quickfix/services/account_deletion_service.dart';
import 'package:quickfix/services/network_status_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quickfix/models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final NetworkStatusService _network;

  AuthService({FirebaseAuth? auth, FirebaseFirestore? firestore, NetworkStatusService? networkStatusService})
      : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _network = networkStatusService ?? NetworkStatusService.instance;

  // Stream of auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Current user
  User? get currentUser => _auth.currentUser;

  // Sign in with email and password
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return credential;
    } on FirebaseAuthException catch (e) {
      throw _mapAuthException(e);
    }
  }

  // Register with email and password
  Future<UserCredential> registerWithEmailAndPassword({
    required String email,
    required String password,
    required String fullName,
    required String phone,
    required UserRole role,
    String language = 'en',
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      if (credential.user != null) {
        await _createUserProfile(
          uid: credential.user!.uid,
          email: email.trim(),
          fullName: fullName,
          phone: phone,
          role: role,
          language: language,
        );
      }

      return credential;
    } on FirebaseAuthException catch (e) {
      throw _mapAuthException(e);
    }
  }

  // Create user profile in Firestore
  Future<void> _createUserProfile({
    required String uid,
    required String email,
    required String fullName,
    required String phone,
    required UserRole role,
    String language = 'en',
  }) async {
    final userData = UserModel(
      uid: uid,
      email: email,
      fullName: fullName,
      phone: phone,
      role: role,
      avatarUrl: null,
      rating: 0.0,
      completedJobs: 0,
      preferredLanguage: language,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await _firestore.collection('users').doc(uid).set(userData.toMap());
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
    _network.reset();
  }

  // Send a password reset email
  Future<void> sendPasswordReset({required String email}) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw _mapAuthException(e);
    }
  }

  // Get user profile
  Future<UserModel?> getUserProfile(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    final current = _auth.currentUser;
    var pending = false;
    if (current?.uid == uid) {
      try { pending = (await _firestore.collection('accountDeletions').doc(uid).get(const GetOptions(source: Source.server)).timeout(const Duration(seconds: 3))).exists; }
      catch (_) { if (!doc.exists) rethrow; /* Cached profiles can still be read offline. */ }
    }
    if (!doc.exists) {
      if (!pending || current == null) return null;
      return UserModel(uid: uid, email: current.email ?? '', fullName: 'Account deletion pending', phone: '',
        role: UserRole.user, deletionPending: true, createdAt: DateTime.now(), updatedAt: DateTime.now());
    }
    return UserModel.fromMap(doc.data()!, doc.id).copyWith(deletionPending: pending);
  }

  // Live user profile stream
  Stream<UserModel?> watchUser(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .snapshots().trackNetwork(status: _network)
        .map((doc) =>
            doc.exists ? UserModel.fromMap(doc.data()!, doc.id) : null);
  }

  // Update user profile
  Future<void> updateProfile({
    required String uid,
    String? fullName,
    String? phone,
    String? avatarUrl,
    String? preferredLanguage,
    NotificationPrefs? notificationPrefs,
  }) async {
    final updates = <String, dynamic>{
      'updatedAt': DateTime.now(),
    };

    if (notificationPrefs != null) updates['notificationPrefs'] = notificationPrefs.toMap();
    if (fullName != null) updates['fullName'] = fullName;
    if (phone != null) updates['phone'] = phone;
    if (avatarUrl != null) updates['avatarUrl'] = avatarUrl;
    if (preferredLanguage != null) {
      updates['preferredLanguage'] = preferredLanguage;
    }

    await _firestore.collection('users').doc(uid).update(updates);
  }

  Future<void> updateNotificationPreference({required String uid, required String key, required bool value}) async {
    if (!const {'jobUpdates', 'messages', 'promotions'}.contains(key)) throw ArgumentError('Unknown preference.');
    await _firestore.collection('users').doc(uid).update({'notificationPrefs.$key': value, 'updatedAt': FieldValue.serverTimestamp()})
      .timeout(const Duration(seconds: 10));
  }
  Future<void> requestCurrentPasswordReset(String uid) async {
    final current = _auth.currentUser;
    if (current == null || current.uid != uid || current.email == null) throw StateError('Sign in to this account first.');
    await sendPasswordReset(email: current.email!).timeout(const Duration(seconds: 10));
  }

  // Update user role (worker <-> user)
  Future<void> updateUserRole(String uid, UserRole role) async {
    await _firestore.collection('users').doc(uid).update({
      'role': role.name,
      'updatedAt': DateTime.now(),
    });
  }

  // Preserve the existing entry point, but never silently delete without
  // reauthentication or skip worker/content cleanup. Use DeleteAccountScreen.
  Future<void> deleteAccount({String? password}) async {
    final user = _auth.currentUser;
    if (user == null || password == null || password.isEmpty) {
      throw const AccountDeletionException('Open Settings → Delete account and re-enter your password before deleting.');
    }
    await AccountDeletionService(auth: _auth, firestore: _firestore, networkStatusService: _network)
      .deleteAccount(uid: user.uid, password: password);
  }

  // Map FirebaseAuthException to user-friendly messages
  Exception _mapAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return Exception('No user found with this email.');
      case 'wrong-password':
        return Exception('Incorrect password.');
      case 'email-already-in-use':
        return Exception('An account already exists with this email.');
      case 'weak-password':
        return Exception('Password is too weak. Use at least 6 characters.');
      case 'invalid-email':
        return Exception('Invalid email address.');
      case 'user-disabled':
        return Exception('This account has been disabled.');
      case 'too-many-requests':
        return Exception('Too many attempts. Please try again later.');
      case 'operation-not-allowed':
        return Exception('This sign-in method is not enabled.');
      default:
        return Exception('Authentication failed: ${e.message}');
    }
  }
}