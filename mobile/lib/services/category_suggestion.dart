import 'package:quickfix/shared/models/job_model.dart';

/// A labeled result from an image classifier (label + confidence 0..1).
typedef DetectedLabel = ({String label, double confidence});

/// A category suggestion produced from detected labels.
class CategorySuggestion {
  final JobCategory category;
  final double confidence;

  const CategorySuggestion({required this.category, required this.confidence});
}

/// Minimum combined keyword confidence required to make a suggestion.
const double _threshold = 0.4;

/// Keywords that map to each [JobCategory]. `other` is intentionally absent.
const Map<JobCategory, List<String>> _keywordRules = {
  JobCategory.cleaning: [
    'cleaning', 'clean', 'mop', 'broom', 'vacuum', 'soap', 'detergent',
    'dust', 'sponge', 'bathroom', 'kitchen', 'housekeeping',
  ],
  JobCategory.plumbing: [
    'plumbing', 'pipe', 'faucet', 'tap', 'toilet', 'sink', 'leak', 'drain',
    'water', 'wrench', 'shower', 'plumber',
  ],
  JobCategory.electrical: [
    'electrical', 'electrical wiring', 'wiring', 'cable', 'socket', 'light',
    'light bulb', 'bulb', 'fuse', 'wire', 'electrician', 'switch', 'fan',
  ],
  JobCategory.carpentry: [
    'carpentry', 'wood', 'hammer', 'saw', 'drill', 'furniture', 'cabinet',
    'door', 'carpenter', 'screwdriver', 'plywood',
  ],
  JobCategory.painting: [
    'paint', 'painting', 'roller', 'brush', 'wall', 'paintbrush',
    'exterior', 'interior',
  ],
  JobCategory.gardening: [
    'garden', 'gardening', 'plant', 'lawn', 'grass', 'soil', 'hedge',
    'flower', 'shovel', 'leaf',
  ],
  JobCategory.moving: [
    'moving', 'box', 'boxes', 'packing', 'carton', 'packaging', 'cardboard',
    'trolley',
  ],
  JobCategory.applianceRepair: [
    'appliance', 'refrigerator', 'washing machine', 'oven', 'microwave',
    'air conditioning', 'ac', 'freezer', 'dishwasher', 'cooker',
  ],
  JobCategory.tutoring: [
    'books', 'book', 'classroom', 'studying', 'study', 'homework', 'teacher',
    'teaching', 'laptop', 'school', 'tutoring',
  ],
  JobCategory.beauty: [
    'scissors', 'hair', 'haircut', 'makeup', 'salon', 'nail', 'beauty',
    'spa', 'beard',
  ],
};

/// Suggests a [JobCategory] from detected image [labels].
///
/// Each label is scored against every category's keyword list
/// (case-insensitive substring match); a category's score is the sum of the
/// confidences of all labels that matched it. The highest-scoring category is
/// returned only if its score is at least [_threshold]. Returns null when no
/// confident suggestion exists. [labels] must not be empty.
CategorySuggestion? suggestCategory(List<DetectedLabel> labels) {
  if (labels.isEmpty) {
    throw ArgumentError.value(labels, 'labels', 'must not be empty');
  }
  double bestScore = 0;
  JobCategory? bestCategory;
  for (final entry in _keywordRules.entries) {
    double score = 0;
    for (final label in labels) {
      final lower = label.label.toLowerCase();
      if (entry.value.any((keyword) => lower.contains(keyword))) {
        score += label.confidence;
      }
    }
    if (score > bestScore) {
      bestScore = score;
      bestCategory = entry.key;
    }
  }
  if (bestCategory == null || bestScore < _threshold) return null;
  return CategorySuggestion(category: bestCategory, confidence: bestScore);
}