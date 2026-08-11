import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quickfix/core/theme/app_theme.dart';

void main() {
  test('palette matches the spec exactly', () {
    expect(AppTheme.brandBlue, const Color(0xFF0D47A1));
    expect(AppTheme.ctaOrange, const Color(0xFFF57C00));
    expect(AppTheme.accentOrange, const Color(0xFFFF9800));
    expect(AppTheme.successGreen, const Color(0xFF4CAF50));
    expect(AppTheme.dangerRed, const Color(0xFFE53935));
    expect(AppTheme.bgLight, const Color(0xFFF5F5F5));
    expect(AppTheme.surfaceWhite, const Color(0xFFFFFFFF));
  });
}
