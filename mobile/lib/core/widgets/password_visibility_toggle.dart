import 'package:flutter/material.dart';

import 'package:quickfix/core/theme/app_theme.dart';

/// Eye button used as a password field's `suffixIcon`.
///
/// Purely additive to the auth forms: it only flips the field's
/// `obscureText` flag, so validation, error text and keyboard behaviour are
/// untouched. Each password field owns its own `bool` so the login password,
/// the signup password and the signup confirmation toggle independently.
class PasswordVisibilityToggle extends StatelessWidget {
  /// Whether the field is currently hidden (i.e. `obscureText == true`).
  final bool obscured;

  /// Flips the owning screen's obscure flag.
  final VoidCallback onToggle;

  /// Stable key for widget tests, e.g. `login-password-visibility`.
  final String visibilityKey;

  const PasswordVisibilityToggle({
    super.key,
    required this.obscured,
    required this.onToggle,
    required this.visibilityKey,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: Key(visibilityKey),
      tooltip: obscured ? 'Show password' : 'Hide password',
      onPressed: onToggle,
      icon: Icon(
        obscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        size: 20,
        color: AppTheme.textMuted,
      ),
    );
  }
}
