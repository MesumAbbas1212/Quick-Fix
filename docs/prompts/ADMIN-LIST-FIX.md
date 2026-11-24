# QuickFix — Fix the admin account lists and seed moderation data

> **Paste as the task brief.** Two verified defects plus a data-seeding task.
> Do not re-diagnose from scratch — §1 has the evidence.

---

## 0. Symptoms reported

On the mobile admin app (built from `arena/f4c30e79-quick-fix`, HEAD `b05ac18`):

- **Overview** shows 77 users, 49 workers, ~15 k jobs, 0 reports — the counts are correct.
- **Accounts → Users** lists **1** account.
- **Accounts → Workers** lists **none**.
- **Reports** is empty, and the demo needs real report data to look credible.

The Overview numbers come from `count()` aggregations, which see every document. The
lists come from different queries, which do not. That gap is the bug.

---

## 1. Root causes (verified against the live `quickfix-fyp` database)

### 1.1 Users tab — the limit is applied before the filter

`mobile/lib/services/admin_service.dart`:

```dart
Stream<List<AdminAccountRow>> watchUsers({int limit = 50}) =>
    _firestore.collection('users')
        .orderBy('createdAt', descending: true)
        .limit(limit)                                   // <-- 50 arbitrary docs
        .snapshots()
        .map((snapshot) => snapshot.docs
            .where((doc) => doc.data()['role'] == 'user')   // <-- filter after
            ...);
```

The query takes the **50 newest documents regardless of role**, then filters to
`role == 'user'` in Dart.

Live data proves the consequence. Running the app's exact query:

```
query returned: 50 docs
roles: { worker: 49, user: 1 }
after role=='user' filter: 1
```

The 50 newest `users` are 49 worker accounts plus one client. The other 25 clients are
older and never enter the window. Hence "1 account".

The original author filtered client-side to avoid a composite index — but that trades
correctness for convenience, and the trade is invisible until the data grows.

### 1.2 Workers tab — the enrichment query needs an index that is not deployed

```dart
Stream<List<AdminAccountRow>> watchWorkers({int limit = 50}) =>
    _firestore.collection('workers').orderBy('createdAt', descending: true).limit(limit)
        .snapshots().asyncMap((snapshot) async {
          return Future.wait(snapshot.docs.map((doc) async {
            final user = await _firestore.collection('users').doc(doc.id).get();
            final completed = await _firestore.collection('jobs')
                .where('workerId', isEqualTo: doc.id)
                .where('status', isEqualTo: 'completed')
                .where('completedAt', isGreaterThanOrEqualTo: cutoff)
                .count().get();
            ...
```

`firestore.indexes.json` **declares** `jobs: workerId + status + completedAt`, but the
index is not live. Verified — the query returns:

```
400 The query requires an index. You can create it here:
https://console.firebase.google.com/.../indexes?create_composite=...
```

`asyncMap` propagates that error, the `StreamBuilder` renders `AdminError`, and the tab
looks empty. One failing enrichment blanks all 49 workers.

Even once indexed, this is an **N+1 pattern**: 49 workers × 2 queries = 98 reads on
every snapshot emission.

### 1.3 Reports — genuinely zero documents

```
reports count: 0
```

Nothing has ever created a report. This is missing data, not a code bug.

---

## 2. Fixes

### 2.1 `watchUsers` — filter on the server, order on the server

Add a composite index (see §3) and change the query to:

```dart
Stream<List<AdminAccountRow>> watchUsers({int limit = 50}) =>
    _firestore.collection('users')
        .where('role', isEqualTo: 'user')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs
            .map((d) => AdminAccountRow.fromMaps(d.id, d.data()))
            .toList(growable: false));
```

- The `limit` now applies **after** the role filter, so it returns the newest 50 users.
- Delete the client-side `.where(...)` — it is now redundant and misleading.

**Caveat you must handle:** Firestore's `orderBy` silently **excludes documents that lack
the ordered field**. `users/ct84PISHIHbjHkg71BC3NSZsBg13` (the live admin) has no
`createdAt`. It is excluded from any `orderBy('createdAt')` query — harmless today
because that tab filters to `role == 'user'`, but it is a trap.

So: **every document the admin lists must have `createdAt`.** Backfill is in §2.4.

### 2.2 `watchWorkers` — stop one failure from blanking the list

Three changes:

1. **Guard each enrichment.** Wrap the per-doc `jobs` count in `try/catch`; on failure
   use `completedInYear: null` and render the badge from the worker's own
   `completedJobs` (already on the document) instead of failing the whole stream.
2. **Cap the work.** Enrich only the first 20 rows of the page; the rest show name,
   email, rating and status without the in-year count. Add a `See exact rank` action in
   the detail screen if you want the precise figure on demand.
3. **Keep the list alive.** A failed enrichment must never produce `AdminError` for the
   whole tab — only a missing number on one row.

Also add `.limit(limit)` *before* enrichment (already there) so the cap is meaningful.

If you prefer to keep exact counts for every row, do them as a single batched read:
collect the worker ids, run one `jobs` query per status window and tally client-side.
Do **not** keep 49 sequential `count()` calls per snapshot.

### 2.3 Reports — seed realistic moderation data

Add `backend/seed/seed-reports.js`, following the conventions of `seed.js`:

- **Dry run by default.** `--write` required to persist; `--dry-run` prints the plan.
- **Deterministic.** Seeded PRNG, fixed ids (`report-demo-01` …), so reruns are idempotent
  and skip existing documents.
- **Realistic content.** 12 reports spanning the last 30 days, drawn from:
  - reasons: `Didn't show up`, `Rude or unprofessional`, `Wrong or unsafe work`,
    `Fake profile`, `Asked for payment outside the app`
  - statuses: 7 `open`, 3 `resolved`, 2 `dismissed`
  - `resolved`/`dismissed` entries carry `resolutionNote`, `resolvedAt`, `resolvedBy`
  - `reporterId` = a real client uid from `users`; `reportedId` = a real worker or client
    uid; `jobId` set for roughly half, referencing real completed jobs
  - at least 2 reports link to a `disputes` document via `disputeId`, so the report
    detail screen's dispute branch is exercised
- **Read the ids from the database**, do not hardcode uids. If the project is empty, fail
  with a clear message rather than writing orphans.
- **Update `backend/seed/README.md`** with the new command and what it writes.

Because report creation is rules-restricted (`reporterId` must equal the caller), this
**must** run with a service account:

```bash
cd backend/seed
npm install
GOOGLE_APPLICATION_CREDENTIALS=path/to/service-account.json node seed-reports.js --dry-run
GOOGLE_APPLICATION_CREDENTIALS=path/to/service-account.json node seed-reports.js --write
```

Document that prerequisite. If no service account is available, a degraded fallback is to
create reports attributed to the admin's own uid through the REST API — acceptable for a
demo but visibly artificial, so prefer the script.

### 2.4 Backfill `createdAt` on provisioned accounts

The admin provisioning path (`users/{uid}` created by hand in the Console) omits
`createdAt`, which makes the document invisible to any ordered query.

- Update the README provisioning section to include `createdAt` (server timestamp) and
  `updatedAt`.
- Add a tiny maintenance step to `seed-reports.js` or a separate
  `backend/seed/backfill-user-fields.js`: for every `users` doc missing `createdAt`, set
  it to a fixed past timestamp (e.g. the doc's creation order is unknown, so use a
  deterministic spread before the seed date). Dry-run by default, `--write` to apply.
- Do **not** change `role` or any other field.

---

## 3. Indexes

Add to `docs/firestore/firestore.indexes.json`:

```json
{
  "collectionGroup": "users",
  "queryScope": "COLLECTION",
  "fields": [
    { "fieldPath": "role", "order": "ASCENDING" },
    { "fieldPath": "createdAt", "order": "DESCENDING" }
  ]
}
```

The jobs index needed by the workers tab **already exists** in the file
(`workerId + status + completedAt`) but is not deployed. Do not duplicate it.

Deployment is an operator step (§6) — do not run it yourself.

---

## 4. Tests

`mobile/test/admin_service_test.dart` and the screen tests:

- `watchUsers` issues a query **with** `where role == 'user'` and applies `limit` after
  the filter — assert the call shape with a fake, or at minimum assert that 60 users
  (55 workers, 5 users) yields 5 rows, not 1.
- `watchWorkers` still returns rows when the per-worker `jobs` count throws — inject a
  service whose count future fails and assert the list renders with no rank badge rather
  than an error state.
- `admin_accounts_test.dart`: a page containing only workers shows the empty state for
  the Users segment, and a mixed page shows only users.
- If you add the backfill script, add a `node --test` case asserting the dry-run plan is
  deterministic and that `--write` is refused without the flag.

Do not weaken existing assertions to make this pass.

---

## 5. Definition of done

- [ ] Users tab shows the real client accounts (26 today), newest first.
- [ ] Workers tab shows all 49, with rank badges where the count resolves.
- [ ] A single failed enrichment cannot blank either list.
- [ ] `flutter analyze` clean; all existing tests still pass.
- [ ] Reports tab shows 12 seeded reports after the operator runs the script.
- [ ] `docs/firestore/firestore.indexes.json` has the new `users` index.
- [ ] `backend/seed/README.md` documents the new script and the service-account
      prerequisite.
- [ ] README provisioning section includes `createdAt`.

---

## 6. Operator steps (not for the agent)

1. Deploy the new index:
   `firebase deploy --only firestore:indexes --project quickfix-fyp`
   Wait for it to finish building in the console (a few minutes).
2. Generate a service account key (Console → Project settings → Service accounts) and run
   the seed script with `--write`.
3. Rebuild and reinstall the app.

---

## 7. Out of scope

- Pagination or infinite scroll for the account lists (50 is fine at this scale).
- Changing the Overview counts — they are correct.
- Any change to client/worker shells, quotes, payments or rules.
- Deploying anything yourself.

---

## 8. Report back

1. Files changed with paths.
2. The before/after query shape for both streams.
3. Checks actually run, with numbers — and which you could not run.
4. The seeded report ids and their statuses, so the operator can verify in the console.
5. Anything you could not verify without deploying the index.
