# AI Category Detection from Job Photos — Design

Date: 2026-08-10
Status: Approved by user (2026-08-10, via brainstorming session)

## Goal

When a user uploads a photo of the work needed in the Post Job screen, the app
detects the job type on-device and pre-fills the service category, while still
letting the user override the suggestion manually (per FYP.docx functional
requirements: "AI suggests service category / Select final category manually if
needed"). Lightweight ML Kit image labeling, per the proposal's scope
("AI features will be limited to lightweight image classification and language
translation for reviews") and its tool list (Google ML Kit — Image
Classification).

## Context

- Dependency `google_mlkit_image_labeling: ^0.13.0` is already declared in
  `mobile/pubspec.yaml` but unused.
- `PostJobScreen` (`mobile/lib/features/jobs/presentation/post_job_screen.dart`)
  already captures up to 5 images and posts jobs to Firestore; the category is
  currently always chosen manually from the dropdown.
- 11 `JobCategory` values exist (`mobile/lib/shared/models/job_model.dart`):
  cleaning, plumbing, electrical, carpentry, painting, gardening, moving,
  applianceRepair, tutoring, beauty, other.
- Firebase Storage is unavailable (billing), so images live in local app
  storage (`LocalImageStore`); the detector reads from the local file path,
  which is compatible.

## Architecture

Three small units, each with one purpose:

### 1. Category suggestion mapper (pure Dart, no ML Kit)

`mobile/lib/services/category_suggestion.dart`

- Input: a list of `(label, confidence)` pairs, e.g. from ML Kit Image Labeler.
- Output: `CategorySuggestion?` — `{category, confidence}` or `null` when no
  confident match exists.
- Behavior:
  - Keyword → category rules, one list per category (e.g. cleaning:
    `mop, broom, vacuum, soap, detergent, sink, dust, sponge`; plumbing:
    `plumbing, pipe, faucet, tap, toilet, sink, leak, drain, wrench`;
    electrical: `electrical, wiring, cable, socket, light bulb, fuse, wire`;
    carpentry: `carpentry, wood, hammer, saw, drill, furniture`;
    painting: `paint, painting, roller, brush, wall`; gardening:
    `garden, plant, lawn, grass, soil, hedge`; moving:
    `moving, boxes, packing, carton`; applianceRepair:
    `appliance, refrigerator, washing machine, oven, microwave, ac, freezer`;
    tutoring: `books, classroom, studying, homework, teacher, laptop`;
    beauty: `scissors, hair, makeup, salon, nail`).
  - Score = sum of matched label confidences; label matching is
    case-insensitive substring containment (e.g. keyword `washing machine`
    matches label "washing machine", and keyword `paint` also matches
    "painting").
  - Pick the category with the highest score; require score >= threshold
    (0.4). If the top score is below threshold, return null (no suggestion).
  - `other` is never suggested and never scored.
- Why pure: unit-testable without a native plugin; ML Kit output and mapping
  decisions are independently verifiable.

### 2. ML Kit detector wrapper

`mobile/lib/services/image_category_detector.dart`

- Wraps `ImageLabeler` (conf = 0.5) from `google_mlkit_image_labeling`.
- `Future<List<({String label, double confidence})>> detect(String imagePath)`
  — builds `InputImage.fromFilePath`, runs `labelImage`, maps results, closes
  the labeler in `close()`.
- Constructor takes an optional labeler factory so tests can inject a fake;
  the class is thin (no business logic).
- Runs on device, offline. First-call model load is lazy inside the SDK.

### 3. PostJobScreen integration

- `_images` add → if this is the first image, run detection:
  - show inline "Detecting category..." indicator in the form card;
  - call detector + mapper on the first picked image;
  - on suggestion: set `_selectedCategory` to the suggestion, show chip
    `AI suggestion: <Category> (<confidence%>)` above the category dropdown;
  - on null/error: silently no suggestion; chip hidden; posting never blocked.
- The chip is dismissed when the user changes the dropdown selection (their
  manual choice wins, per the doc).
- Detection is skipped entirely in widget tests via the injected fake.

## Data flow

1. User picks ≥1 image in PostJobScreen.
2. `ImageCategoryDetector.detect(path)` → raw labels.
3. `suggestCategory(labels)` → `CategorySuggestion?`.
4. UI: prefill + chip, or nothing.
5. User may override; posted job stores the final `_selectedCategory`.

No stored detection metadata on the job record (YAGNI — not required by doc).

## Error handling

- Plugin throws (bad file, native failure): caught in PostJobScreen, logged,
  suggestion silently skipped. Posting continues normally.
- Empty labels / below-threshold: null suggestion, no UI noise.
- Timeout: detection is fast (~100 ms model warm-up aside); no explicit
  timeout, but the indicator clears on completion/error via `finally`.

## Testing

- `mobile/test/category_suggestion_test.dart` — pure mapping: ~30 cases
  covering every category keyword, threshold behavior, tie-breaking (first
  listed wins), empty input, `other` never suggested, case-insensitivity.
- `mobile/test/post_job_screen_test.dart` (extend existing or new file) —
  widget test with fake detector: suggestion prefills dropdown + chip shows;
  override via dropdown hides chip; detector failure → no chip, posting still
  works. ML Kit plugin itself cannot run in `flutter test` (native).
- Full suite must stay green (currently 81 tests).

## Out of scope (future rounds)

- Custom trained TFLite model (per user choice, on-device labeling first).
- Gap-closing items vs FYP.docx (worker experience/hourly rate, earnings
  summary, admin block/report tools, price negotiation in chat, profile photo
  upload) — tracked separately as follow-up work.