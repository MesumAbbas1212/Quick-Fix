# QuickFix Spec Alignment + Real Geolocation — Design

Date: 2026-08-10
Status: Approved by user (2026-08-10, via brainstorming)

## Goal

Align the existing QuickFix mobile app with the supervisor's application spec (FYP.docx / Principal Engineer brief) while keeping all working features, and make location sharing real instead of mocked. Deliverables: exact MVC-style folder structure (`lib/views`, `lib/controllers`, `lib/models`, `lib/services`), exact color palette from the brief, role-selection login screen, mockup-faithful Job Request screen, chat wired to Firestore with consent-based real GPS location sharing, and Firestore schema documentation.

**Out of scope this round** (approved): FCM push notifications (future round), rendered Google Maps widget (needs billing-enabled API key), admin web app changes, AI image category detection (removed by user — manual category selection only).

## Context

- Existing app: 72 passing tests on `master`, Firebase-connected (`quickfix-fyp`), React admin web app, seeded data (12 user docs, 15 jobs, categories, reviews).
- Mock location today: hardcoded `GeoPoint(31.5204, 74.3587)` in `post_job_screen.dart:137`, `find_jobs_screen.dart`, `worker_dashboard_screen.dart`, `my_jobs_screen.dart` (demo fixtures). `profile_service.dart` already has an unused real `getCurrentPosition()` (Geolocator).
- Chat today: `chat_screen.dart` renders a hardcoded mock message list. `ChatService` + `ChatMessage` (attachmentType `'location'`) already exist but the screen never uses them.
- `geolocator: ^13.0.1` and `google_maps_flutter: ^2.9.0` already in pubspec. GPS via Geolocator needs NO billing; Maps API key would need billing → map rendering excluded, replaced by coordinates card + maps link.
- Theme deltas: brandBlue `#004F9F` → `#0D47A1`, ctaOrange `#F36C00` → `#F57C00`, bgLight `#F4F6F9` → `#F5F5F5`, dangerRed `#E53935` already correct; missing `#4CAF50` success green and `#FF9800` accent.
- Current structure: `lib/features/<f>/presentation|models|services`, `lib/shared/models`, `lib/core`, `lib/services`.
- Android manifest needs `ACCESS_FINE_LOCATION` / `ACCESS_COARSE_LOCATION` for real GPS.

## Architecture

Units, each with one clear responsibility:

### 1. LocationService (`lib/services/location_service.dart`)

- `Future<GeoPoint?> getCurrentLocation()` — requests permission (`Geolocator.requestPermission()`), returns `Position` as `GeoPoint`, null on denied/error.
- Absorbs `ProfileService.getCurrentPosition` (duplicate removed; `ProfileService` delegates or drops it).
- No background tracking — called only on explicit user action (post job, share location button).

### 2. PostJobScreen — real location

- On submit: `LocationService.getCurrentLocation()`; if null → snackbar with permission instructions, posting blocked (location required); store returned `GeoPoint` instead of the hardcoded constant.

### 3. ChatScreen — real data + real location share

- Replace hardcoded `_messages` fixture with a Firestore stream via existing `ChatService` (conversation by participants; messages subcollection).
- New "Share Location" pin action in the input bar: explicit press → `LocationService.getCurrentLocation()` → send `ChatMessage(attachmentType: 'location', lat/lng)`.
- Location bubble renderer: card with `Lat, Lng` + "Open in Google Maps" (`https://maps.google.com/?q=lat,lng`). No map image.
- Permission denied → snackbar, nothing sent.

### 4. Folder structure (`lib/views`, `lib/controllers`, `lib/models`, `lib/services`)

Mechanical moves + import updates only (no behavior change; all 72 tests must keep passing):

- `lib/features/<f>/presentation/*` → `lib/views/<f>/*`
- `lib/shared/models/*` + feature models → `lib/models/*` (flatten; keep class names so only imports change)
- `lib/services/*` + feature services → `lib/services/*` (flatten)
- New `lib/controllers/`: ChangeNotifiers only where they improve structure per spec (e.g. `AuthController` wrapping auth state; `JobListController` wrapping find-jobs state). Minimal — no redesign of working flows.
- `lib/core` (theme, utils) stays.

### 5. Exact palette (`lib/core/theme/app_theme.dart`)

- `brandBlue` → `Color(0xFF0D47A1)`; `ctaOrange` → `Color(0xFFF57C00)`
- add `accentOrange = Color(0xFFFF9800)` (active tabs/badges)
- add `successGreen = Color(0xFF4CAF50)` (Accept/success)
- `bgLight` → `Color(0xFFF5F5F5)`; dangerRed `#E53935` and surfaceWhite `#FFFFFF` unchanged
- Only Theme constants change (and widgets referencing old values); the demo phone-frame chrome is left as-is.

### 6. Role-selection Login (Screen 1)

- Two side-by-side selectable cards: "Login as User — Find Services" (blue) / "Login as Worker — Get Jobs" (orange).
- Selection drives post-login routing (AppShell already routes by role); wrong-role logins show a hint. Signup link preserved.

### 7. Job Request screen (Screen 4, worker side)

- Job details card (title, description, location, distance km, PKR).
- Client overview: name, star rating (`4.8 ★★★★★`), review count, posting date (Firestore via existing services).
- Dual buttons: **Accept Job** (`successGreen`) / **Decline** (dangerRed) — persist via `JobRequestService`.

### 8. Job feed card alignment (Screen 2)

- Verify `find_jobs_screen` cards match the mockup: image left, title, PKR price, "X km away" distance. Adjust labels where missing.

### 9. Firestore schema docs (deliverable)

- `docs/firestore/schemas.md`: collections `users`, `jobs`, `chats` (conversations + messages), `reviews` — matching real seeded data and Firestore rules.

## Data flow

1. Post Job: form → `LocationService` (GPS) → `JobService.createJob` with real `GeoPoint` → Firestore `jobs` doc.
2. Chat: screen subscribes to `ChatService` stream; pin tap → `LocationService` (GPS) → `ChatMessage(location)` → Firestore → stream rebuild → location bubble for both sides.
3. Accept/Decline → `JobRequestService` → job status transition → dashboards update via existing streams.

## Error handling

- GPS denied/unavailable: snackbar with permission instructions; post job blocked; chat share aborted.
- GPS timeout / provider error: caught → snackbar "Couldn't fetch location, try again"; never fake coordinates.
- Chat stream errors: standard Firestore error snackbar; existing OfflineCache behavior retained.

## Testing

- `LocationService`: unit-testable via injected geolocator dependency (permission denials, errors → null; permission granted → GeoPoint).
- PostJobScreen: widget test — denied location blocks posting + shows snackbar; granted location posts with real GeoPoint (existing `JobService` mock pattern).
- ChatScreen: widget test — location pin sends `ChatMessage` with attachmentType `'location'`; permission denied → no message, snackbar shown.
- Theme: golden-free assertion test that palette constants equal the exact hex values from the brief.
- Structure moves: full suite (72 tests) must stay green after moves — imports updated.
- Full suite + `flutter analyze` at end.

## Out of scope

FCM, rendered maps, admin web app, AI detection (removed), Google Maps API key provisioning (billing).