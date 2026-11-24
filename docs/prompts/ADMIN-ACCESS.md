# QuickFix — Admin Access in the Mobile App

> **Paste this as the task brief.** It is written as an imperative specification.
> Read §1–§4 before writing any code: §1 is binding, and §2 records a live defect
> you must not "rediscover" by guessing.

---

## 0. Mission

The project has a full admin surface on the web (`admin/`, React) — users, workers,
jobs, reports, languages, categories, analytics — but **the mobile app has no admin
experience at all**, and an admin who signs in on the phone is silently routed into the
client shell.

Build a real admin experience inside the Flutter app, and make admin sign-in reliable
and legible. An admin must be able to open the app, authenticate, and moderate — without
touching the web dashboard.

This is **not** a redesign of the client or worker apps. Those two shells must keep
working exactly as they do today.

---

## 1. Guardrails (binding — security critical)

1. **Never add an "admin" option to sign-up.** The role tiles stay `Client` and
   `Worker`. There is no in-app path to becoming an admin, ever.
2. **Never let the client write `role: 'admin'`.** The `users` create rule already
   enforces `role in ['user','worker']`. Do not relax it, do not add an exception.
3. **Admin is derived, never chosen.** After authentication, read
   `users/{uid}.role` and route on it. Never accept a role from a UI toggle, a query
   parameter, a deep link, or shared preferences.
4. **Fail closed.** Any admin screen that finds `role != 'admin'` (or a missing profile)
   must sign the session out and return to login. No partial render, no "read-only mode".
5. **Re-verify on resume.** If the app returns from background, re-check the role before
   showing admin data again. A demoted or deleted admin must not keep a live admin view.
6. **No new packages.** Not for tables, charts, date pickers, or state management.
7. **Views never touch Firestore.** All I/O in services; every service constructor-injectable
   (`widget.xService ?? XService()`), so widget tests can mock it.
8. **Reuse `AppTheme`.** Zero inline hex values. Card = radius 20 + 4 % black shadow +
   `borderGray` border (the de-facto style used across the app).
9. **Four states on every list**: loading, empty, error, data. A silent empty list is a bug.
10. **Destructive actions confirm and record a reason** where the schema supports it.
11. **Do not modify the client or worker shells**, their constructors, or their tests.
12. **Do not weaken security rules.** The only permitted rule additions are in §9.

---

## 2. Current state (verified — do not re-derive)

### 2.1 Routing

`mobile/lib/views/auth/app_shell.dart`:

```dart
UserRole.worker => WorkerShell(...),
// Admins use the client shell on mobile (the React dashboard is the
// primary admin surface); they explicitly map to a valid shell instead
// of silently falling back after a role parse failure.
UserRole.user || UserRole.admin => ClientShell(...),
```

Admins are deliberately folded into the client shell. That is the thing you are changing.

### 2.2 Sign-up

`mobile/lib/views/auth/signup_screen.dart` offers exactly two role tiles
(`UserRole.user`, `UserRole.worker`). `users` create rule:

```js
&& request.resource.data.role in ['user', 'worker']
```

So an admin profile can only be created out-of-band: Firebase Console, or
`backend/seed/create-accounts.js` with a service account.

### 2.3 Live defect you must fix as part of this task

On the real project (`quickfix-fyp`), `admin@quickfix.test` / `Admin@123` **exists and
authenticates** (uid `ct84PISHIHbjHkg71BC3NSZsBg13`), but `users/ct84PISHIHbjHkg71BC3NSZsBg13`
**does not exist** (Firestore returns 404). Sign-in therefore fails.

The user-visible result is a single generic string from the catch-all at
`login_screen.dart:65`:

> "Could not sign in or load your account. Check your credentials and connection, then retry."

…even though the credentials were correct. Worse, `AuthService.getUserProfile` performs a
second, unrelated read of `accountDeletions/{uid}` with `Source.server` and a **3 s
timeout**, and `rethrow`s when the profile is missing and that read fails — which is the
common case on mobile data. So a missing profile and a wrong password look identical.

**Both problems must be fixed** (see §7 A1 and §10).

### 2.4 What already exists that you should reuse

| Piece | Path | Notes |
|---|---|---|
| Shared list states | `core/widgets/empty_state.dart`, `error_state.dart`, `loading_list.dart`, `section_header.dart` | Built for exactly this |
| Status pill | `core/widgets/status_pill.dart` | Use for report/job/verification status |
| Avatars | `core/widgets/user_avatar.dart` | |
| Rank badge | `core/widgets/rank_badge.dart` | Show worker tier in the account list |
| Models | `UserModel`, `WorkerProfile`, `JobModel`, `Review`, `WorkerVerification`, `ServiceCategory`, `AppLanguage` | Reuse; do not duplicate |
| Services | `job_service`, `profile_service`, `review_service`, `verification_service`, `report_service`, `category_service`, `language_service` | Extend where it fits; do not fork behaviour |

**Note:** `mobile/lib/views/admin/report_screen.dart` is the *report-a-user* screen,
misfiled under `admin/`. Move it to `mobile/lib/views/reports/report_screen.dart`, update
its imports, and free `views/admin/` for the real admin screens.

### 2.5 What the rules already allow (no changes needed)

`docs/firestore/firestore.rules` already grants admins the writes below. Verified:

| Collection | Admin capability |
|---|---|
| `users` | `update` (block, role, verification flags) |
| `workers` | `create`, `update` (approve, block, verification) |
| `jobs` | `update`, `delete` |
| `reports` | `update`, `delete` (resolve / dismiss) |
| `disputes` | `update`, `delete` |
| `reviews` | `update`, `delete` |
| `payments` | `read`, `update`, `delete` |
| `payouts` | `read`, `update` |
| `workerVerifications` | `read`, `update` |
| `categories`, `languages` | `write` |
| `config/app`, `config/features` | `write` |

`isAdmin()` is defined as a `users/{uid}.role == 'admin'` lookup, so **the admin document
must exist** for any of this to work — which is exactly what is broken today.

`notifications` is **not** admin-readable (own-document only). See §9 if you build broadcast.

### 2.6 What the web dashboard does (mirror this behaviour, not its pixels)

`admin/src/api/*.ts` is the reference implementation. Exact payloads:

| Operation | Write |
|---|---|
| `blockUser(uid, blocked)` | `users/{uid}.blocked`, `updatedAt` |
| `approveWorker(uid, approved)` | `workers/{uid}.approved`, `updatedAt` |
| `blockWorker(uid, blocked)` | `workers/{uid}.blocked`, `updatedAt` |
| `reviewWorkerVerification(uid, decision)` | transaction: `workerVerifications/{uid}.status`, then `workers/{uid}.verification = {status, submittedAt, reviewedAt}`, `updatedAt` |
| `resolveReport(id, status, note, by)` | **transaction**: `reports/{id}` ← `status`, `resolutionNote`, `resolvedAt`, `resolvedBy`, `updatedAt`; and if `disputeId` is set, `disputes/{id}` ← `status`, `resolutionNote`, `reviewedAt`, `reviewedBy`. 12 s guard, "Resolution was not confirmed. Refresh before retrying." |
| `saveCategory(id, name, icon, isActive)` | `categories/{name}` |
| `saveLanguage(code, nativeName, englishName)` / `setLanguageActive` | `languages/{code}` |

`resolveReport` and `reviewWorkerVerification` **must** be transactions in the mobile
implementation too — two documents move together and a half-applied decision is worse than
a failed one.

---

## 3. Access model (the design decision — implement exactly this)

### 3.1 Sign-in stays where it is

Do **not** add an "Admin" tab, an "Admin login" button, or a separate route. An admin
signs in with the same email/password form as everyone else. The role is read from the
profile after authentication and decides the shell.

This is the only design that cannot be abused: there is no UI state that can be flipped to
claim admin rights, and no endpoint that grants them.

### 3.2 Routing table

| `users/{uid}.role` | Shell |
|---|---|
| `user` | `ClientShell` (unchanged) |
| `worker` | `WorkerShell` (unchanged) |
| `admin` | **`AdminShell`** (new) |
| missing document | **`ProfileMissingScreen`** (new, §7 A1) |

### 3.3 Admin can still see the client app

`AdminShell` profile tab gets a **"Open client view"** action that pushes `ClientShell`
(not `pushReplacement`) with the same user, so the admin can post a test job or check what
customers see. Back returns to admin. This is a navigation affordance, not a role change —
the admin's document is untouched.

### 3.4 Provisioning (documented, not in-app)

Add a short section to `README.md`:

- Create the Auth user (Console → Authentication → Add user), **or** run
  `backend/seed/create-accounts.js` with a service account.
- Create `users/{uid}` with `role: 'admin'`.
- The app can never do this itself, by design.

### 3.5 Make the admin mode obvious

The admin app bar carries a small `ADMIN` chip (10–12 px, `w700`, `brandBlue` on 10 % tint).
An admin should never wonder which mode they are in, and a screenshot of the app should be
unambiguous to an examiner.

---

## 4. Architecture

### 4.1 New files

```
mobile/lib/views/admin/
  admin_shell.dart                5-tab scaffold + role gate
  admin_dashboard_screen.dart     counts, queues, recent activity
  admin_reports_screen.dart       report queue
  admin_report_detail_screen.dart resolve / dismiss with note
  admin_accounts_screen.dart      users + workers, segmented
  admin_account_detail_screen.dart one account, role-aware sections
  admin_catalog_screen.dart       categories + languages, segmented
  admin_profile_screen.dart       identity, client view, sign out

mobile/lib/views/auth/
  profile_missing_screen.dart     authenticated but no users/{uid}

mobile/lib/services/
  admin_service.dart              moderation reads/writes + counts
  admin_catalog_service.dart      categories + languages CRUD

mobile/lib/models/
  admin_report_row.dart           thin row (report + reporter/target names)
  admin_account_row.dart          thin row (user or worker + moderation flags)
```

### 4.2 Modified files

- `views/auth/app_shell.dart` — route `admin` → `AdminShell`; add `ProfileMissingScreen`.
- `views/auth/login_screen.dart` — surface the real failure reason (§10).
- `services/auth_service.dart` — `getUserProfile` must stop `rethrow`ing on the
  `accountDeletions` probe; distinguish "missing profile" from "network error".
- `README.md` — provisioning section.

### 4.3 Why two services

`AdminService` owns moderation (accounts, reports, jobs). `AdminCatalogService` owns
categories and languages (create/rename/deactivate). Splitting keeps each testable with a
small mock surface, and mirrors the web's `api/` split. Both are constructor-injectable.

---

## 5. Design system

Reuse `AppTheme` verbatim. Summary of what matters here:

| Token | Use |
|---|---|
| `brandBlue #0D47A1` | admin app bar, primary actions, links |
| `ctaOrange #F57C00` | one primary CTA per screen |
| `dangerRed #E53935` | block, delete, dismiss-with-consequence |
| `successGreen #4CAF50` | approved, resolved |
| `accentYellow #FF9800` | pending, open, needs-attention |
| `textMuted #64748B` | meta lines |
| `bgLight #F5F5F5` | scaffold |
| `surfaceWhite` + `borderGray` | cards |

Type scale: screen title 20 `w800`; section header 13 `w700`; body 14; meta 12 `textMuted`;
chip 10–12 `w600–w700`.

Cards: radius 20, `borderGray` 1 px border, `Colors.black.withValues(alpha: 0.04)` shadow,
blur 8, offset (0,2). Page padding 14. Gap between cards 14.

Status colours: `open`/`pending` → amber; `resolved`/`verified` → green;
`dismissed`/`blocked` → `textMuted`; `cancelled` → `dangerRed`.

No gradients, no coloured surfaces, no custom page transitions.

---

## 6. Data contract

### 6.1 Reads

| Screen | Query | Notes |
|---|---|---|
| Dashboard | ``count()` aggregation` on `users`, `workers`, `jobs`; `reports where status == 'open'` count | **Do not** `onSnapshot` the whole `jobs` collection to count — the web dashboard does this and it is the wrong pattern at 15 k docs |
| Reports | `reports orderBy createdAt desc limit 50`, filtered client-side by status tab | Needs an index only if you add a `where` — prefer client-side filtering to avoid one |
| Accounts | `users orderBy createdAt desc limit 50`; `workers orderBy createdAt desc limit 50` | Segment switch loads the other list lazily |
| Account detail | `users/{uid}`, `workers/{uid}`, their last 10 `jobs`, last 5 `reviews`, `workerVerifications/{uid}` | One screen, role-aware sections |
| Catalog | `categories`; `languages orderBy englishName` | Both are world-readable |

### 6.2 Writes

Copy §2.6 exactly. Two rules:

- **Transactions** for `resolveReport` and `reviewVerification`. Both touch two documents.
- **Never** write `role` from the app. If you build "promote to admin", that is out of
  scope (§13) — it is a Console operation.

### 6.3 Blocking is currently decorative — fix it or say so

Verified today. `blocked` is enforced in **far fewer places than the web UI implies**:

| Path | Enforced? |
|---|---|
| Browse workers list | ✅ `profile_service.dart:259` filters them out |
| Worker sending a quote | ✅ `quote_service.dart:94` |
| Worker creating a quote (rules) | ✅ but inside the quotes feature, which is **OFF** |
| Assigning a quoted booking to a blocked worker (rules) | ✅ same gate — **OFF** |
| Blocked **worker** being assigned a normal job, chatting, completing work | ❌ nothing checks it |
| Blocked **user** signing in, posting jobs, sending messages | ❌ nothing checks it |

So with quotes disabled, a blocked account keeps almost all its capability. A moderation
button that changes a flag nobody reads is worse than no button — it creates false
confidence in a demo.

Minimum acceptable fix (client-side, no rule cost):

- After authentication, if `users/{uid}.blocked == true`, sign out immediately and show
  "This account has been suspended. Contact support." Do this before any shell mounts, for
  both roles.
- Add `blocked` to `UserModel` (optional, default `false`) so the check is typed.

Recommended (rules, one `get()` per write): add `notBlocked(uid)` and apply it to `jobs`
create, `messages` create and `reviews` create, plus job acceptance for workers. If you do
this, extend the emulator suite (§11) — a blocked user must be denied, and the tests must
fail if the helper is removed.

---

## 7. Screens

### A1. `ProfileMissingScreen` — `views/auth/profile_missing_screen.dart`

- **Purpose:** the authenticated-but-profileless state that is broken today. Without this,
  admins hit a generic error and cannot tell what is wrong.
- **Entry:** `AppShell`/login when `getUserProfile` returns `null` and the account is not
  pending deletion.
- **Reads:** `users/{uid}` (confirmed absent), `accountDeletions/{uid}`.
- **Writes:** none. Offers `Sign out`.
- **Sections:** icon, headline "Your profile is missing", body naming the exact uid, and a
  collapsible "What to do" block: create `users/<uid>` with `role`, or run the seed script.
  Copy must be specific — an FYP examiner may see this screen.
- **States:** no network → "Can't reach Firestore" variant with retry.
- **Notes:** never auto-create the document. The rules forbid it for admins, and silently
  creating a `user` profile for an admin would be worse than failing.

### A2. `AdminShell` — `views/admin/admin_shell.dart`

- **Purpose:** container + role gate.
- **Entry:** `AppShell` when `role == admin`.
- **Reads:** live `users/{uid}` stream — if `role` stops being `admin`, sign out and pop to
  login immediately.
- **Tabs:** Overview · Reports · Accounts · Catalog · Profile.
- **Chrome:** app bar with `ADMIN` chip; bottom nav like the other shells (20 px icons,
  `ctaOrange` selected, `SafeArea(top:false)`).
- **Notes:** keep tab state alive with the same `_KeepAlive` pattern used by
  `ClientShell`/`WorkerShell` so switching tabs doesn't refetch.

### A3. `AdminDashboardScreen`

- **Purpose:** the answer to "what needs attention right now".
- **Reads:** counts (users, workers, jobs, open reports); latest 5 open reports; latest 5
  pending verifications.
- **Sections:** (1) 2×2 stat cards; (2) "Needs attention" — open reports and pending
  verifications with counts and a tap-through; (3) recent activity list.
- **States:** loading skeleton cards, error with retry, empty ("Nothing needs attention").
- **Notes:** counts via ``count()` aggregation`, never by downloading collections.

### A4. `AdminReportsScreen`

- **Purpose:** the moderation queue.
- **Reads:** `reports` newest first, 50.
- **Sections:** segmented filter — Open / Resolved / Dismissed; rows show reason, reporter
  → reported, age, and a status pill; tap → detail.
- **States:** loading, empty per tab, error.
- **Notes:** open count in the tab label.

### A5. `AdminReportDetailScreen`

- **Purpose:** judge a report with enough context to decide.
- **Reads:** the report; reporter and reported profiles; the reported worker's rating,
  completed jobs, prior report count; linked job if `jobId` is set.
- **Writes:** `resolveReport` transaction (§2.6).
- **Sections:** (1) report summary; (2) people involved (two cards, tap-through);
  (3) evidence — job link, review excerpts; (4) decision panel: note field (required for
  `resolved`, optional for `dismissed`), `Resolve` (green) and `Dismiss` (muted), both
  behind a confirm.
- **States:** submitting spinner, 12 s timeout message, success pops with a snackbar.
- **Notes:** never allow resolving twice — if `status != 'open'`, show the existing
  decision read-only.

### A6. `AdminAccountsScreen`

- **Purpose:** find and act on any account.
- **Reads:** `users` or `workers` (segmented), 50 each, newest first.
- **Sections:** segmented Users / Workers; search by name or email (client-side over the
  loaded page); rows show avatar, name, role chip, rating (workers), blocked badge, and
  rank emblem (workers).
- **States:** loading, empty, error; search with no match gets its own empty copy.
- **Notes:** blocked accounts sort with a visible badge, not to the bottom — an admin is
  usually looking for them.

### A7. `AdminAccountDetailScreen`

- **Purpose:** one place for every action on one account.
- **Reads:** account doc, recent jobs, recent reviews, verification (workers).
- **Writes:** `blockUser`, `approveWorker`, `blockWorker`, `reviewWorkerVerification`.
- **Sections:** identity header (avatar, name, email, phone, joined, role, status chips);
  stat strip; tabs — Activity / Reviews / Moderation; verification card for workers with
  proof thumbnails and Approve / Reject (rejection requires a note).
- **States:** loading, error, action-in-flight, success snackbar.
- **Notes:** every destructive action opens a confirm sheet naming the account. Blocking a
  worker must also warn that it hides them from browse and blocks quotes.

### A8. `AdminCatalogScreen`

- **Purpose:** the two admin-managed lists the app depends on.
- **Reads:** `categories`, `languages`.
- **Writes:** `saveCategory`, `updateCategory`, `setCategoryActive`, `saveLanguage`,
  `setLanguageActive`.
- **Sections:** segmented Categories / Languages; rows with active toggle; `+ Add` opens a
  sheet.
- **States:** loading, empty, error, validation.
- **Notes:** category `name` must match a `JobCategory` enum value — validate against the
  enum and explain the constraint in the error. Languages: `code` is the doc id, BCP-47
  pattern `^[a-z]{2,3}(-[A-Z]{2})?$`, no duplicates. **Deactivate, never delete** —
  existing `preferredLanguage` values reference these codes.

### A9. `AdminProfileScreen`

- **Purpose:** identity + escape hatches.
- **Reads:** current user, app version (`String.fromEnvironment('APP_VERSION')`).
- **Writes:** sign out.
- **Sections:** identity card with `ADMIN` chip; `Open client view`; app version and build;
  `Sign out` (confirm).
- **Notes:** `Open client view` pushes `ClientShell` with the same user and pops back to
  admin — do not mutate the role.

---

## 8. Service API

```dart
class AdminService {
  // counts — `count()` aggregation, never full downloads
  Future<AdminCounts> counts();

  Stream<List<AdminReportRow>> watchReports({int limit = 50});
  Future<AdminReportDetail?> reportDetail(String reportId);
  Future<void> resolveReport({
    required String reportId,
    required String status,          // 'resolved' | 'dismissed'
    required String note,
    required String resolvedBy,
  });                                 // transaction, 12s guard

  Stream<List<AdminAccountRow>> watchUsers({int limit = 50});
  Stream<List<AdminAccountRow>> watchWorkers({int limit = 50});
  Future<void> setUserBlocked(String uid, bool blocked);
  Future<void> setWorkerApproved(String uid, bool approved);
  Future<void> setWorkerBlocked(String uid, bool blocked);
  Future<void> reviewVerification(String uid, String decision, {String? note});
  Future<void> cancelJob(String jobId, String reason);
}

class AdminCatalogService {
  Stream<List<ServiceCategory>> watchCategories();
  Stream<List<AppLanguage>> watchLanguages();
  Future<void> saveCategory({required String name, required String icon, required bool isActive});
  Future<void> renameCategory({required String from, required String to});
  Future<void> setCategoryActive(String name, bool active);
  Future<int> jobCountForCategory(String name);   // warn before rename
  Future<void> saveLanguage({required String code, required String nativeName, required String englishName});
  Future<void> setLanguageActive(String code, bool active);
}
```

`AdminCounts` is a small value class. Every method must be mockable — no static Firestore
access inside widgets.

---

## 9. Security rules

**No changes required** for everything in §7. The admin writes already exist (§2.5).

Permitted additions only:

1. **Block enforcement** (§6.3), if you take the recommended path: a `notBlocked(uid)`
   helper applied to `jobs` create, `messages` create, `reviews` create.
2. **Admin read on `notifications`**, only if you build a broadcast feature — which is out
   of scope. Skip it.

If you touch the rules, you must add emulator cases (§11). Do not deploy rules; that is an
operator action.

---

## 10. Error handling (the part that makes this usable)

Replace the catch-all in `login_screen.dart` with specific outcomes:

| Failure | Message |
|---|---|
| `user-not-found` / `invalid-credential` | "No account matches that email and password." |
| `user-disabled` | "This account has been disabled." |
| `too-many-requests` | "Too many attempts. Try again in a few minutes." |
| network / timeout | "Couldn't reach the server. Check your connection." |
| profile missing | → `ProfileMissingScreen` |
| `blocked == true` | "This account has been suspended. Contact support." |
| anything else | keep the generic string **plus** a short error code |

In `AuthService.getUserProfile`, stop `rethrow`ing the `accountDeletions` probe failure.
Wrap it so that a failed probe yields `pending = false` and a missing profile returns
`null` — the caller then shows `ProfileMissingScreen` instead of pretending the password
was wrong. That single change is what made this bug take an hour to diagnose.

---

## 11. Testing

Per screen (`mobile/test/admin_<name>_test.dart`): loading, empty, error, populated, and
the primary action with a mocked service asserting the exact call. Destructive actions:
the confirm sheet appears and cancelling performs **no** write.

Service tests: `resolveReport` builds the correct two-document batch; `reviewVerification`
writes both docs; counts parse.

Rules emulator (`validation/firestore/rules.test.mjs`), add:

- non-admin **denied**: `blockUser`, `resolveReport`, `saveCategory`, `setWorkerApproved`;
- admin **allowed** on the same four;
- if you add block enforcement: blocked user denied on `jobs` create and `messages` create;
- an admin whose `users/{uid}` document is deleted loses admin rights (the `isAdmin()`
  lookup returns false).

The emulator needs Node ≥ 24 and Java 21. If your sandbox lacks Java 21, write the cases
and let CI run them — do not claim they passed.

---

## 12. Definition of done (per screen)

- [ ] Correct file under `views/admin/`, class `<Name>Screen`.
- [ ] Services injected via nullable params, defaulting to real instances.
- [ ] No Firestore call in the view.
- [ ] Four states implemented.
- [ ] `AppTheme` tokens only; zero inline hex.
- [ ] Card style matches §5.
- [ ] Destructive actions confirm, and state the consequence in the sheet.
- [ ] Keys on test-relevant widgets.
- [ ] Test file written.
- [ ] `flutter analyze` clean.
- [ ] Existing client/worker tests untouched and still passing.
- [ ] One conventional commit per screen: `feat(admin): add AdminReportsScreen`.

---

## 13. Build order

1. **Access** — `AppShell` routing, `ProfileMissingScreen`, login error mapping,
   `blocked` check at sign-in. Ship this alone first: it is the actual bug.
2. **Shared bits** — `AdminService` skeleton + `AdminAccountRow`/`AdminReportRow`,
   `AdminShell` with five empty tabs.
3. **Dashboard** — counts only; proves the wiring end to end.
4. **Reports** — queue + detail + transaction. Highest moderation value.
5. **Accounts** — list + detail + block/approve/verification.
6. **Catalog** — categories + languages.
7. **Profile** — client-view switch, sign out.
8. **Rules emulator cases** and README provisioning section.

Each step must leave the app runnable.

---

## 14. Out of scope

- Promoting or demoting roles from the app (Console only).
- Broadcast notifications, CSV export, audit log tables.
- Charts beyond the four count cards.
- Any change to client/worker behaviour, pricing, quotes (stay OFF), payments (simulated).
- Deploying rules, seeding live data, or touching production config.

---

## 15. Report back

1. Screens added, with paths.
2. Services/models added or changed; whether the Firestore shape changed.
3. Checks **actually run** with numbers, and which you could not run and why.
4. Whether the live admin account (`ct84PISHIHbjHkg71BC3NSZsBg13`) now resolves, if you
   were able to test it.
5. Anything you deliberately left out, and any place where this brief conflicted with the
   code — and which one you followed.

Do not report a screen done if any box in §12 is unchecked.
