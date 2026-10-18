import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quickfix/core/utils/content_direction.dart';

void main() {
  group('contentDirection', () {
    test('Urdu names and Arabic content are RTL', () {
      expect(contentDirection('محمد علی'), TextDirection.rtl);
      expect(contentDirection('مرحبا بالعالم'), TextDirection.rtl);
    });
    test('English and empty content are LTR', () {
      expect(contentDirection('Ali Khan'), TextDirection.ltr);
      expect(contentDirection(''), TextDirection.ltr);
    });
    test('non-Latin does not imply RTL', () {
      expect(contentDirection('बहुत अच्छा काम'), TextDirection.ltr);
    });
  });
}
