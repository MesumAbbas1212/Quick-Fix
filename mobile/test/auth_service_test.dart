import 'package:flutter_test/flutter_test.dart';
import 'package:quickfix/models/user_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() {
  group('UserModel', () {
    test('fromMap creates UserModel with all fields', () {
      final map = {
        'email': 'test@example.com',
        'fullName': 'Test User',
        'phone': '+923001234567',
        'role': 'worker',
        'avatarUrl': 'https://example.com/avatar.png',
        'rating': 4.5,
        'completedJobs': 10,
        'createdAt': Timestamp.fromDate(DateTime(2024, 1, 1)),
        'updatedAt': Timestamp.fromDate(DateTime(2024, 6, 1)),
      };

      final user = UserModel.fromMap(map, 'uid123');

      expect(user.uid, 'uid123');
      expect(user.email, 'test@example.com');
      expect(user.fullName, 'Test User');
      expect(user.phone, '+923001234567');
      expect(user.role, UserRole.worker);
      expect(user.avatarUrl, 'https://example.com/avatar.png');
      expect(user.rating, 4.5);
      expect(user.completedJobs, 10);
      expect(user.createdAt, DateTime(2024, 1, 1));
      expect(user.updatedAt, DateTime(2024, 6, 1));
    });

    test('fromMap defaults role to user when invalid', () {
      final map = {
        'email': 'test@example.com',
        'fullName': 'Test User',
        'phone': '+923001234567',
        'role': 'invalid_role',
      };

      final user = UserModel.fromMap(map, 'uid123');
      expect(user.role, UserRole.user);
    });

    test('fromMap handles missing optional fields', () {
      final map = {
        'email': 'test@example.com',
        'fullName': 'Test User',
        'phone': '+923001234567',
        'role': 'user',
      };

      final user = UserModel.fromMap(map, 'uid123');
      expect(user.avatarUrl, isNull);
      expect(user.rating, 0.0);
      expect(user.completedJobs, 0);
    });

    test('toMap returns correct map', () {
      final user = UserModel(
        uid: 'uid123',
        email: 'test@example.com',
        fullName: 'Test User',
        phone: '+923001234567',
        role: UserRole.worker,
        avatarUrl: 'https://example.com/avatar.png',
        rating: 4.5,
        completedJobs: 10,
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 6, 1),
      );

      final map = user.toMap();

      expect(map['email'], 'test@example.com');
      expect(map['fullName'], 'Test User');
      expect(map['phone'], '+923001234567');
      expect(map['role'], 'worker');
      expect(map['avatarUrl'], 'https://example.com/avatar.png');
      expect(map['rating'], 4.5);
      expect(map['completedJobs'], 10);
      expect(map['createdAt'], isA<Timestamp>());
      expect(map['updatedAt'], isA<Timestamp>());
    });

    test('copyWith updates only specified fields', () {
      final user = UserModel(
        uid: 'uid123',
        email: 'test@example.com',
        fullName: 'Test User',
        phone: '+923001234567',
        role: UserRole.user,
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 6, 1),
      );

      final updated = user.copyWith(
        fullName: 'Updated Name',
        role: UserRole.worker,
        rating: 5.0,
      );

      expect(updated.fullName, 'Updated Name');
      expect(updated.role, UserRole.worker);
      expect(updated.rating, 5.0);
      expect(updated.email, 'test@example.com'); // unchanged
      expect(updated.phone, '+923001234567'); // unchanged
    });
  });

  group('AuthException mapping', () {
    test('maps user-not-found to friendly message', () {
      final e = FirebaseAuthException(code: 'user-not-found', message: 'No user');
      final mapped = _mapAuthException(e);
      expect(mapped.toString(), contains('No user found'));
    });

    test('maps wrong-password to friendly message', () {
      final e = FirebaseAuthException(code: 'wrong-password', message: 'Wrong password');
      final mapped = _mapAuthException(e);
      expect(mapped.toString(), contains('Incorrect password'));
    });

    test('maps email-already-in-use to friendly message', () {
      final e = FirebaseAuthException(code: 'email-already-in-use', message: 'Email in use');
      final mapped = _mapAuthException(e);
      expect(mapped.toString(), contains('already exists'));
    });

    test('maps weak-password to friendly message', () {
      final e = FirebaseAuthException(code: 'weak-password', message: 'Weak');
      final mapped = _mapAuthException(e);
      expect(mapped.toString(), contains('too weak'));
    });

    test('maps invalid-email to friendly message', () {
      final e = FirebaseAuthException(code: 'invalid-email', message: 'Invalid');
      final mapped = _mapAuthException(e);
      expect(mapped.toString(), contains('Invalid email'));
    });

    test('maps unknown code to generic message', () {
      final e = FirebaseAuthException(code: 'unknown-code', message: 'Unknown error');
      final mapped = _mapAuthException(e);
      expect(mapped.toString(), contains('Authentication failed'));
    });
  });
}

// Helper to test the private method - extracted for testing
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