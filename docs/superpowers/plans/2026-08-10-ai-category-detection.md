# AI Category Detection from Job Photos — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** When a user adds the first photo in the Post Job screen, the app runs on-device ML Kit image labeling and pre-fills the service category with an "AI suggestion" chip the user can override.

**Architecture:** Three units: a pure keyword→category mapper (`suggestCategory`), a thin ML Kit wrapper behind a small `CategoryDetector` interface, and PostJobScreen glue that detects on first image, prefills the dropdown, and shows a dismissible-on-override suggestion chip. ML Kit cannot run in `flutter test`, so all testable logic lives in the pure mapper and an injected fake detector.

**Tech Stack:** Flutter/Dart, `google_mlkit_image_labeling: ^0.13.0` (already in pubspec), `image_picker` (already in pubspec), flutter_test + Mocktail (already dev deps).

**Repo:** `D:\OpenCode_Projects\FYP Project` (mobile app in `mobile/`). All test commands run with workdir `mobile`.

---

### Task 1: Category suggestion mapper (pure Dart)

**Files:**
- Create: `mobile/lib/services/category_suggestion.dart`
- Test: `mobile/test/category_suggestion_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/category_suggestion_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:quickfix/services/category_suggestion.dart';
import 'package:quickfix/shared/models/job_model.dart';

typedef _L = ({String label, double confidence});

void main() {
  group('suggestCategory', () {
    test('maps plumbing labels to plumbing', () {
      final result = suggestCategory([
        _L(label: 'plumbing', confidence: 0.87),
        _L(label: 'pipe', confidence: 0.72),
      ]);
      expect(result, isNotNull);
      expect(result!.category, JobCategory.plumbing);
      expect(result.confidence, closeTo(1.59, 0.001));
    });

    test('maps cleaning labels to cleaning', () {
      final result = suggestCategory([_L(label: 'mop', confidence: 0.6)]);
      expect(result!.category, JobCategory.cleaning);
    });

    test('paint keyword matches the painting label', () {
      final result = suggestCategory([_L(label: 'painting', confidence: 0.9)]);
      expect(result!.category, JobCategory.painting);
    });

    test('wins by score across categories', () {
      final result = suggestCategory([
        _L(label: 'sink', confidence: 0.5),
        _L(label: 'wrench', confidence: 0.4),
        _L(label: 'broom', confidence: 0.2),
      ]);
      expect(result!.category, JobCategory.plumbing);
    });

    test('tie goes to the first listed category', () {
      final result = suggestCategory([
        _L(label: 'sink', confidence: 0.5),
        _L(label: 'mop', confidence: 0.5),
      ]);
      expect(result!.category, JobCategory.cleaning);
    });

    test('returns null below threshold', () {
      final result = suggestCategory([_L(label: 'sink', confidence: 0.15)]);
      expect(result, isNull);
    });

    test('throws on empty label list', () {
      expect(() => suggestCategory(const []), throwsArgumentError);
    });

    test('never maps to other', () {
      final result = suggestCategory([_L(label: 'misc stuff', confidence: 0.99)]);
      expect(result, isNull);
    });

    test('matching is case-insensitive', () {
      final result = suggestCategory([_L(label: 'MOUSE Tap', confidence: 0.8)]);
      expect(result!.category, JobCategory.plumbing);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/category_suggestion_test.dart`
Expected: FAIL — "Target file does not exist" / compile error, `suggestCategory` undefined.

- [ ] **Step 3: Write the implementation**

Create `lib/services/category_suggestion.dart`:

```dart
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/category_suggestion_test.dart`
Expected: PASS (9 tests). Note: the "never maps to other" test relies on `misc stuff` matching no keyword → `bestCategory` null → null returned.

- [ ] **Step 5: Commit**

```bash
git add test/category_suggestion_test.dart lib/services/category_suggestion.dart
git commit -m "feat: category suggestion mapper for AI image detection"
```

---

### Task 2: ML Kit detector wrapper

**Files:**
- Create: `mobile/lib/services/image_category_detector.dart`

- [ ] **Step 1: Write the detector wrapper**

Create `lib/services/image_category_detector.dart`:

```dart
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:quickfix/services/category_suggestion.dart';

/// Detects labels in an image at [imagePath].
abstract class CategoryDetector {
  Future<List<DetectedLabel>> detect(String imagePath);
}

/// On-device ML Kit image labeling implementation.
class MlKitImageDetector implements CategoryDetector {
  final ImageLabeler _labeler;

  MlKitImageDetector()
      : _labeler = ImageLabeler(
          options: ImageLabelerOptions(confidenceThreshold: 0.5),
        );

  @override
  Future<List<DetectedLabel>> detect(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final labels = await _labeler.labelImage(inputImage);
    return [
      for (final label in labels)
        (label: label.label, confidence: label.confidence),
    ];
  }

  void close() {
    _labeler.close();
  }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `flutter analyze lib/services/image_category_detector.dart`
Expected: "No issues found!" — this task has no unit tests because the ML Kit plugin cannot run in `flutter test` (native Android/iOS only); correctness of the mapping is covered by Task 1 and end-to-end by Task 3's widget tests with a fake detector.

- [ ] **Step 3: Commit**

```bash
git add lib/services/image_category_detector.dart
git commit -m "feat: ML Kit image labeler wrapper behind CategoryDetector interface"
```

---

### Task 3: PostJobScreen integration

**Files:**
- Modify: `mobile/lib/features/jobs/presentation/post_job_screen.dart`
- Test: `mobile/test/post_job_ai_test.dart`

- [ ] **Step 1: Write the failing widget tests**

Create `test/post_job_ai_test.dart`:

```dart
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:quickfix/features/jobs/presentation/post_job_screen.dart';
import 'package:quickfix/services/category_suggestion.dart';
import 'package:quickfix/shared/models/job_model.dart';

/// 1x1 transparent PNG (valid decodable image for Image.file).
final Uint8List _tinyPng = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89,
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x44, 0x41, 0x54,
  0x78, 0x9C, 0x62, 0x00, 0x01, 0x00, 0x00, 0x05, 0x00, 0x01,
  0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00,
  0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

class _FakeDetector implements CategoryDetector {
  final List<DetectedLabel> labels;
  bool failed = false;
  _FakeDetector(this.labels);

  @override
  Future<List<DetectedLabel>> detect(String imagePath) async {
    if (failed) throw Exception('detector exploded');
    return labels;
  }
}

void main() {
  late Directory tempDir;
  late String pngPath;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('qfix_ai');
    pngPath = '${tempDir.path}${Platform.pathSeparator}pic.png';
    File(pngPath).writeAsBytesSync(_tinyPng);
  });

  tearDown(() => tempDir.deleteSync(recursive: true));

  Future<void> pumpScreen(WidgetTester tester, {required CategoryDetector detector}) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: PostJobScreen(
              userId: 'user-1',
              detector: detector,
              prefilledImages: [XFile(pngPath)],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('suggests plumbing and prefills the dropdown', (tester) async {
    await pumpScreen(
      tester,
      detector: _FakeDetector(const [
        (label: 'plumbing', confidence: 0.87),
        (label: 'pipe', confidence: 0.72),
      ]),
    );

    expect(find.textContaining('AI suggestion: Plumbing'), findsOneWidget);
    expect(find.text('Plumbing'), findsWidgets); // pre-filled dropdown value
  });

  testWidgets('manual category change dismisses the suggestion chip',
      (tester) async {
    await pumpScreen(
      tester,
      detector: _FakeDetector(const [(label: 'sink', confidence: 0.9)]),
    );

    expect(find.textContaining('AI suggestion: Plumbing'), findsOneWidget);

    await tester.tap(find.text('Plumbing'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cleaning').last);
    await tester.pumpAndSettle();

    expect(find.textContaining('AI suggestion:'), findsNothing);
  });

  testWidgets('detector failure shows no chip and posting is unaffected',
      (tester) async {
    final detector = _FakeDetector(const []);
    detector.failed = true;
    await pumpScreen(tester, detector: detector);

    expect(find.textContaining('AI suggestion:'), findsNothing);
    expect(find.text('Post Job'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/post_job_ai_test.dart`
Expected: FAIL — `CategoryDetector`/`detector`/`prefilledImages` don't exist on `PostJobScreen`.

- [ ] **Step 3: Implement the integration in PostJobScreen**

Edit `lib/features/jobs/presentation/post_job_screen.dart`:

a) Imports + constructor — add detection imports and params:

```dart
import 'package:quickfix/services/category_suggestion.dart';
import 'package:quickfix/services/image_category_detector.dart';
```

Constructor gains:

```dart
  final CategoryDetector? detector;
  final List<XFile>? prefilledImages;

  const PostJobScreen({
    super.key,
    this.prefilledImageUrl,
    this.suggestedCategory,
    this.suggestedDescription,
    this.suggestedAddress,
    this.suggestedBudget,
    this.userId = 'user-1',
    this.detector,
    this.prefilledImages,
  });
```

b) State fields:

```dart
  late final CategoryDetector _detector =
      widget.detector ?? MlKitImageDetector();
  CategorySuggestion? _aiSuggestion;
  bool _detecting = false;
```

c) `initState` — seed prefilled images and trigger detection on the first one:

```dart
  @override
  void initState() {
    super.initState();
    if (widget.suggestedCategory != null) {
      _selectedCategory = widget.suggestedCategory!;
    }
    if (widget.suggestedDescription != null) {
      _descriptionController.text = widget.suggestedDescription!;
    }
    if (widget.suggestedAddress != null) {
      _addressController.text = widget.suggestedAddress!;
    }
    if (widget.suggestedBudget != null) {
      _budgetController.text = widget.suggestedBudget!.toStringAsFixed(0);
    }
    final prefilled = widget.prefilledImages;
    if (prefilled != null && prefilled.isNotEmpty) {
      _images.addAll(prefilled.take(5));
      _detectCategory(prefilled.first.path);
    }
  }
```

d) `_pickImages` — route through a shared handler so detection also fires for gallery picks:

```dart
  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage();
    if (picked.isNotEmpty) {
      setState(() {
        _images.addAll(picked.take(5 - _images.length));
      });
      if (_images.isNotEmpty) {
        _detectCategory(_images.first.path);
      }
    }
  }

  Future<void> _detectCategory(String path) async {
    setState(() => _detecting = true);
    try {
      final labels = await _detector.detect(path);
      final suggestion = suggestCategory(labels);
      if (!mounted) return;
      setState(() {
        _aiSuggestion = suggestion;
        if (suggestion != null) {
          _selectedCategory = suggestion.category;
        }
      });
    } catch (_) {
      // Detection is best-effort: never block posting or show errors.
      if (mounted) setState(() => _aiSuggestion = null);
    } finally {
      if (mounted) setState(() => _detecting = false);
    }
  }
```

e) Category dropdown — dismiss the chip on manual change; the dropdown's `onChanged` becomes:

```dart
          onChanged: (v) => setState(() {
            _selectedCategory = v!;
            _aiSuggestion = null;
          }),
```

f) Suggestion chip UI — insert above the category dropdown in `_buildFormCard()`, replacing the old `widget.suggestedCategory` block with:

```dart
          if (_detecting) ...[
            const Row(
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 8),
                Text(
                  'Detecting category from photo...',
                  style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
          if (_aiSuggestion != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.brandBlue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.brandBlue.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome, size: 14, color: AppTheme.brandBlue),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'AI suggestion: ${_formatCategory(_aiSuggestion!.category)} (${(_aiSuggestion!.confidence * 100).round()}%)',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textDark,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
```

(Note: `_formatCategory(JobCategory.plumbing)` → `Plumbing`, so the chip text reads "AI suggestion: Plumbing (87%)". The old `widget.suggestedCategory` block should remain as-is if you prefer keeping that prefill hint, but it is redundant with the new chip for the detection path — keep it only if you want the explicit `suggestedCategory` param behavior preserved. Recommended: remove it, since `_selectedCategory` prefill in `initState` already covers it.)

- [ ] **Step 4: Run widget tests to verify they pass**

Run: `flutter test test/post_job_ai_test.dart`
Expected: PASS (3 tests). If the dropdown value assertion is flaky (pump timing), add `await tester.pumpAndSettle()` after `pumpScreen`.

- [ ] **Step 5: Run full suite + analyze**

Run: `flutter test`
Expected: all previously passing tests still pass (81 + 9 + 3 = 93).

Run: `flutter analyze`
Expected: no NEW issues beyond the 4 known sealed-class mock warnings in `test/job_service_test.dart`.

- [ ] **Step 6: Commit**

```bash
git add lib/features/jobs/presentation/post_job_screen.dart test/post_job_ai_test.dart
git commit -m "feat: AI category suggestion in post job flow (ML Kit)"
```

---

### Task 4: On-device verification

**Files:** none (uses existing APK build)

- [ ] **Step 1: Build and install on the connected phone**

Verify the phone is connected: `adb devices` (expect `mflrizqk6hvcvko7  device` or similar).

Run (workdir `mobile`): `flutter build apk --debug`
Expected: BUILD SUCCESSFUL.

Run: `adb install -r build/app/outputs/flutter-apk/app-debug.apk`
Expected: Success (if MIUI blocks again, re-check "Install via USB" toggle).

- [ ] **Step 2: Manual sanity check**

Launch the app, log in as `user@quickfix.test` / `User@123`, open Post a Job, add a photo of a pipe/sink/faucet (or a mop/broom for cleaning).
Expected: "Detecting category from photo..." briefly, then chip "AI suggestion: Plumbing (NN%)" (or matching category) with the dropdown pre-filled; changing the dropdown removes the chip; posting the job still succeeds.

- [ ] **Step 3: Commit if any fixups were needed**

(If the on-device run uncovered issues, fix them with a test first, then commit.) Otherwise no commit needed.

---

## Self-Review Notes

- Spec coverage: mapper (Task 1), detector wrapper (Task 2), PostJobScreen integration incl. chip + override + silent error handling (Task 3), on-device verification (Task 4). Threshold behavior and `other`-never-suggested covered by Task 1 tests. No stored metadata on jobs — matches YAGNI decision in spec.
- Placeholder scan: every step has concrete code or exact commands; no TBD/TODO.
- Type consistency: `DetectedLabel` typedef, `CategorySuggestion`, `suggestCategory`, `CategoryDetector`, `MlKitImageDetector`, `PostJobScreen({detector, prefilledImages})` are defined once in Task 1/2 and used identically in Task 3. `_formatCategory` already exists on `_PostJobScreenState` (line 637) and renders `Plumbing` style names.