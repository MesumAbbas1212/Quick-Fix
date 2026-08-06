import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:quickfix/shared/models/job_model.dart';

class ImageClassifierService {
  final ImageLabeler _labeler;

  ImageClassifierService({ImageLabeler? labeler})
      : _labeler = labeler ?? ImageLabeler(options: ImageLabelerOptions());

  // Classify an image and return all labels with confidence
  Future<List<ImageLabel>> classifyImage(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    return await _labeler.processImage(inputImage);
  }

  // Classify an image and return the single best label
  Future<ImageLabel?> classifyImageBest(String imagePath) async {
    final labels = await classifyImage(imagePath);
    if (labels.isEmpty) return null;
    labels.sort((a, b) => b.confidence.compareTo(a.confidence));
    return labels.first;
  }

  // Map image labels to a JobCategory using keyword matching
  JobCategory suggestCategory(List<ImageLabel> labels, {JobCategory fallback = JobCategory.other}) {
    // Build combined text from labels
    final combined = labels
        .where((l) => l.confidence >= 0.3)
        .map((l) => l.label.toLowerCase())
        .join(' ');

    final keywordMap = <String, Set<String>>{
      JobCategory.cleaning.name: {'broom', 'vacuum', 'cleaning', 'mop', 'detergent', 'sponge', 'dust'},
      JobCategory.plumbing.name: {'pipe', 'faucet', 'plumbing', 'sink', 'plumber', 'drain', 'water', 'shower', 'tap', 'toilet'},
      JobCategory.electrical.name: {'electrical', 'wire', 'socket', 'lightbulb', 'bulb', 'switch', 'circuit', 'plug'},
      JobCategory.carpentry.name: {'wood', 'chair', 'table', 'furniture', 'carpentry', 'cabinet', 'shelf', 'desk', 'repair'},
      JobCategory.painting.name: {'paint', 'painting', 'paintbrush', 'roller', 'wall', 'color', 'canvas'},
      JobCategory.gardening.name: {'plant', 'garden', 'gardening', 'soil', 'flower', 'grass', 'leaf', 'tree'},
      JobCategory.moving.name: {'box', 'packing', 'moving', 'moving truck', 'luggages', 'boxes', 'trolley'},
      JobCategory.applianceRepair.name: {'ac', 'air conditioner', 'refrigerator', 'fridge', 'washing machine', 'microwave', 'oven', 'appliance', 'washer', 'cooling'},
      JobCategory.tutoring.name: {'book', 'books', 'education', 'school', 'tutor', 'learning', 'desk', 'pencil', 'paper', 'classroom'},
      JobCategory.beauty.name: {'hair', 'beauty', 'makeup', 'salon', 'scissors', 'comb', 'cosmetics', 'brush', 'skincare'},
    };

    // Check each category's keywords
    String? bestCategory;
    var bestScore = 0;
    for (final entry in keywordMap.entries) {
      if (entry.key == '#categories') continue;
      var score = 0;
      for (final keyword in entry.value) {
        if (combined.contains(keyword)) score++;
      }
      if (score > bestScore) {
        bestScore = score;
        bestCategory = entry.key;
      }
    }

    if (bestCategory != null && bestScore > 0) {
      return JobCategory.values.firstWhere(
        (c) => c.name == bestCategory,
        orElse: () => fallback,
      );
    }
    return fallback;
  }

  // Static keyword map for the mapping logic
  static const Map<String, Set<String>> keywordMap = {
    'cleaning': {'broom', 'vacuum', 'cleaning', 'mop', 'detergent', 'sponge', 'dust'},
    'plumbing': {'pipe', 'faucet', 'plumbing', 'sink', 'plumber', 'drain', 'wrench', 'shower', 'tap', 'toilet'},
    'electrical': {'electrical', 'wire', 'socket', 'lightbulb', 'bulb', 'switch', 'led', 'power'},
    'carpentry': {'wood', 'chair', 'table', 'furniture', 'carpentry', 'cabinet', 'shelf', 'desk', 'repair'},
    'painting': {'paint', 'painting', 'paintbrush', 'roller', 'wall', 'canvas'},
    'gardening': {'plant', 'garden', 'gardening', 'soil', 'flower', 'grass', 'leaf', 'tree'},
    'moving': {'box', 'packing', 'moving', 'boxes', 'trolley'},
    'applianceRepair': {'refrigerator', 'fridge', 'washing machine', 'microwave', 'oven', 'appliance', 'cooling'},
    'tutoring': {'book', 'books', 'education', 'school', 'tutor', 'pencil', 'paper', 'classroom'},
    'beauty': {'hair', 'beauty', 'makeup', 'salon', 'scissors', 'groom', 'brush'},
  };

  Future<void> dispose() async {
    await _labeler.close();
  }
}