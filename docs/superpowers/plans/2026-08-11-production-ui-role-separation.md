# Implementation Plan: Production UI + Role Separation

Spec: `docs/superpowers/specs/2026-08-11-production-ui-role-separation-design.md` (approved)
App dir: `D:\OpenCode_Projects\FYP Project\mobile` — run all flutter commands there with `$env:PATH = "D:\flutter\bin;$env:PATH"`
Git commits: code at `mobile` (scope `mobile/`), docs at repo root `D:\OpenCode_Projects\FYP Project`

## Objective

Deliver the approved production UI: remove mock phone frames everywhere, separate client vs worker experiences at the shell level, fix logout, and add client features (dashboard with Post a Job hero, My Posted Jobs, Workers browse with live reviews + translate, worker detail with chat, rate-worker flow wired to ReviewService, profile editing with local avatar).

## Key decisions (from approved spec)

- **Role switch in AppShell**: `user.role == UserRole.worker ? WorkerShell : ClientShell`. `FindJobsScreen` deleted; the worker Jobs feed moves to the first tab of `WorkerShell`.
- **Client shell tabs**: Home (dashboard), Workers, Messages, Profile. Worker shell tabs: Jobs, My Jobs, Messages, Profile.
- **Email + password auth stays**; phone becomes an editable profile field (not OTP).
- **Avatars stored locally** via `LocalImageStore` pattern (no Firebase Storage).
- **Reviews**: live from Firestore via `ReviewService.watchReviewsForWorker`; Translate button uses `TranslationService` (already proxies to backend, offline fallback keeps text as-is). Reviews list rendered by shared `ReviewListTile`.
- **"Rate Worker"** on client job detail when job status is `completed` → ReviewScreen, then `ReviewService.submitReview`; conversation end shows link to worker detail.
- **Logout**: confirm dialog → `AuthService.signOut()` → `AuthController.clearSession()` → `Navigator.pushAndRemoveUntil(LoginScreen)`.
- **Layout**: full-screen body, AppBar `AppTheme.brandBlue`, `SafeArea`, no 9px text, consistent 12–16px body type.
- **TDD**: every task starts with failing tests; `flutter analyze` must show zero NEW warnings (4 pre-existing sealed-class-mock warnings in `test/job_service_test.dart` are known/acceptable); full suite green before commit.

## Environment facts

- Device: Redmi Note 11, serial `mflrizqk6hvcvko7`, 720x1650 @320dpi (~360dp wide). MIUI blocks `adb shell input` and `pm grant` — user interacts manually on device.
- Screenshots to `C:\Users\MESUMA~1\AppData\Local\Temp\opencode\`, resize (System.Drawing) before reading.
- Tests already follow: `tester.view.physicalSize = Size(1000,900); tester.view.devicePixelRatio = 1.0; addTearDown(tester.view.reset)`; fakes via constructor injection; `ChatService` has lazy `late final _firestore` so fakes can subclass without Firebase init.
- `main.dart` calls `Firebase.initializeApp()` before `runApp`; `QuickFixApp` home is `LoginScreen`.

## File inventory

### Create

| File | Purpose |
|---|---|
| `lib/core/widgets/user_avatar.dart` | Shared avatar widget (circle, initials fallback, optional online dot / border) |
| `lib/core/widgets/review_list_tile.dart` | Shared review card with star rating, original text, Translate button |
| `lib/views/client/client_shell.dart` | Client BottomNav shell: Home / Workers / Messages / Profile |
| `lib/views/client/client_home_screen.dart` | Dashboard: greeting, Post a Job hero card, My Posted Jobs stream (`JobService.watchUserJobs`) |
| `lib/views/client/client_job_detail_screen.dart` | Client's job detail: status card, applicants info, Rate Worker button when `completed` |
| `lib/views/client/workers_screen.dart` | Browse workers (`ProfileService.searchWorkers`), search by profession, distance |
| `lib/views/client/worker_detail_screen.dart` | Worker profile, live reviews w/ translate, Chat button |
| `lib/views/worker/worker_shell.dart` | Worker BottomNav shell: Jobs / My Jobs / Messages / Profile |
| `lib/views/profile/edit_profile_screen.dart` | Edit name/phone, avatar pick → local store, save via `AuthService.updateProfile` |
| `test/client_home_screen_test.dart` | ClientHomeScreen tests |
| `test/workers_screen_test.dart` | WorkersScreen tests |
| `test/worker_detail_screen_test.dart` | WorkerDetailScreen tests (live reviews + translate + chat) |
| `test/client_job_detail_screen_test.dart` | ClientJobDetailScreen tests |
| `test/edit_profile_screen_test.dart` | EditProfileScreen + avatar save tests |
| `test/logout_flow_test.dart` | Logout confirm → signOut → LoginScreen tests |

### Modify

| File | Change |
|---|---|
| `lib/services/review_service.dart` | Fix `submitReview` aggregates: update scalar `rating` (recomputed average) + `reviews` (increment) to match `WorkerProfile`/`ProfileService`; unit-testable |
| `lib/services/local_image_store.dart` | Add `saveAvatar(XFile) → String` (own subdir `quickfix_avatars`) |
| `lib/views/auth/app_shell.dart` | Role switch → `ClientShell` / `WorkerShell` |
| `lib/views/auth/login_screen.dart` | Remove phone frame; full-screen layout |
| `lib/views/auth/signup_screen.dart` | Remove phone frame; full-screen layout |
| `lib/views/chat/chat_screen.dart` | Remove phone frame; full-screen AppBar |
| `lib/views/profile/profile_screen.dart` | Remove frame + `_isWorker` sections → worker-only extras (menu) stay for worker shell; live reviews via ReviewListTile; working logout at line ~474; use UserAvatar |
| `lib/views/jobs/worker_dashboard_screen.dart` | Rename header to "Jobs"; remove frame; keep accept/decline request flow |
| `lib/views/jobs/my_jobs_screen.dart` | Remove frame |
| `lib/views/jobs/post_job_screen.dart` | Remove frame |
| `lib/views/jobs/job_request_screen.dart` | Remove frame |
| `lib/views/reviews/review_screen.dart` | Remove frame; wire submit to `ReviewService.submitReview` (batch incl. worker aggregates) + optional translation on submit |
| `test/widget_test.dart` | Replace FindJobsScreen smoke test with ClientShell/WorkerShell smoke |
| `test/app_shell_test.dart` | Update for shell switch |
| `docs/superpowers/specs/...design.md` | No change (frozen) |

### Delete

| File | Why |
|---|---|
| `lib/views/jobs/find_jobs_screen.dart` | Replaced by worker Jobs tab + client Workers screen |

## Task 1 — ReviewService aggregate fix (foundation)

**Why first**: `submitReview` currently writes nested `rating.average`/`rating.total`, but the app displays scalar `rating` + `reviews` from `WorkerProfile`. Review flow (Task 6) depends on correct aggregates.

Files: `lib/services/review_service.dart`, `test/review_service_test.dart` (new).

TDD:
1. Write `test/review_service_test.dart` first — a `FakeFirestore`-style seam: make `_firestore` injectable (constructor param, default `FirebaseFirestore.instance`), then verify:
   - `submitReview` writes review doc to `reviews` collection with all fields (`rating`, `originalText`, `originalLang`, `translatedText`, `jobId`, `reviewerId`, `workerId`).
   - worker doc gets `reviews: +1` and `rating` recomputed to the exact average.
   - second review recomputes correctly (e.g. 4.0 + 5.0 → 4.5).
2. Implement: injectable `_firestore`; `submitReview` reads worker doc → `newRating = (rating*reviews + r)/(reviews+1)` → batch: set review doc, update `{'rating': newRating, 'reviews': FieldValue.increment(1)}`.

Verify: `flutter test test/review_service_test.dart` → `flutter analyze lib/services/review_service.dart`
Commit (in `mobile`): `fix(review): write scalar rating/reviews aggregates via injectable firestore`

## Task 2 — Shared widgets: UserAvatar + ReviewListTile

Files: `lib/core/widgets/user_avatar.dart`, `lib/core/widgets/review_list_tile.dart`, `test/widgets_test.dart` (extend or new file `test/shared_widgets_test.dart`).

TDD:
1. Tests first:
   - `UserAvatar`: shows `Image.network` when `avatarUrl` non-empty; initials circle (`A B` from fullName) when empty; honors `size`; `online` dot when true; optional `borderColor`.
   - `ReviewListTile`: shows rating stars (`Icons.star` for filled count, `star_border` remainder out of 5); original text; Translate button visible ONLY when `TranslationService.isNonLatin(originalText)` AND translated text is empty; pressing button with `translatedText` already set shows it inline; onTap callback invoked.
2. Implement both widgets from the spec. `ReviewListTile` API: `{required Review review, VoidCallback? onTranslate}` — widget internally shows `review.translatedText` when non-empty, else calls `onTranslate` which returns `Future<String>` (screen/service layer fetches via TranslationService; tile shows result with setState). Simpler contract: tile owns `showOriginalOnly` logic; the translate callback is `Future<String> Function(String text)`.

Verify: `flutter test test/shared_widgets_test.dart`
Commit: `feat(widgets): add shared UserAvatar and ReviewListTile`

## Task 3 — Avatar store + EditProfileScreen + logout

Files: `lib/services/local_image_store.dart`, `lib/views/profile/edit_profile_screen.dart`, `lib/views/profile/profile_screen.dart`, `test/local_image_store_test.dart` (extend), `test/edit_profile_screen_test.dart`, `test/logout_flow_test.dart`.

TDD:
1. Tests first:
   - `LocalImageStore.saveAvatar(XFile)` — hmm, widget tests can't use real file IO with path_provider (MissingPluginException). Keep `saveAvatar` thin and test the pure parts: filename/extension logic via `test` of `_extensionOf` if extractable; integration verified on device. Widget tests for EditProfileScreen use injected fakes instead.
   - `EditProfileScreen`: renders current name/phone from `UserModel`; save button calls injected `AuthService.updateProfile` with edited values and pops with updated `UserModel`.
   - `LogoutFlow`: in ProfileScreen (fake auth/controller injected), tapping logout shows confirm dialog; confirming calls `signOut` and `clearSession`, then navigates to `LoginScreen` (pump `QuickFixApp`-like harness with fakes, or test at AppShell level — use `AppShell` harness with fake `AuthService`).
2. Implement:
   - `LocalImageStore.saveAvatar(XFile picked)` → single path under `quickfix_avatars` subdir, reusing `_extensionOf`; keep `readImage` shared.
   - `EditProfileScreen({required UserModel user, required AuthService authService})`: name + phone fields (prefilled), avatar tap → `ImagePicker.pickImage` → `saveAvatar` → preview via `readImage` (`Image.memory`) → save → `authService.updateProfile(uid, name:, phone:, avatarUrl:)` → `Navigator.pop(updatedUser)`.
   - ProfileScreen: replace `_PhoneFrame` wrapper with full-screen `SafeArea` + `Scaffold` AppBar `brandBlue` titled "Profile"; replace avatar block with `UserAvatar`; logout menu item → confirm dialog → `authService.signOut()` → `AuthController.clearSession()` → `pushAndRemoveUntil(LoginScreen)`. Inject `AuthService` (constructor optional w/ default for tests, mirroring existing patterns).
3. Make existing profile tests pass (adjust wrappers).

Verify: `flutter test test/edit_profile_screen_test.dart test/logout_flow_test.dart test/local_image_store_test.dart`
Commit: `feat(profile): edit profile with local avatar + working logout`

## Task 4 — ClientShell + ClientHomeScreen + AppShell switch (client side)

Files: `lib/views/client/client_shell.dart`, `lib/views/client/client_home_screen.dart`, `lib/views/auth/app_shell.dart`, `test/client_home_screen_test.dart`, `test/app_shell_test.dart`, `test/widget_test.dart`.

TDD:
1. Tests first:
   - `ClientHomeScreen`: shows greeting with user's first name; shows Post a Job hero card (title + button → pushes `PostJobScreen`); lists "My Posted Jobs" from injected fake `JobService.watchUserJobs` stream; empty state text "No jobs posted yet"; job card shows category, status chip, budget.
   - `AppShell`: `user.role == UserRole.user` → shows 4 tabs (Home/Workers/Messages/Profile) and lands on Home; Messages tab shows ChatScreen; Profile tab shows ProfileScreen; bottom nav switching works.
2. Implement:
   - `ClientShell` (`AppShell`-provided `user` + `workerProfile`? client has none): IndexedStack of `ClientHomeScreen`, `WorkersScreen` (stub placeholder this task — returns `Placeholder`? No: implement after Task 5; use a temporary "coming soon" only if needed — better: implement `WorkersScreen` in Task 5 and have this task's shell use it. To keep tasks green, Task 4 shell tab shows minimal `WorkersScreen` stub pushed from Task 5 scope... Simpler: Task 4 includes only a stub `WorkersScreen` placeholder that Task 5 replaces), `ChatScreen(peerName: 'Sarah Ahmed', peerId: 'worker1', myId: user.uid)` — wait: chat wiring currently only supports single peer; keep existing pattern (worker chat in shell uses same peerId 'worker2' as before? Prior worker shell used ChatScreen with 'Sarah Ahmed'/'worker2'. Client shell: peer = worker1 'worker2'? Keep symmetric: client Messages → ChatScreen(peerName: 'Sarah Ahmed', peerId: 'worker2', myId: user.uid)).
   - `ClientHomeScreen`: `StreamBuilder(watchUserJobs)`; hero card gradient `brandBlue→accentBlue`, "Post a Job" CTA; job cards link to `ClientJobDetailScreen` (stub push this task; full screen in Task 6 — push to a temporary placeholder? To stay green: Task 4 push to `PostJobScreen` for CTA and job cards just display; wiring to detail comes Task 6).
3. Update `test/app_shell_test.dart` + `test/widget_test.dart` for new shell smoke (role user → ClientShell).

Verify: `flutter test test/client_home_screen_test.dart test/app_shell_test.dart test/widget_test.dart`
Commit: `feat(client): client shell with dashboard and posted jobs`

## Task 5 — WorkersScreen + WorkerDetailScreen

Files: `lib/views/client/workers_screen.dart`, `lib/views/client/worker_detail_screen.dart`, `test/workers_screen_test.dart`, `test/worker_detail_screen_test.dart`.

TDD:
1. Tests first (injected fakes for `ProfileService`/`JobService`/`ChatService`/`ReviewService`):
   - `WorkersScreen`: lists workers from injected `searchWorkers` future; worker card shows `UserAvatar`, name, profession chips, `rating` stars, `completedJobs`, distance when `location` present; profession filter dropdown filters list (re-calls service with category).
   - `WorkerDetailScreen`: shows fullName, professions, about, stats (rating/completed jobs/reviews count); reviews section lists live reviews from injected stream via `ReviewListTile`; tapping Translate on a non-Latin review calls injected `TranslationService.translate` and displays result; empty reviews → "No reviews yet"; Chat button pushes `ChatScreen(peerId: workerId, peerName: workerName, myId: currentUser.uid)`.
2. Implement per spec. `WorkersScreen` uses `ProfileService.searchWorkers(fromLocation: null)`; distance shown when worker.location != null (needs current user location via `LocationService` optional; hide distance when denied).
3. ClientShell Messages tab already done; swap Workers tab stub → `WorkersScreen`.

Verify: `flutter test test/workers_screen_test.dart test/worker_detail_screen_test.dart`
Commit: `feat(client): browse workers with live reviews and translate`

## Task 6 — ClientJobDetailScreen + ReviewScreen wiring

Files: `lib/views/client/client_job_detail_screen.dart`, `lib/views/reviews/review_screen.dart`, `lib/services/job_service.dart` (if needed), `test/client_job_detail_screen_test.dart`.

TDD:
1. Tests first:
   - `ClientJobDetailScreen`: shows job category, title, description, images (via `LocalImageStore.readImage` + `Image.memory`), status chip; when `status == completed` shows enabled "Rate Worker" button → pushes `ReviewScreen(job, workerId: job.workerId)`; when not completed button hidden.
   - `ReviewScreen` (update existing tests): submit calls injected `ReviewService.submitReview` with rating + text and pops with success SnackBar; when `TranslationService.isNonLatin(text)` submits translated text alongside original (calls `translate` first).
2. Implement:
   - `ClientJobDetailScreen({required JobModel job, required String currentUserId})`; status mapping chip colors (open `brandBlue`, in_progress `accentYellow`, completed `successGreen`).
   - `ReviewScreen`: accept optional injected `ReviewService`/`TranslationService`; `_handleSubmit` calls `translate` when non-Latin → `submitReview(jobId, reviewerId: currentUserId, workerId: job.workerId, rating, originalText, originalLang: 'ur' when non-Latin else 'en', translatedText)`.
   - Fix `ReviewService.submitReview` batch already done in Task 1.
3. ClientHomeScreen job cards now push `ClientJobDetailScreen`.

Verify: `flutter test test/client_job_detail_screen_test.dart test/review_screen_test.dart` (existing review tests updated)
Commit: `feat(client): job detail with rate-worker review flow`

## Task 7 — WorkerShell + worker Jobs tab + delete FindJobsScreen

Files: `lib/views/worker/worker_shell.dart`, `lib/views/jobs/worker_dashboard_screen.dart`, `lib/views/auth/app_shell.dart`, `test/app_shell_test.dart`, `test/widget_test.dart`, delete `lib/views/jobs/find_jobs_screen.dart`.

TDD:
1. Tests first:
   - `AppShell` role `worker` → `WorkerShell` with 4 tabs (Jobs/My Jobs/Messages/Profile), first tab = WorkerDashboardScreen (header "Jobs").
   - Update `widget_test.dart` smoke: pump role-worker → sees "Jobs" nav item; pump role-user → sees "Home"/"Workers" (no "Find Jobs" anywhere).
   - Update any tests referencing `FindJobsScreen` (grep `find_jobs_screen` / `FindJobsScreen`).
2. Implement:
   - `WorkerShell` mirrors current WorkerDashboardScreen tab structure: IndexedStack(WorkerDashboardScreen, MyJobsScreen, ChatScreen('Sarah Ahmed','worker2', myId), ProfileScreen).
   - `WorkerDashboardScreen`: remove `_PhoneFrame`, full-screen AppBar `brandBlue` "Jobs", keep "Hi, {name}!" greeting, availability toggle (needs `workerProfile`), suggested jobs stream, JobRequestScreen push flow unchanged.
   - `AppShell`: `user.role == UserRole.worker ? WorkerShell(user: user, workerProfile: workerProfile) : ClientShell(user: user)`.
   - Delete `find_jobs_screen.dart`.
3. Grep codebase for remaining `FindJobsScreen` references and clean.

Verify: `flutter test` (full suite) — all green; `flutter analyze` → zero NEW warnings.
Commit: `refactor(roles): worker shell with Jobs tab, remove FindJobsScreen`

## Task 8 — Frame removal sweep + typography polish + final verification

Files: `lib/views/auth/login_screen.dart`, `lib/views/auth/signup_screen.dart`, `lib/views/chat/chat_screen.dart`, `lib/views/jobs/my_jobs_screen.dart`, `lib/views/jobs/post_job_screen.dart`, `lib/views/jobs/job_request_screen.dart`, `lib/views/reviews/review_screen.dart`, `lib/views/profile/profile_screen.dart` (worker sections), plus any remaining `_PhoneFrame`/`DeviceFrame` wrappers.

Steps:
1. Grep `_PhoneFrame|PhoneFrame|device_frame|MockupPhone` → remove every occurrence: screens render full-bleed under `Scaffold` AppBar `brandBlue` + `SafeArea`.
2. Typography pass: no font size below 12; button labels ≥ 14; consistent `AppTheme` tokens; remove hardcoded grays where tokens exist.
3. `ProfileScreen`: remove `_isWorker`-gated blocks? — NO: workers still need reviews/menu; instead ensure gating reflects worker shell only (worker extras stay for workers; client profile shows only account + menu). Replace hardcoded review fixtures with live `ReviewService.watchReviewsForWorker` when worker profile present.
4. Full suite: `flutter test` green; `flutter analyze` zero new warnings.
5. Full test file run: `flutter test` (expect ~100+ tests).

Commit: `style(ui): full-screen layout pass, remove mock device frames`

## Task 9 — Device verification + docs

Steps (interactive, MIUI — user taps; model pulls screenshots):
1. `flutter build apk --debug` → install via adb → launch `com.example.quickfix`.
2. Login as **client** (`client@test.com` / password used in prior sessions): Home dashboard (greeting, Post a Job hero, My Posted Jobs), Workers tab (cards, open worker detail → reviews + Translate tap), Messages (chat + location share card), Profile (edit profile → avatar pick from gallery → saved; logout → confirm → login screen).
3. Login as **worker**: Jobs tab header "Jobs", accept/decline flow, My Jobs, Profile (availability, live reviews), logout works.
4. Screenshots each screen → resize → verify no frames, correct colors (`#009AE2`, `accentYellow`, `successGreen`), no 9px text.
5. User sign-off on visuals.
6. Docs commit (repo root): update design doc status/checklist if spec has one; commit plan doc.

Commit (root): `docs(plan): implementation plan for production UI + role separation`

## Risks / notes

- **Firebase testability**: ReviewService gets injectable firestore; JobService fakes already in use via existing test pattern (`watchUserJobs` stream fake).
- **MIUI permission** for location on Workers distance: degrade gracefully (hide distance) when denied — already the pattern.
- **Pre-existing analyze warnings** (4, sealed mocks in `test/job_service_test.dart`): leave; verify no new ones.
- **ChatScreen peer wiring** stays hardcoded peer (Sarah Ahmed/worker2) for demo; multi-conversation chat is out of scope (noted in spec).
- **OfflineCache** has no clear method; logout does not clear cache (non-goal this round).

## Definition of Done

- All tasks committed; `flutter test` green (~100+ tests); `flutter analyze` no new warnings.
- Device walkthrough passes for both roles; no phone frames; working logout; client sees zero worker-feed UI and vice-versa.
- User visual sign-off recorded; plan + spec committed at repo root.
