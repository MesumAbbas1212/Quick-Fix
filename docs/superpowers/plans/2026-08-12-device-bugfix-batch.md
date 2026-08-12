# Device Bugfix Batch Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix the 10 device-verified bugs (profile refresh/avatar, workers vanish, job/review visibility, conversation list, hardcoded My Jobs/Suggested Jobs, role-specific settings, accept→My Jobs realtime) reported by the user on 2026-08-12.

**Architecture:** Realtime Firestore streams everywhere (user, worker profile, jobs, conversations); path-aware avatar loading (local vs network); remove all hardcoded sample lists and stub shells; conversation list with New Chat search; role-specific settings menus.

**Tech Stack:** Flutter, Firebase Firestore, mocktail tests. App dir `D:\OpenCode_Projects\FYP Project\mobile`, `$env:PATH = "D:\flutter\bin;$env:PATH"`. Commits in `mobile` scope. Device: Redmi Note 11 `mflrizqk6hvcvko7` (MIUI; user taps manually; adb at `$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe`; screenshots corrupt in PS — use `cmd /c` redirection).

**Baseline:** 142 tests green, `flutter analyze` = 8 pre-existing (4 sealed-mock warnings + 4 curly-braces infos). Rules at `docs/firestore/firestore.rules`; NO `firestore.indexes.json` — every `where+orderBy` stream may require a composite index (user reported jobs appearing "split second" then vanishing and zero reviews — consistent with cache-first snapshot then index failure; verify on device after index deploy).

---

### Task 1: Path-aware avatar loading (UserAvatar + edit preview)

**Files:**
- Modify: `lib/core/widgets/user_avatar.dart`
- Modify: `lib/views/profile/edit_profile_screen.dart`
- Test: `test/shared_widgets_test.dart` (extend), `test/edit_profile_screen_test.dart` (extend)

- [ ] **Step 1: Write failing tests**

In `test/shared_widgets_test.dart` add:

```dart
testWidgets('UserAvatar loads local avatar path via injected loader', (tester) async {
  const bytes = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47]);
  await tester.pumpWidget(MaterialApp(
    home: UserAvatar(
      fullName: 'A B',
      avatarUrl: '/data/app_flutter/quickfix_avatars/a.png',
      imageLoader: (_) async => bytes,
    ),
  ));
  await tester.pump();
  expect(find.byType(Image), findsOneWidget);
  expect(find.text('AB'), findsNothing);
});

testWidgets('UserAvatar falls back to initials when local read fails', (tester) async {
  await tester.pumpWidget(MaterialApp(
    home: UserAvatar(
      fullName: 'A B',
      avatarUrl: '/data/app_flutter/quickfix_avatars/a.png',
      imageLoader: (_) async => null,
    ),
  ));
  await tester.pump();
  expect(find.text('AB'), findsOneWidget);
});
```

In `test/edit_profile_screen_test.dart` add:

```dart
testWidgets('existing local avatar renders from bytes, not network', (tester) async {
  final user = _user()..avatarUrl = '/data/app_flutter/quickfix_avatars/a.png'; // copyWith instead
  // pump EditProfileScreen with user whose avatarUrl is a local path;
  // expect Image widget present and no Image.network (find.byType(ImageNetwork-less check via errorBuilder path)
});
```

- [ ] **Step 2: Run and verify fail**

Run: `flutter test test/shared_widgets_test.dart test/edit_profile_screen_test.dart` — new tests fail (UserAvatar has no `imageLoader` param / renders `Image.network`).

- [ ] **Step 3: Implement**

`UserAvatar`: add `final Future<Uint8List?> Function(String path)? imageLoader;` (default null → `LocalImageStore().readImage`). Build: if `avatarUrl` starts with `http://` or `https://` → `Image.network` (existing behavior); else → `FutureBuilder` on imageLoader → `Image.memory` or `_initialsCircle`.

`EditProfileScreen._avatarImageOrInitials`: same logic — local path → `FutureBuilder` reading `widget.imageStore.readImage(path)` + preview fallback; keep `Image.network` only for http(s).

Add `import 'dart:convert';` + `import 'package:quickfix/services/local_image_store.dart';` where needed. `Uint8List` import already present in edit screen.

- [ ] **Step 4: Run full suite + analyze**

Run: `flutter test` (expect 144+), `flutter analyze` (expect only the 8 pre-existing).

- [ ] **Step 5: Commit**

```bash
git commit -m "fix(avatar): render local avatar paths from disk, network only for URLs"
```

---

### Task 2: Live user + worker profile streams (name/avatar/phone update instantly)

**Files:**
- Modify: `lib/services/auth_service.dart`
- Modify: `lib/services/profile_service.dart`
- Modify: `lib/views/auth/app_shell.dart`
- Modify: `lib/views/worker/worker_shell.dart`
- Modify: `lib/views/client/client_shell.dart`
- Test: `test/app_shell_test.dart` (extend)

- [ ] **Step 1: Write failing test**

In `test/app_shell_test.dart`:

```dart
testWidgets('AppShell reflects user profile updates from stream', (tester) async {
  final auth = MockAuthService();
  final updates = StreamController<UserModel>();
  when(() => auth.watchUser('u1')).thenAnswer((_) => updates.stream);
  when(() => auth.getUserProfile('u1')).thenAnswer((_) async => _user(UserRole.user));
  // pump AppShell(user: _user(UserRole.user), authService: auth) ... (AppShell gains authService param)
  // emit _user(UserRole.user).copyWith(fullName: 'New Name');
  // expect(find.textContaining('New Name'), findsOneWidget);
});
```

AppShell must expose `AuthService? authService` and wrap its build in `StreamBuilder<UserModel>` keyed on `auth.watchUser(widget.user.uid)`, falling back to `widget.user` when no stream data yet.

- [ ] **Step 2: Run and verify fail** — `flutter test test/app_shell_test.dart` fails (no param/stream).

- [ ] **Step 3: Implement**

`AuthService`:

```dart
Stream<UserModel?> watchUser(String uid) =>
    _firestore.collection('users').doc(uid).snapshots().map(
        (doc) => doc.exists ? UserModel.fromMap(doc.data()!, doc.id) : null);
```

`ProfileService`:

```dart
Stream<WorkerProfile?> watchWorkerProfile(String uid) =>
    _workersCollection.doc(uid).snapshots().map((doc) =>
        doc.exists ? WorkerProfile.fromMap(doc.data()!, doc.id) : null);
```

`AppShell`: add `final AuthService? authService;` — build stays stateless; add `StreamBuilder<UserModel?>` provider wrapper: when `authService == null` render current behavior; else listen `watchUser(user.uid)`, pass `snapshot.data ?? widget.user` into the role switch. (Widget remains const-compatible: use `widget.` fields.)

`ClientShell`/`WorkerShell`: pass-through `authService`/`profileService` constructors (optional) so tests can inject; shells render with the streamed `user`.

- [ ] **Step 4: Run full suite + analyze** — all green, 8 pre-existing.

- [ ] **Step 5: Commit**

```bash
git commit -m "feat(profile): realtime user and worker-profile streams through shells"
```

---

### Task 3: Fix workers vanishing (availability filter) + seed-agnostic search

**Files:**
- Modify: `lib/services/profile_service.dart`
- Modify: `lib/views/client/workers_screen.dart`
- Test: `test/workers_screen_test.dart` (extend), `test/profile_service_test.dart` (new if none)

- [ ] **Step 1: Write failing test**

In `test/workers_screen_test.dart`:

```dart
testWidgets('workers still listed when location granted but workers lack isAvailable', (tester) async {
  // fake ProfileService.searchWorkers returns 2 WorkerProfile with no isAvailable
  // fake LocationService.getCurrentLocation returns a GeoPoint
  // pump WorkersScreen -> expect both worker names visible
});
```

New `test/profile_service_test.dart`: fake Firestore (mocktail `Mock` of `FirebaseFirestore` + `CollectionReference`) verifying `searchWorkers(fromLocation: point)` does NOT add `where('isAvailable', isEqualTo: true)` and returns workers without the field.

- [ ] **Step 2: Run and verify fail** — current code filters `isAvailable == true` → empty.

- [ ] **Step 3: Implement**

`ProfileService.searchWorkers`: remove the `if (fromLocation != null) query = query.where('isAvailable', isEqualTo: true);` branch. Availability filtering moves client-side: `workers.where((w) => w.isAvailable ?? true)` ONLY as a final explicit flag `onlyAvailable: false` param default false. Distance filter in Dart stays.

- [ ] **Step 4: Full suite + analyze green.** — verify `flutter test`.

- [ ] **Step 5: Commit**

```bash
git commit -m "fix(workers): stop filtering by isAvailable in query; show all workers with distance in Dart"
```

---

### Task 4: Realtime jobs (watchOpenJobs + watchWorkerJobs) + real Accept flow

**Files:**
- Modify: `lib/views/jobs/worker_dashboard_screen.dart`
- Modify: `lib/views/jobs/my_jobs_screen.dart`
- Modify: `lib/views/jobs/job_request_screen.dart`
- Test: `test/worker_dashboard_test.dart` (new), `test/my_jobs_screen_test.dart` (new)

- [ ] **Step 1: Write failing tests**

`test/worker_dashboard_test.dart`:

```dart
testWidgets('suggested jobs stream from JobService', (tester) async {
  // fake JobService.watchOpenJobs -> Stream.value([job])
  // pump WorkerDashboardScreen(user: worker, jobService: fake) -> expect job title
});

testWidgets('accept writes assignJob with worker uid', (tester) async {
  // open JobRequestScreen via tap; tap Accept; verify fakeJobService.assignJob(jobId, workerUid)
});
```

`test/my_jobs_screen_test.dart`:

```dart
testWidgets('My Jobs lists worker jobs from stream', (tester) async {
  // fake JobService.watchWorkerJobs(uid) -> Stream.value([job1, job2])
  // pump MyJobsScreen(workerId: uid, jobService: fake) -> expect titles
});
```

- [ ] **Step 2: Run and verify fail**

Run: `flutter test test/worker_dashboard_test.dart test/my_jobs_screen_test.dart` — fail (widgets use hardcoded lists).

- [ ] **Step 3: Implement**

`WorkerDashboardScreen`: replace `_suggestedJobs` list with `StreamBuilder<List<JobModel>>(stream: _jobService.watchOpenJobs())`; add optional `JobService? jobService`; pass `workerId: widget.user.uid` context onward. Keep header/availability UI.

`JobRequestScreen`: add params `{required JobModel job, required String workerId, required JobService jobService, VoidCallback? onAccept, VoidCallback? onDecline}` — Accept: `await jobService.assignJob(job.id, workerId); onAccept?.call(); Navigator.pop`. Decline: `onDecline?.call(); Navigator.pop` (job stays open).

`MyJobsScreen`: change to `MyJobsScreen({required String workerId, JobService? jobService})`; body = `StreamBuilder` on `watchWorkerJobs(workerId)`; keep `_filters` All/Active/Pending/Completed applied to stream data; replace hardcoded `_jobs`.

Update `WorkerShell` to pass `workerId: widget.user.uid, jobService:` into `MyJobsScreen` and `WorkerDashboardScreen`.

- [ ] **Step 4: Update existing tests referencing MyJobsScreen/WorkerDashboard hardcoded fixtures; full suite + analyze green.**

- [ ] **Step 5: Commit**

```bash
git commit -m "feat(jobs): realtime suggested + my-jobs streams; accept assigns job to worker"
```

---

### Task 5: Conversations list screen with New Chat search

**Files:**
- Create: `lib/views/chat/conversations_screen.dart`
- Create: `lib/views/chat/new_chat_screen.dart`
- Modify: `lib/views/client/client_shell.dart`
- Modify: `lib/views/worker/worker_shell.dart`
- Modify: `lib/views/chat/chat_screen.dart` (constructor cleanups only if needed)
- Test: `test/conversations_screen_test.dart` (new), `test/new_chat_screen_test.dart` (new)
- Modify: `test/app_shell_test.dart` (Messages tab now shows ConversationsScreen)

- [ ] **Step 1: Write failing tests**

`test/conversations_screen_test.dart`:

```dart
testWidgets('empty state when no conversations', (tester) async {
  // fake ChatService.watchConversations('u1') -> Stream.value([])
  // pump ConversationsScreen(user) -> expect 'No conversations yet'
});

testWidgets('lists conversations with peer name + last message', (tester) async {
  // fake watchConversations -> [ConversationPreview(participants: ['u1','w2'], lastMessage: 'hi', lastMessageAt: now)]
  // fake AuthService.getUserProfile('w2') -> UserModel(fullName: 'Ali Worker')
  // expect 'Ali Worker' and 'hi' visible; tap opens ChatScreen with peerId w2
});

testWidgets('New Chat opens worker search', (tester) async {
  // tap 'New Chat' -> find.byType(NewChatScreen)
});
```

`test/new_chat_screen_test.dart`: fake `ProfileService.searchWorkers` returns 2 workers; typing in search field filters; tapping a worker opens `ChatScreen(peerId: worker.uid, peerName: worker.fullName, myId: user.uid)`.

- [ ] **Step 2: Run and verify fail** — screens don't exist.

- [ ] **Step 3: Implement**

`ConversationsScreen({required UserModel user, ChatService? chatService, AuthService? authService})`: `StreamBuilder` on `watchConversations(user.uid)`; each tile: resolve peer (`participants.where((p) => p != user.uid).first`), peer name via `FutureBuilder` on `authService.getUserProfile(peerId)` (cache in `Map<String,String>`), show `UserAvatar`, lastMessage, `lastMessageAt` relative time, unreadCount badge; tap → `ChatScreen(peerName: name, peerId: peerId, myId: user.uid)`. FAB/button "New Chat" → `NewChatScreen`.

`NewChatScreen({required UserModel user, ProfileService? profileService, AuthService? authService})`: `searchWorkers()` with optional text filter (name/professions contains); `TextField` onChanged filters; list tiles → `ChatScreen(peerName: fullName, peerId: uid, myId: user.uid)`; empty state "No workers found".

`ClientShell`/`WorkerShell`: Messages tab → `ConversationsScreen(user: user, chatService:…)` (injectables passed through). Remove hardcoded `ChatScreen` from both shells.

- [ ] **Step 4: Update app_shell_test.dart Messages assertions (expect ConversationsScreen not ChatScreen). Full suite + analyze.**

- [ ] **Step 5: Commit**

```bash
git commit -m "feat(chat): conversations list with New Chat worker search"
```

---

### Task 6: Role-specific profile settings + worker professional info + persistent availability

**Files:**
- Modify: `lib/views/profile/profile_screen.dart`
- Create: `lib/views/profile/worker_pro_info_screen.dart`
- Modify: `lib/views/jobs/worker_dashboard_screen.dart` (availability persists)
- Modify: `lib/views/worker/worker_shell.dart` (pass workerProfile stream + services)
- Test: `test/profile_screen_test.dart` (new), `test/worker_pro_info_screen_test.dart` (new)

- [ ] **Step 1: Write failing tests**

`test/profile_screen_test.dart`:

```dart
testWidgets('client settings show only account items', (tester) async {
  // pump ProfileScreen(user: client, reviewService: fake)
  // expect 'My Posted Jobs' and 'Help & Support'; expect 'Availability' and 'Professional Info' findsNothing
});

testWidgets('worker settings show availability, professional info, reviews', (tester) async {
  // pump ProfileScreen(user: worker, workerProfile: fake) with fake ProfileService
  // expect 'Availability', 'Professional Info', 'Reviews' present
});

testWidgets('availability toggle persists via ProfileService', (tester) async {
  // toggle -> verify fakeProfileService.setAvailability(uid, false) called
});
```

`test/worker_pro_info_screen_test.dart`: fields prefilled from WorkerProfile; Save calls `fakeProfileService.saveWorkerProfile` with edited values and pops; professions multi-select from `JobCategory`.

- [ ] **Step 2: Run and verify fail.**

- [ ] **Step 3: Implement**

`ProfileScreen`: add optional `ProfileService? profileService`; `_buildMenuCard` becomes role-aware:
- Worker: Availability (Switch → `profileService.setAvailability(uid, v)`; initial value from `workerProfile?.isAvailable ?? true`), Professional Info → `WorkerProInfoScreen(workerProfile, profileService)`, Reviews (existing tile header), Help & Support.
- Client: My Posted Jobs → `ClientHomeScreen(user: _user)`, Account (Edit Profile), Help & Support.
Remove cross-role stubs ('My Job History' on client; reviews/menu only worker extras). Keep `_buildReviewsCard` only for `_isWorker` with streamed `workerProfile` (Task already done — keep using `watchReviewsForWorker(workerProfile?.uid ?? user.uid)`); empty state already 'No reviews yet'.

`WorkerProInfoScreen({required WorkerProfile profile, required ProfileService profileService})`: name (read-only), About (multiline), min/max budget (numeric), professions (FilterChips from `JobCategory.values`), languages (chips: English/Urdu/Punjabi); Save → `saveWorkerProfile(profile.copyWith(...))` → pop with SnackBar 'Professional info saved'.

`WorkerDashboardScreen` availability: on toggle also `_profileService.setAvailability(user.uid, value)` (inject `ProfileService?`); initial `_isAvailable` from `widget.workerProfile?.isAvailable ?? true`; listen to profile stream if provided (rebuild on change).

`WorkerShell`: fetch worker profile: `StreamBuilder<WorkerProfile?>` on `ProfileService.watchWorkerProfile(user.uid)` feeding `WorkerDashboardScreen` + `ProfileScreen` (replaces the never-set `workerProfile`).

- [ ] **Step 4: Full suite + analyze green.**

- [ ] **Step 5: Commit**

```bash
git commit -m "feat(profile): role-specific settings, worker pro-info editor, persistent availability"
```

---

### Task 7: Firestore composite indexes + rules alignment (deploy + device verify)

**Files:**
- Create: `docs/firestore/firestore.indexes.json`
- Modify (doc only): `docs/firestore/firestore.rules` — no functional change; verify rules match all collections used.

- [ ] **Step 1: Add indexes for every used composite query**

```json
{
  "indexes": [
    { "collectionGroup": "jobs", "queryScope": "COLLECTION", "fields": [
      { "fieldPath": "userId", "order": "ASCENDING" },
      { "fieldPath": "createdAt", "order": "DESCENDING" } ] },
    { "collectionGroup": "jobs", "queryScope": "COLLECTION", "fields": [
      { "fieldPath": "status", "order": "ASCENDING" },
      { "fieldPath": "createdAt", "order": "DESCENDING" } ] },
    { "collectionGroup": "jobs", "queryScope": "COLLECTION", "fields": [
      { "fieldPath": "workerId", "order": "ASCENDING" },
      { "fieldPath": "createdAt", "order": "DESCENDING" } ] },
    { "collectionGroup": "reviews", "queryScope": "COLLECTION", "fields": [
      { "fieldPath": "workerId", "order": "ASCENDING" },
      { "fieldPath": "createdAt", "order": "DESCENDING" } ] },
    { "collectionGroup": "conversations", "queryScope": "COLLECTION", "fields": [
      { "fieldPath": "participants", "arrayConfig": "CONTAINS" },
      { "fieldPath": "lastMessageAt", "order": "DESCENDING" } ] },
    { "collectionGroup": "conversations", "queryScope": "COLLECTION", "fields": [
      { "fieldPath": "participants", "arrayConfig": "CONTAINS" },
      { "fieldPath": "lastMessageAt", "order": "ASCENDING" } ] }
  ],
  "fieldOverrides": []
}
```

- [ ] **Step 2: Ask user to deploy rules + indexes** via Firebase console (Firestore → Indexes → add from JSON) or `firebase deploy --only firestore`. Record result in plan.

- [ ] **Step 3: Reconnect device, reinstall APK, reproduce:**

Reproduce flow (user taps, model screenshots via cmd/c adb exec-out screencap):
1. Client login → post a job with image → Home shows job persistently.
2. Workers tab → workers visible; open detail → reviews section shows 'No reviews yet' (no error text = index OK).
3. Rate worker on a completed job → review appears in worker detail live.
4. Messages tab → empty state; New Chat → pick worker → send message → conversation appears in list.
5. Profile: change name + avatar → Home greeting + avatar update immediately without re-login.
6. Worker login → accept a job → appears in My Jobs instantly; availability toggle persists after restart; Professional Info shows streamed data + editable.

- [ ] **Step 4: logcat sweep** — `adb logcat -d` grep `E/flutter|FirebaseException|permission-denied|requires an index`; fix anything surfaced test-first.

- [ ] **Step 5: User sign-off + final gate**

Run: `flutter test` (full) + `flutter analyze` (only 8 pre-existing). Commit (in `mobile` if code touched, else root): `docs(firestore): declare composite indexes for realtime queries` at repo root.

---

## Definition of Done

- All 10 reported bugs verified fixed on device by the user (both roles).
- `flutter test` green (~150+), analyze: zero NEW issues (8 pre-existing only).
- Conversations list replaces hardcoded Sarah Ahmed; New Chat search works.
- Accept writes to Firestore; My Jobs + Suggested Jobs realtime.
- Role-specific settings confirmed on device.