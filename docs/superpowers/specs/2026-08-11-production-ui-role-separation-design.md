# QuickFix Production UI + Role Separation — Design

**Date:** 2026-08-11
**Status:** Approved (approach A: structured refactor of existing screens)

## Problem

The app's UI is a desktop demo: every screen is wrapped in a mock phone frame (340×680 with a
notch), content is worker-oriented even for client accounts, the client home shows the worker's
job feed with Accept/Decline cards, clients cannot post jobs from their home, the client profile
shows worker sections (received reviews, availability), the logout button is a no-op TODO, and
small fixed typography/layout values make the app feel like a mockup rather than a product.

## Goals

1. **Role separation** — client (user) and worker shells render distinct navigation, home content,
   profiles, and actions. No worker actions (Accept/Decline) reachable from the client shell.
2. **Working logout** — teardown auth session + app state, clear navigation stack, land on login.
3. **Professional full-screen UI** — remove `_PhoneFrame` from every screen; consistent app bars,
   typography scale, spacing, cards, and responsive layouts.
4. **Client features** — home dashboard (post job + my posted jobs), workers browse with detail
   (reviews + translate), rate-workers flow wired to real services.
5. **Profile creation/editing** — edit name/phone, avatar upload (local storage), shown everywhere.
6. **Reviews & ratings** — review submission wired to `TranslationService` + `ReviewService`;
   translate toggle on every foreign-language review.

## Out of scope (per decisions)

- Firebase phone OTP auth — auth stays email+password; phone is a profile field (already collected).
- Firebase Storage for avatars — local storage via existing `LocalImageStore` pattern.
- Client-side Accept/Decline — worker applications flow stays minimal: worker detail offers
  Chat only (JobRequest creation deferred; `jobRequests` collection already exists for future use).
- Admin web app, FCM, rendered Google Maps — as before.

## Architecture

### 1. Role shells

`lib/views/auth/app_shell.dart` becomes the single switch:

```dart
class AppShell extends StatelessWidget {
  final UserModel user;
  ...
  @override
  Widget build(BuildContext context) =>
      user.role == UserRole.worker ? WorkerShell(user: user) : ClientShell(user: user);
}
```

**ClientShell** (new, `lib/views/client/client_shell.dart`):
bottom nav tabs: **Home** (`ClientHomeScreen`), **Workers** (`WorkersScreen`),
**Messages** (`ChatScreen` — conversation entry), **Profile** (`ProfileScreen` with client data).
Header shows the client's name / "Home".

**WorkerShell** (new, `lib/views/worker/worker_shell.dart`):
bottom nav tabs: **Jobs** (`WorkerDashboardScreen`), **My Jobs** (`MyJobsScreen(isWorker: true)`),
**Messages** (`ChatScreen`), **Profile** (`ProfileScreen` with worker data).
The existing `FindJobsScreen` is retired (its content moves into the worker dashboard);
`worker_dashboard_screen.dart` becomes the worker Jobs tab (header "Jobs").

Each shell owns its own `Scaffold` + bottom navigation; tabs are full screens (no more
`IndexedStack` of mixed-content widgets).

### 2. Full-screen layout system

- Delete the private `_PhoneFrame` class from all 9 screens (login, signup, chat, profile,
  find_jobs, job_request, my_jobs, post_job, worker_dashboard). No fixed 340×680 container.
- Standard skeleton per screen: `Scaffold(backgroundColor: AppTheme.bgLight)` →
  `AppBar` (brandBlue, white title, back arrow where pushed) → `SafeArea` body with
  16–20px horizontal padding, scrollable via `SingleChildScrollView`/`ListView`.
- Typography scale (shared via `AppTheme.textTheme` where practical):
  - Screen titles: 20/18 w800
  - Section headers: 15 w700
  - Body: 14
  - Secondary: 12 (textMuted)
  - Captions/labels: 10–11 — never below 9 (9px times removed).
- Cards: 16px radius, 1px borderGray border, soft shadow (existing style) — full width.
- Login/Signup: brandBlue gradient background, centered card, full-width role cards
  (min height 72px), full-width fields/buttons.
- Loading/empty/error states on all lists.

### 3. Logout

- `ProfileScreen` gains `VoidCallback? onLogout` (shells pass the implementation).
- Shell logout handler: confirm dialog → `AuthService().signOut()` →
  `AuthController().clearSession()` → `OfflineCache` clear → `pushAndRemoveUntil` LoginScreen.
- Button shows a spinner while signing out; failure → error snackbar.
- `auth_service.dart:86` `signOut()` already exists; no service change needed.

### 4. Client features

**ClientHomeScreen** (new, `lib/views/client/client_home_screen.dart`):
- Hero "Post a Job" card (brandBlue gradient, wrench icon) → `PostJobScreen` (existing:
  image upload, description, category dropdown, budget, real GPS — untouched).
- "My Posted Jobs": `StreamBuilder` on `jobs where userId == me orderBy createdAt desc`;
  card per job: title, category icon, status chip (open → successGreen "Open", assigned →
  brandBlue "Assigned", completed → gray), assigned worker name if present;
  tap → **ClientJobDetailScreen** (new): job details + assigned worker card (avatar, name,
  rating, "Chat" button) + "Rate Worker" button when status == completed and no review yet.

**WorkersScreen** (new, `lib/views/client/workers_screen.dart`):
- `StreamBuilder` on `workers` collection (WorkerProfile docs joined with users where needed);
  worker card: avatar, name, rating ★ 4.8, profession badges, completed jobs, "Chat" icon;
  tap → **WorkerDetailScreen** (new):
  - profile section (about, skills badges, languages, budget range PKR, availability chip)
  - reviews section — reuses the worker reviews widget pattern (non-Latin reviews render a
    "Translate" button; tap toggles translated text via `TranslationService`)
  - actions: "Chat" → `ChatScreen(peerName, peerId, myId)`
  - No Hire/Request button in this round (out of scope).

### 5. Worker side (polish only)

- WorkerDashboardScreen: header "Jobs", full-screen layout, feed behavior unchanged
  (suggested jobs + Accept/Decline → JobRequestScreen with client overview — verified on device).
- MyJobsScreen stays worker-only (assigned/in-progress jobs).
- ProfileScreen worker sections (worker card, reviews with translate, availability toggle)
  remain worker-only — already gated by `_isWorker`.

### 6. Reviews & ratings wiring

`review_screen.dart` `_handleSubmit` replaces the simulated delay with:

```dart
final lang = TranslationService.detectLanguage(text);       // existing helper
final translated = lang == 'en'
    ? null
    : await TranslationService().translate(text, 'en');    // existing service
await ReviewService().submitReview(
  jobId, workerId, reviewerId, rating: _rating, text, originalLang: lang, translatedText: translated);
```

- `ReviewService.submitReview` already updates the worker doc rating/review count (verify during
  implementation; adjust if it only writes the review).
- Entry point: ClientJobDetailScreen "Rate Worker" → `ReviewScreen(jobId, workerId, reviewerId)`.
- Guard: hide "Rate Worker" if a review for (jobId) already exists (query once on load).
- Translate toggle in review lists (worker profile + worker detail): existing pattern from
  `profile_screen.dart:393` — promote to a shared widget `ReviewListTile` so both screens reuse it.

### 7. Profile editing + avatar

- **EditProfileScreen** (new, `lib/views/profile/edit_profile_screen.dart`):
  - Avatar circle (64px) with camera badge → `ImagePicker` → `LocalImageStore.save` →
    local path stored on user doc (`avatarUrl` field already exists on UserModel) via
    `ProfileService.updateProfile`.
  - Fields: full name, phone (email read-only). Save → loading spinner → success snackbar.
  - `ProfileScreen` menu gains "Edit Profile" → EditProfileScreen.
- Shared **`UserAvatar`** widget (`lib/core/widgets/user_avatar.dart`): renders local avatar
  path or initials circle (brandBlue) — used in profile card, worker cards, worker detail,
  chat header (peer avatar optional), job cards (assigned worker).

## Files

**Create:**
- `lib/views/client/client_shell.dart`
- `lib/views/client/client_home_screen.dart`
- `lib/views/client/client_job_detail_screen.dart`
- `lib/views/client/workers_screen.dart`
- `lib/views/client/worker_detail_screen.dart`
- `lib/views/worker/worker_shell.dart`
- `lib/views/profile/edit_profile_screen.dart`
- `lib/core/widgets/user_avatar.dart`
- `lib/core/widgets/review_list_tile.dart` (extracted from profile_screen reviews)
- Tests: `test/client_shell_test.dart`, `test/workers_screen_test.dart`,
  `test/edit_profile_screen_test.dart`, `test/logout_flow_test.dart` (+ extend existing)

**Modify:**
- `lib/views/auth/app_shell.dart` — role switch to ClientShell/WorkerShell
- `lib/views/auth/login_screen.dart`, `signup_screen.dart` — remove phone frame, full-screen
- `lib/views/chat/chat_screen.dart` — remove phone frame
- `lib/views/profile/profile_screen.dart` — remove phone frame, logout wiring, Edit Profile menu,
  extract ReviewListTile
- `lib/views/jobs/worker_dashboard_screen.dart` — remove phone frame, header "Jobs",
  drop client-side role routing if any
- `lib/views/jobs/my_jobs_screen.dart`, `post_job_screen.dart`, `job_request_screen.dart` —
  remove phone frame
- `lib/views/jobs/find_jobs_screen.dart` — deleted (superseded by client shell + worker shell)
- `lib/views/reviews/review_screen.dart` — real submission wiring
- `lib/app.dart` — unchanged (LoginScreen home)
- `test/widget_test.dart`, `test/app_shell_test.dart` — update for shell routing

## Testing

- TDD per task: widget tests for ClientShell routing (client → ClientShell, worker → WorkerShell),
  logout flow (signOut called, navigator cleared, login screen visible), Home dashboard renders
  posted jobs + Post a Job entry, Workers list + worker detail renders reviews with translate
  toggle, EditProfile saves avatar path + fields, review submission calls services (fake
  services via constructor injection where needed).
- Existing suite (88 tests) stays green; phone-frame sizing overrides in tests remain valid.
- Final: `flutter analyze` (4 known warnings), `flutter test`, `flutter build apk --debug`,
  on-device pass (client flow + worker flow + logout).

## Risks / notes

- ReviewService.submitReview must update worker aggregates — verify and adjust in implementation.
- `find_jobs_screen.dart` deletion removes its tests if any (job cards finders) — move assertions
  to worker dashboard tests.
- Chat tab entry point: shells pass a conversation list placeholder for now; per-conversation
  ChatScreen keeps its Firestore stream (works standalone).
