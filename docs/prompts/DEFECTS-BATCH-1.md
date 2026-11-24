# QuickFix — eight reported defects

> **Read §1 before touching anything.** One of the eight is not a defect, and "fixing" it
> would break correct code. The rest are real and each has a verified root cause.

---

## 0. Where you are

| | |
|---|---|
| Repo | https://github.com/MesumAbbas1212/Quick-Fix |
| Branch | `arena/f4c30e79-quick-fix` |
| HEAD | `e1561c1` |
| Local clone | `C:\Users\MOON COMPUTERS\WorkBuddy AI\2026-10-18-16-18-16\quick-fix` |

Toolchain on this machine:

- Flutter 3.44.9 at `D:\flutter`. In Git Bash prefix every call:
  `env "ProgramFiles(x86)=C:\Program Files (x86)" flutter ...`
- `JAVA_HOME=D:\jdk` (17), `ANDROID_HOME=D:\android-sdk`. `java` on PATH is 1.8 — ignore it.
- adb: `D:/android-sdk/platform-tools/adb.exe`, device `mflrizqk6hvcvko7` when connected.
- **Always run `flutter pub get` after a checkout**, or `flutter analyze` reports ~30 000
  phantom errors from a stale package config.

Baseline before you change anything: `flutter analyze --no-pub` is clean and `flutter test`
gives **908 passed / 3 failed**, where the three failures are `local_image_store_test.dart`
symlink tests that fail only on Windows (`errno 1314`). They are expected; do not touch them.

**A previous agent spent nine minutes on this list and edited zero files.** Do not repeat
that: after each item, confirm the file actually changed (`git diff --stat`) before moving on.

---

## 1. Triage — what is actually true

| # | Reported | Verified? | Root cause |
|---|---|---|---|
| 1 | No option to remove a job (user + admin) | **Partly** | Owner cancel exists only for assigned jobs; `deleteJob` is dead code; admin has cancel but no delete |
| 2 | Worker cannot send message or location | **Needs diagnosis** | Rules **permit** the write (proved); the failure is hidden by a bare `catch` |
| 3 | Overview shows dummy 83 users / 52 workers | **NO — not a bug** | Live database genuinely holds 83 users and 52 workers |
| 4 | No show/hide password toggle | **Yes** | Both password fields hardcode `obscureText: true`, zero `suffixIcon` |
| 5 | Jobs shown to workers of other categories | **Yes** | Worker board calls `watchOpenJobs()` with no category argument |
| 6 | Splash screen off-centre, clipped left | **Unconfirmed** | The Flutter layout is correctly centred; needs a screenshot |
| 7 | Cannot zoom job photos to fullscreen | **Yes** | A zoom viewer exists but is never wired to job images |
| 8 | Cannot remove a picked image before posting | **Yes** | The composer is a `PageView` with only an "add photo" button |

---

## 2. Item 3 — do not change this

The dashboard reads live `count()` aggregations (`AdminService.counts()`); there are no
hardcoded numbers anywhere in `admin_dashboard_screen.dart` or `AdminCounts`.

Queried directly against `quickfix-fyp` on 24 November 2026:

```
users: 83
workers: 52
jobs: 15427
reports: 12
```

The app is displaying the truth. The numbers grew because demo accounts were provisioned
(four users, two workers) and accounts were created during testing.

**Action: none.** If the user wants different numbers, the fix is data, not code. Say so
rather than inventing a "fix" — and never hardcode a display value.

---

## 3. Item 1 — removing a job

### Current state

- `JobService.deleteJob(jobId)` exists at `services/job_service.dart:79` and is **called
  from nowhere**. Dead code.
- `JobService.cancelAssignedJob(jobId, ownerId)` at line 202 is wired only in
  `views/jobs/job_tracking_screen.dart:154`.
- `views/jobs/my_jobs_screen.dart` renders an action only when status is `assigned` or
  `inProgress` (line ~303). An **open** job — posted, nobody hired — has no action at all.
- Admin: `views/admin/admin_jobs_screen.dart` has "Cancel job" inside the detail sheet
  (line ~383), which calls `AdminService.cancelJob`. There is no delete.

### What the rules already allow

`normalJobUpdate()` permits the owner to move `open → cancelled`:

```js
(uid == old.userId && ((old.status == 'open' && next.status in ['open','assigned','cancelled']) ...
```

and `jobs` allows `delete` for admins. **No rule change is needed.**

### Required change

1. **Client, open jobs** — add a "Cancel job" action on the `open` card in `my_jobs_screen`
   (overflow menu or a text button under the timeline). Confirm first: "Cancel this job?
   Workers who applied will lose the request." On confirm, set `status: 'cancelled'`,
   `cancelReason`, `cancelledAt`, `updatedAt`.
   - Reuse `cancelAssignedJob`'s shape or add `cancelOpenJob`; do **not** call
     `deleteJob` for this. Cancelling preserves history, the chat thread and notifications;
     deleting orphans them.
   - Hide the action for `cancelled`, `completed` and `inProgress`.
2. **Admin** — add "Delete job" to the existing detail sheet, below "Cancel job", in
   `dangerRed`, with a confirm that states it is permanent and removes the record for both
   parties. Wire it to `deleteJob` (finally using that method) or an admin-specific delete
   in `AdminService`.
3. **Both** — after the action, the list must update without a manual refresh (it is a
   stream, so this should be automatic; verify it).

### Acceptance

- A client can cancel an open job; it moves to Cancelled with a reason.
- An admin can cancel *and* delete any job.
- Neither action is offered on completed jobs.
- `deleteJob` is no longer unreferenced.

---

## 4. Item 2 — worker cannot send a message or share location

### What has been proven

The security rules **do not block this**. I signed in as `worker@quickfix.test` and
committed the same two writes the app performs (conversation + message) against the live
project: **HTTP 200, both writes accepted.** A blocked worker does not exist in the
database either (0 of 52).

So the failure is somewhere else, and the app is hiding it:

```dart
} catch (_) {
  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
    content: Text('Failed to send message. Check your connection.')));
}
```

Every possible cause — permission denied, missing profile document, timeout, a genuine
network drop — produces the same sentence. That is why this bug is unfixable by guessing.

### Required change

1. **Instrument first.** In `ChatService.sendMessage` and `ChatScreen._sendMessage`, catch
   `FirebaseException` explicitly and log `e.code` (use `debugPrint`, not a user-facing
   string). Map the code to a real message:

   | Code | Message |
   |---|---|
   | `permission-denied` | "You don't have permission to message this user." |
   | `unavailable` / `deadline-exceeded` | "You appear to be offline. The message will send when you reconnect." |
   | `not-found` | "This conversation no longer exists." |
   | anything else | the code itself, in small text |

2. **Then reproduce and fix the real cause.** Most likely candidates, in order:
   - the sender's `users/{uid}` document is missing, so `notBlocked(uid)` returns false and
     the write is denied (this happens for a worker created before profiles were
     provisioned);
   - the receiver's `users` document is missing, so `livePair()` fails;
   - a genuine offline moment, where the correct behaviour is a queued message, not an error.
3. **Location sharing** (`ChatScreen._shareLocation`) already has its own message; apply the
   same code mapping so "check your connection" is only shown when that is actually true.
4. **Do not** simply delete the error or widen the rules. If a rule is wrong, change it
   deliberately and add an emulator test.

### Acceptance

- Sending a message as `worker@quickfix.test` to `user@quickfix.test` works on a device.
- With airplane mode on, the user sees the offline message, not a generic failure.
- No `catch (_)` remains on the send path without a logged code.

---

## 5. Item 4 — show/hide password

`views/auth/login_screen.dart:277` and `views/auth/signup_screen.dart:374` and `:387` all
pass `obscureText: true` with no toggle. There is no `suffixIcon` in either file.

### Required change

- Add a `suffixIcon: IconButton(...)` to every password field (login, signup password,
  signup confirm password if present) that toggles visibility with
  `Icons.visibility_outlined` / `Icons.visibility_off_outlined`.
- The toggle needs per-field state: `bool _obscurePassword = true;` in the `State` class,
  or a small reusable `PasswordField` widget in `core/widgets/`.
- Accessibility: `tooltip: 'Show password' / 'Hide password'`, and a `Key` such as
  `login-password-visibility`.
- Preserve existing validation, error text and the existing `_PasswordField`/styling —
  this is an additive change.

### Acceptance

- Tapping the eye reveals the typed password and tapping again hides it, on both screens.
- The keyboard type, autofill hints and validation are unchanged.
- A widget test asserts the text is obscured, then visible after the tap.

---

## 6. Item 5 — jobs reaching the wrong workers

`views/jobs/worker_dashboard_screen.dart:265`:

```dart
Stream<List<JobModel>> _watchBoard() {
  try { return _jobService.watchOpenJobs(); } ...
```

No category argument — so every worker sees every open job. The service already supports
it (`watchOpenJobs({JobCategory? category})`, `job_service.dart:288`) and
`MatchingService` already scores category at 0.3 weight; neither is used for the board.

Workers can hold several professions (`workers/{uid}.professions` is a list, e.g.
`['plumbing','electrical']`).

### Required change

1. Read the signed-in worker's `professions` (already on `WorkerProfile`).
2. Filter the board to jobs whose `category` is in that list. Firestore `whereIn` supports
   up to 30 values, so one query works — or filter the existing stream client-side, which
   avoids a new composite index. Prefer the client-side filter unless you add the index
   deliberately.
3. Add a visible control — a chip row or a switch: **"My professions" / "All jobs"** — so a
   worker can deliberately browse everything. Default to their professions.
4. If the worker has no professions yet, show all jobs and a prompt to complete onboarding.
5. Keep the empty state useful: "No open jobs in your professions yet" with a button to
   switch to All jobs.

### Acceptance

- A plumbing-only worker sees no electrical jobs by default.
- The "All jobs" toggle reveals them.
- A worker with two professions sees both.
- Existing worker dashboard tests still pass, and a new test covers the filter.

---

## 7. Item 6 — splash off-centre

**Do not guess at this one.** The current layout is already centred:

```dart
Scaffold(backgroundColor: AppTheme.brandBlue,
  body: SafeArea(child: Column(
    mainAxisAlignment: MainAxisAlignment.center, children: [...]
```

A `Column` centres horizontally by default, and the native launch theme
(`android/app/src/main/res/drawable/launch_background.xml`) is a plain white background
with no image, so the OS splash cannot be off-centre either.

### Required process

1. Install the current APK on the device and photograph the first two seconds after launch.
2. Identify which of these you are actually looking at:
   - the Android 12+ system splash (app icon, before Flutter starts);
   - `SplashScreen` (blue background, yellow "Q" badge, "QuickFix" text, spinner);
   - `OnboardingCarousel` (first launch only, page dots at the bottom).
3. Reproduce with a large system font scale (Settings → Display → Font size) and with the
   device in split-screen — an overflow is the usual cause of content pushed sideways.
4. Fix only the layer that is actually wrong, and say in your report which one it was.

If you cannot reproduce it, **say so** and leave the code alone. A speculative layout
change here risks breaking a screen that currently works.

---

## 8. Item 7 — zoom job photos

A full-screen, pinch-zoom viewer already exists:

`core/widgets/local_photo_viewer.dart` → `InteractiveViewer(minScale: 1, maxScale: 4)`,
with a caption bar and optional delete. It is wired to portfolio, certifications and
dispute evidence — but **never to job images**.

Job images appear in three places and none is tappable:

| Screen | Rendering |
|---|---|
| `views/client/client_job_detail_screen.dart:385` | `PageView` of `Image.file` |
| `views/client/client_home_screen.dart:334` | `JobImageThumb` |
| `views/jobs/my_jobs_screen.dart:238` | `JobImageThumb` |
| `views/jobs/worker_dashboard_screen.dart:340` | `JobImageThumb` |

### Required change

- Wrap each job image (thumbnail and each `PageView` page) in an `InkWell`/`GestureDetector`
  that pushes `LocalPhotoViewer(imagePath: path, caption: job.title, imageStore: ...)`.
- `LocalPhotoViewer` needs an `imageStore`; the job screens already have access to
  `LocalImageStore` — inject it the same way the portfolio screen does.
- Keep the existing thumbnail size and border radius; only add the tap target.
- Show a subtle affordance (a small expand icon in the corner of the detail `PageView`, or
  `InkWell` ripple) so users know it is tappable.

### Acceptance

- Tapping a job photo anywhere opens it full-screen and pinch-zoom works (1×–4×).
- Back returns to the same scroll position.
- A photo that has been deleted from disk shows the viewer's existing "not a readable
  image" message rather than crashing.

---

## 9. Item 8 — remove a picked image before posting

`views/jobs/post_job_screen.dart` keeps `final List<XFile> _images` and renders it as a
`PageView` with page dots. The only control is an "add photo" button (line ~341). Once
picked, an image cannot be removed — and because it is a `PageView`, the user cannot even
tell which one they are looking at.

### Required change

1. Add a remove control for the **currently visible** image: a small `close` button in the
   top-left of the image area (opposite the add button), calling
   `setState(() => _images.removeAt(_page))`, then clamping `_page` so the `PageView` does
   not point past the end. Use a `PageController` and keep `_page` in sync with
   `onPageChanged`.
2. Better, and preferred: replace the bare `PageView` with a horizontal thumbnail strip
   under a large preview. Each thumbnail carries its own remove badge, so the target is
   unambiguous. Keep the 5-image cap and the existing card styling.
3. If the composer supports editing an existing job (`prefilled`), only remove the
   *newly added* entries; do not offer to delete images already saved to the job unless you
   also delete the file.
4. Show the counter: "3 of 5 photos".

### Acceptance

- Pick three images, remove the middle one, post — exactly two are attached, in the right order.
- The counter and dots stay correct after removals.
- Removing the last image returns to the empty placeholder.
- No `RangeError` when the page index exceeds the list length.

---

## 10. Working agreement

- Fix in the order 4 → 8 → 7 → 5 → 1 → 2 → 6. Items 4, 8, 7 and 5 are self-contained;
  1 touches rules-adjacent behaviour; 2 needs diagnosis; 6 may be un-reproducible.
- One conventional commit per item: `fix(auth): add password visibility toggle`.
- After each item: `flutter analyze --no-pub` must stay clean, and `flutter test` must not
  regress below 908 passed / 3 Windows-only failures.
- Do **not** change `docs/firestore/firestore.rules` unless an item genuinely requires it,
  and if you do, add an emulator case in `validation/firestore/rules.test.mjs`.
- Do **not** add packages. `InteractiveViewer` is in the framework; the password toggle is
  an `IconButton`.
- Do **not** touch item 3.

---

## 11. Report back

For each of the eight, one line: **fixed / not reproducible / not a bug**, the file you
changed, and the check you ran. Then a summary of anything you could not verify without a
device, and any place where this brief disagreed with the code.
