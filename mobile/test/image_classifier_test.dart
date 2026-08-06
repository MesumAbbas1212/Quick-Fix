import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:quickfix/services/image_classifier_service.dart';
import 'package:quickfix/shared/models/job_model.dart';

void main() {
  late ImageClassifierService service;

  setUp(() {
    service = ImageClassifierService();
  });

  ImageLabel label(String text, double confidence) {
    return ImageLabel(
      label: text,
      confidence: confidence,
      index: 0,
    );
  }

  group('suggestCategory', () {
    test('returns plumbing for faucet/pipe labels', () {
      final labels = [
        label('faucet', 0.92),
        label('tap', 0.85),
        label('sink', 0.7),
      ];
      expect(service.suggestCategory(labels), JobCategory.plumbing);
    });

    test('returns cleaning for mop/broom labels', () {
      final labels = [
        label('mop', 0.9),
        label('cleaning', 0.8),
      ];
      expect(service.suggestCategory(labels), JobCategory.cleaning);
    });

    test('returns electrical for wire/socket labels', () {
      final labels = [
        label('wire', 0.88),
        label('electrical', 0.8),
      ];
      expect(service.suggestCategory(labels), JobCategory.electrical);
    });

    test('returns painting for paint roller labels', () {
      final labels = [
        label('paint', 0.9),
        label('wall', 0.75),
      ];
      expect(service.suggestCategory(labels), JobCategory.painting);
    });

    test('returns applianceRepair for fridge labels', () {
      final labels = [
        label('refrigerator', 0.95),
        label('appliance', 0.7),
      ];
      expect(service.suggestCategory(labels), JobCategory.applianceRepair);
    });

    test('returns carpentry for wood/chair labels', () {
      final labels = [
        label('wood', 0.85),
        label('chair', 0.8),
      ];
      expect(service.suggestCategory(labels), JobCategory.carpentry);
    });

    test('returns fallback for unknown labels', () {
      final labels = [
        label('mountain', 0.9),
        label('sky', 0.8),
      ];
      expect(service.suggestCategory(labels), JobCategory.other);
      expect(service.suggestCategory(labels, fallback: JobCategory.gardening), JobCategory.gardening);
    });

    test('ignores low confidence labels', () {
      final labels = [
        label('faucet', 0.1), // below threshold
        label('mountain', 0.9),
      ];
      expect(service.suggestCategory(labels), JobCategory.other);
    });

    test('returns fallback for empty labels', () {
      expect(service.suggestCategory([]), JobCategory.other);
    });
  });
}