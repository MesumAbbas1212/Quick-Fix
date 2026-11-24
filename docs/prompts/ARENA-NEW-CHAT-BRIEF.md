# QuickFix — defect batch: start here

> You are picking up an existing, working Android project. Read this whole file before
> opening any code. §2 is the part that has gone wrong three times already.

---

## 1. What this project is

**QuickFix** is a final-year project (BSE, COMSATS University Islamabad, Attock Campus) by
Mesum Abbas and Ubaid Hassan. It is an on-demand local-services marketplace for Pakistan,
built with Flutter and Firebase, and it is **substantially complete**: 46+ screens, a React
admin dashboard, 908 passing tests, and a live Firebase project with seeded data.

A customer posts a job with photos and a GPS pin; nearby workers apply; the customer hires
one; they chat; the worker completes it; the customer pays (simulated) and leaves a review
in their own language, which is machine-translated for the reader. Workers earn ranks from
completed-job volume. An admin moderates from the app and from a web dashboard.

| | |
|---|---|
| GitHub | `https://github.com/MesumAbbas1212/Quick-Fix` |
| App | `mobile/` — Flutter 3.44.9, Dart 3.12 |
| Admin | `admin/` — React 19 + Vite + TypeScript |
| Data | Cloud Firestore (18 collections) + Firebase Auth |
| Rules | `docs/firestore/firestore.rules` (469 lines) |
| Server | `backend/translation-proxy/` (Express, 3 endpoints) |
| Reference | `QuickFix-Technical-Report.md` at the repo root — read §3–§6 for architecture |

---

## 2. Branch — this is where every previous attempt failed

The repository has **four branches, and three of them are traps**:

| Branch | Head | Status |
|---|---|---|
| `main` (default) | `3bd3f67` | **Stale.** Weeks behind. Lacks the admin feature. |
| `master` | `eb1e734` | **Stale.** |
| `arena/01a07d14-quick-fix` | `c4f1432` | **Stale.** This is what a previous attempt used, and it spent hours editing files that were three weeks out of date. |
| **`arena/f4c30e79-quick-fix`** | **`e1561c1`** | **Correct.** This is the current work. |

If your new branch was created from `main` (the default), **it is on the wrong base.**

### Verify before you edit anything

```bash
git fetch origin
git log --oneline -1
ls mobile/lib/views/admin/admin_shell.dart
ls backend/seed/seed-reports.js
```

- `git log` must print **`e1561c1`** (or a descendant of it).
- Both files must exist. `admin_shell.dart` is the mobile admin shell; `seed-reports.js` is
  the moderation seeder. They were added after `c4f1432`, so if either is missing, you are
  on a stale base.

### If the check fails

You are on your own new branch with no work yet, so rebasing it is safe:

```bash
git fetch origin arena/f4c30e79-quick-fix
git reset --hard origin/arena/f4c30e79-quick-fix
git log --oneline -1        # must now print e1561c1
```

Then confirm both files exist again before continuing. **Do not** try to reconcile a stale
tree with a merge — just move the branch.

---

## 3. What you can and cannot verify

You have the repository but **no Flutter SDK, no Android device, and no Firebase
credentials**. That means:

- You **cannot** run `flutter analyze`, `flutter test`, or build an APK.
- You **cannot** test against the live database.
- You **can** read code, reason about it, and write changes that compile by inspection.

So: make minimal, conservative changes. Follow existing patterns exactly rather than
introducing new abstractions. **Never report a check as passed that you did not run** —
"written, not verified" is a useful answer; a false "done" has already cost this project
three rounds of rework.

The operator will run the analyzer, the 908-test suite, and install the build.

---

## 4. Conventions you must follow

1. **No state-management library.** No `provider`, no Bloc, no Riverpod. The app uses
   `StatefulWidget` + `StreamBuilder` + constructor injection. (`provider` is declared in
   `pubspec.yaml` but imported by zero files — leave it.)
2. **Services are constructor-injectable:**
   `late final XService _x = widget.xService ?? XService();` — this is what makes 908 widget
   tests possible without a Firebase emulator. Follow it in any new code.
3. **Views never touch Firestore.** All I/O lives in `mobile/lib/services/`.
4. **Four states on every list:** loading, empty, error, data.
5. **`AppTheme` tokens only** — zero inline hex. Cards: radius 20, `borderGray` border,
   4 % black shadow.
6. **No new packages.** Everything needed is in the Flutter framework.
7. **Do not weaken tests or security rules** to make something pass.

---

## 5. The eight defects

Work in this order: **4 → 8 → 7 → 5 → 1 → 2 → 6**.

### Item 3 is NOT a bug — do not touch it

The admin Overview shows 83 users and 52 workers. Those are **real** counts from live
`count()` aggregations; there is no hardcoded data in `admin_dashboard_screen.dart` or
`AdminCounts`. Verified against the database on 24 November 2026:

```
users: 83    workers: 52    jobs: 15427    reports: 12
```

Changing this would break a dashboard that is telling the truth. **Action: none.** If you
find yourself editing the dashboard, stop — you have misread the task.

---

### Item 4 — show/hide password toggle

**Evidence:** `mobile/lib/views/auth/login_screen.dart:277` and
`mobile/lib/views/auth/signup_screen.dart:374` and `:387` all pass `obscureText: true` with
no toggle. Neither file contains a single `suffixIcon`.

**Change:**
- Add `suffixIcon: IconButton(...)` to every password field — login password, signup
  password, and signup confirmation if present — toggling between
  `Icons.visibility_outlined` and `Icons.visibility_off_outlined`.
- Each field needs its own state (`bool _obscurePassword = true;`), so extract a small
  `PasswordField` widget if that is cleaner than three separate flags.
- `tooltip: 'Show password'` / `'Hide password'`; a `Key` such as
  `login-password-visibility` for tests.
- Preserve the existing validation, error text and styling. This is additive.

**Acceptance:** tapping the eye reveals the typed text and hides it again, on both screens;
validation and keyboard behaviour unchanged.

---

### Item 8 — remove a picked photo before posting

**Evidence:** `mobile/lib/views/jobs/post_job_screen.dart` holds `final List<XFile> _images`
and renders it as a `PageView` with page dots. The only control is an "add photo" button
(around line 341). A picked image cannot be removed, and because it is a `PageView` the user
cannot tell which one they are looking at.

**Change:**
- Replace the bare `PageView` with a large preview plus a horizontal thumbnail strip. Each
  thumbnail gets its own remove badge, so the target is unambiguous.
- Keep the 5-image cap and the existing card styling.
- If the screen also edits an existing job (`prefilled`), only allow removing *newly added*
  entries unless you also delete the file from disk.
- Show a counter: "3 of 5 photos".

**Acceptance:** pick three, remove the middle one, post — exactly two attach in the right
order; the counter and dots stay correct; removing the last returns to the empty placeholder;
no `RangeError` when the index exceeds the list length.

---

### Item 7 — zoom job photos to fullscreen

**Evidence:** a zoom viewer already exists — `mobile/lib/core/widgets/local_photo_viewer.dart`
wraps the image in `InteractiveViewer(minScale: 1, maxScale: 4)`. It is wired to portfolio,
certifications and dispute evidence, but **never to job images**.

Job images render in four places, none tappable:

| File | How |
|---|---|
| `views/client/client_job_detail_screen.dart:385` | `PageView` of `Image.file` |
| `views/client/client_home_screen.dart:334` | `JobImageThumb` |
| `views/jobs/my_jobs_screen.dart:238` | `JobImageThumb` |
| `views/jobs/worker_dashboard_screen.dart:340` | `JobImageThumb` |

**Change:** wrap each job image in an `InkWell` that pushes
`LocalPhotoViewer(imagePath: path, caption: job.title, imageStore: ...)`. The screens already
have access to `LocalImageStore` — inject it the same way `portfolio_screen.dart` does. Keep
existing thumbnail size and radius; add a subtle expand affordance on the detail page.

**Acceptance:** tapping any job photo opens it fullscreen with pinch-zoom; back returns to
the same scroll position; a missing file shows the viewer's existing "not a readable image"
message instead of crashing.

---

### Item 5 — jobs must reach only matching workers

**Evidence:** `views/jobs/worker_dashboard_screen.dart:265` calls
`_jobService.watchOpenJobs()` with **no category argument**, so every worker sees every open
job. The service already supports filtering (`watchOpenJobs({JobCategory? category})`,
`job_service.dart:288`) and `MatchingService` already scores category — neither is used.

Workers hold a list of professions: `workers/{uid}.professions`, e.g.
`['plumbing','electrical']`.

**Change:**
- Read the signed-in worker's professions from `WorkerProfile`.
- Filter the board to jobs whose `category` is in that list. Prefer filtering the existing
  stream client-side — that avoids adding a composite index. (`whereIn` also works, but only
  if you deliberately add the index.)
- Add a visible toggle: **"My professions" / "All jobs"**, defaulting to professions.
- If the worker has no professions, show all jobs plus a prompt to finish onboarding.
- Empty state: "No open jobs in your professions yet" with a button to switch to All jobs.

**Acceptance:** a plumbing-only worker sees no electrical jobs by default; the toggle reveals
them; a two-profession worker sees both; existing dashboard tests still pass.

---

### Item 1 — removing a job

**Evidence:**
- `services/job_service.dart:79` — `deleteJob()` exists and is **called from nowhere**. Dead code.
- `services/job_service.dart:202` — `cancelAssignedJob()` is wired only in
  `views/jobs/job_tracking_screen.dart:154`.
- **The client's job list is `views/client/client_home_screen.dart`** (it streams
  `watchUserJobs`). `views/jobs/my_jobs_screen.dart` is the *worker's* job history — it
  streams `watchWorkerJobs` — so do **not** put client cancellation there.
- Admin: `views/admin/admin_jobs_screen.dart` has "Cancel job" inside the detail sheet
  (~line 383) calling `AdminService.cancelJob`. No delete.

**Rules already permit this** — no rule change is required:
```js
// normalJobUpdate(): the owner may move open -> cancelled
(uid == old.userId && ((old.status == 'open' && next.status in ['open','assigned','cancelled']) ...
// and jobs allow delete for admins
```

**Change:**
1. **Client** — on an `open` job card in `client_home_screen.dart`, add "Cancel job" with a
   confirm ("Workers who applied will lose the request"). On confirm set `status: 'cancelled'`,
   `cancelReason`, `cancelledAt`, `updatedAt`. Do **not** delete the document: cancellation
   preserves the chat thread and notifications, deletion orphans them.
2. **Admin** — add "Delete job" beneath "Cancel job" in the detail sheet, in `dangerRed`, with
   a confirm that states it is permanent for both parties. Wire it to the existing
   `deleteJob()`.
3. Hide both actions on `completed` and `cancelled`.

**Acceptance:** a client can cancel an open job; an admin can cancel *and* delete any job;
neither is offered on completed jobs; `deleteJob` is no longer unreferenced.

---

### Item 2 — worker cannot send a message or share location

**This one needs diagnosis, not a guess.**

**What is proven:** the security rules do **not** block it. Signing in as
`worker@quickfix.test` and committing the same two writes the app performs (conversation +
message) against the live project returned **HTTP 200**. No worker is blocked (0 of 52).

**Why it is undiagnosable today** — `views/chat/chat_screen.dart:63`:

```dart
} catch (_) {
  SnackBar(content: Text('Failed to send message. Check your connection.'))
}
```

Permission denied, missing profile, timeout and genuine offline all produce that sentence.

**Change:**
1. In `ChatService.sendMessage` and `ChatScreen._sendMessage`, catch `FirebaseException`
   explicitly and `debugPrint` the `code`. Map it to a real message:

   | Code | Message |
   |---|---|
   | `permission-denied` | "You don't have permission to message this user." |
   | `unavailable`, `deadline-exceeded` | "You appear to be offline. The message will send when you reconnect." |
   | `not-found` | "This conversation no longer exists." |
   | other | the code itself, in small text |

2. Apply the same mapping to `_shareLocation`, which currently has its own generic message.
3. **Do not** delete the error or widen the rules. If a rule is wrong, change it deliberately
   and add an emulator case in `validation/firestore/rules.test.mjs`.

**Likely real cause** (investigate, don't assume): the sender's `users/{uid}` document is
missing, so `notBlocked(uid)` returns false and the write is denied — which looks exactly
like a network failure. Second candidate: the receiver's profile is missing, so `livePair()`
fails.

**Acceptance:** the real error is visible in logs; a denied send says "permission", not
"connection"; no bare `catch (_)` remains on the send path.

---

### Item 6 — splash screen appears off-centre

**Do not guess at this one.**

The Flutter layout is already centred — `views/auth/splash_screen.dart` uses
`Scaffold → SafeArea → Column(mainAxisAlignment: center)`, and a `Column` centres
horizontally by default. The native launch theme
(`android/app/src/main/res/drawable/launch_background.xml`) is a plain white background with
no image, so the OS splash cannot be off-centre either.

**Required process:**
1. Identify which layer the user is seeing: the Android 12+ system splash (app icon, before
   Flutter starts), `SplashScreen` (blue background, yellow "Q", spinner), or
   `OnboardingCarousel` (first launch only).
2. Consider large system font scale and split-screen — overflow is the usual cause of content
   pushed sideways.

**You have no device, so you cannot reproduce this.** Unless you find an actual layout defect
by reading the code, **change nothing** and report it as not reproducible. A speculative
layout change here risks breaking a screen that currently works.

---

## 6. How to deliver

- One commit per item, conventional style: `fix(auth): add password visibility toggle`.
- Commit **on your own new branch**, then push it and report the branch name. Do not force-push
  anyone else's branch, and do not push to `arena/f4c30e79-quick-fix` directly.
- Before your final message, run `git diff --stat origin/arena/f4c30e79-quick-fix` and paste
  it. It should list only the files you touched — if it shows deletions of `admin/` files or
  `seed-reports.js`, your base is wrong; stop and say so.

## 7. Report back

For each of the eight items, one line: **fixed / not reproducible / not a bug**, the file
changed, and the reasoning. Then state plainly which checks you could not run, and anything
in this brief that contradicts the code you read.
