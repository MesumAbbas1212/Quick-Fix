# Admin: delete any job, from any status

> **Read §1 first.** The delete button already exists. Do not rebuild it — the job is to
> finish it. §2 lists the three specific gaps.

---

## 0. Where you are

| | |
|---|---|
| Repo | `https://github.com/MesumAbbas1212/Quick-Fix` |
| Branch | `arena/d2910532-quick-fix` (head `af2eb0f`) — **not** `main`, which is stale |
| Local clone | `C:\Users\MOON COMPUTERS\WorkBuddy AI\2026-10-18-16-18-16\quick-fix` |
| Verify | `git log --oneline -1` must print `af2eb0f` or newer; `mobile/lib/views/admin/admin_jobs_screen.dart` must exist |

Toolchain: Flutter 3.44.9 at `D:\flutter` — prefix every call in Git Bash with
`env "ProgramFiles(x86)=C:\Program Files (x86)"`. Run `flutter pub get` after any checkout.
Baseline: `flutter analyze --no-pub` clean, `flutter test` = **943 passed / 3 failed**, where the
three are `local_image_store_test` symlink tests that need Windows Developer Mode.

---

## 1. What already exists — verified

| Piece | Where | State |
|---|---|---|
| Delete button | `admin_jobs_screen.dart` ~line 437, key `admin-delete-job` | **Only rendered when `job.status != 'completed' && job.status != 'cancelled'`** |
| Confirm dialog | `_deleteJob` ~line 287, key `admin-delete-job-confirm` | Exists, says "Delete permanently" |
| Service | `AdminService.deleteJob` → `JobService.deleteJob` | `_jobsCollection.doc(jobId).delete()` — **bare delete, no cascade** |
| Rule | `firestore.rules` jobs block | `allow delete: if isAdmin() ...` — already permits it |
| Web dashboard | `admin/src/pages/JobsPage.tsx` ~line 58 | Has a delete button, **no status guard, no confirmation** |

So an admin *can* delete an open, assigned or in-progress job today. The user's complaint —
"there isn't any way to do it" — is accurate for **completed and cancelled** jobs, which is
most of what is in the database.

---

## 2. The three gaps

1. **Finished jobs cannot be deleted.** The action is hidden for `completed` and `cancelled`,
   which are the majority of the seeded data.
2. **Deleting leaves orphans.** `jobRequests` (applications), `jobs/{id}/private/*`
   (owner/admin-only address and location), and `notifications` with `refId == jobId` all
   survive pointing at a document that no longer exists. Any screen that resolves those
   references then shows a blank or throws.
3. **No audit trail.** For a moderation action that destroys a customer's record, there is no
   evidence of who removed what and why.

---

## 3. Design: hard delete with cascade + an audit record

Delete the job for real (the user asked for deletion, and a hidden-but-present job would confuse
the demo), but make it accountable and consistent:

- **Cascade** the documents that cannot exist without the job.
- **Preserve** financial and reputational records (payments, reviews) — deleting a payment record
  would falsify a worker's earnings history. Leave them, and say so in the dialog.
- **Audit** every deletion into a new `deletedJobs` collection.

Do **not** implement a soft delete instead. If you believe soft delete is the better design, say
so in your report rather than substituting it silently.

---

## 4. Required changes

### 4.1 Show delete for every status

In `admin_jobs_screen.dart`, the action block currently reads:

```dart
if (job.status != 'completed' && job.status != 'cancelled') ...[
  // Cancel job
  // Delete job
],
```

Split it:

- **Cancel** stays conditional — it makes no sense for a completed or cancelled job.
- **Delete** renders for **every** status, including `completed` and `cancelled`.

Keep the existing keys (`admin-cancel-job`, `admin-delete-job`) so the tests keep working.

### 4.2 Confirm dialog must state consequences

`_deleteJob`'s dialog must list what happens, not just ask "are you sure":

- the job and its photos are removed for both the client and the worker;
- its applications and notifications are removed;
- **payment and review records are kept** (they are financial/historical);
- it cannot be undone.

Require a typed reason (a `TextField` in the dialog) and store it in the audit record. Default
suggestions: "Test data", "Duplicate", "Spam", "Requested by user".

### 4.3 Cascade in `JobService.deleteJob`

Replace the bare delete with a batched removal:

```
1. read jobRequests where jobId == jobId          (chunked, 500 writes per batch max)
2. delete those jobRequest docs
3. delete jobs/{jobId}/private/* documents
4. delete notifications where refId == jobId and type in ['job','jobRequest']
5. delete the job document itself
6. write deletedJobs/{jobId} — see 4.4
```

Use `WriteBatch` with chunks of ≤ 500 operations; a job can have many applications. If any chunk
fails, stop and report which step failed — a half-deleted job is worse than an undeleted one.

### 4.4 Audit record

New collection `deletedJobs`, document id = the job id:

```json
{
  "jobId": "...", "title": "...", "category": "plumbing",
  "ownerId": "...", "workerId": "..." | null,
  "status": "completed", "budgetMin": 1500, "budgetMax": 3000,
  "createdAt": "<original>", "deletedAt": "<serverTimestamp>",
  "deletedBy": "<admin uid>", "reason": "Test data",
  "cascaded": { "jobRequests": 3, "privateDocs": 1, "notifications": 2 }
}
```

Write it **in the same batch** as the final job delete, so an audit record can never be missing.

### 4.5 Check what still references the job

Before you finish, grep the codebase for reads of `jobId` on `reviews` and `payments`. If any
screen calls `getJob(review.jobId)` or similar, a deleted job will break that screen. Either:

- make the read tolerant (show "Job no longer available"), or
- report it and leave it — but **say which** in your summary.

---

## 5. Rules

Add to `docs/firestore/firestore.rules`:

```js
match /deletedJobs/{jobId} {
  allow read: if isAdmin();
  allow create: if isAdmin()
    && request.resource.data.deletedBy == request.auth.uid
    && request.resource.data.reason is string
    && request.resource.data.reason.size() > 0;
  allow update, delete: if false;   // immutable audit trail
}
```

Keep the existing `jobs` delete rule as `isAdmin()`. Do not widen anything else.

Add an emulator case in `validation/firestore/rules.test.mjs`: a normal user cannot read or write
`deletedJobs`; an admin can create one but not update or delete it.

---

## 6. Web dashboard parity

`admin/src/pages/JobsPage.tsx` deletes with no confirmation and no reason. Bring it in line:

- confirm dialog with the same consequence list,
- required reason,
- same cascade call (the dashboard talks to Firestore directly, so it needs the same batched
  logic — put it in `admin/src/api/jobs.ts`).

If the dashboard's data layer is too different to share code, implement it separately but keep
the behaviour identical. Do not leave the dashboard with a one-click destructive button.

---

## 7. Tests

In `mobile/test/admin_jobs_screen_test.dart`:

- delete is offered for **open, assigned, inProgress, completed and cancelled**;
- cancel is **not** offered for completed or cancelled;
- confirming without a reason is refused;
- confirming calls `deleteJob` exactly once with the job id;
- dismissing writes nothing.

In `mobile/test/job_service_test.dart`:

- a job with 2 applications, 1 private doc and 3 notifications produces the expected cascade
  writes and one audit record;
- a cascade failure surfaces the error and does not silently report success.

Do not weaken existing assertions.

---

## 8. Acceptance

- [ ] An admin can delete a completed job from the phone, in two taps plus a reason.
- [ ] An admin can delete a cancelled job the same way.
- [ ] After deletion the job is gone from the client's list, the worker's list and the admin list.
- [ ] `jobRequests`, `private/*` and job notifications for that job are gone.
- [ ] A `deletedJobs/{id}` audit record exists with the admin's uid and the reason.
- [ ] Payments and reviews for that job still exist and still render.
- [ ] A non-admin cannot write `deletedJobs` (emulator test proves it).
- [ ] `flutter analyze` clean; `flutter test` ≥ 943 passed / 3 known Windows failures.

---

## 9. Out of scope

- Restoring a deleted job (the audit record is evidence, not a recycle bin).
- Deleting users or workers.
- Any change to the client or worker shells.
- Deploying rules or building the APK — the operator does that.

---

## 10. Report back

1. Files changed, with paths.
2. What the cascade deletes, and what it deliberately leaves.
3. Whether any screen reads a deleted job's id, and what you did about it.
4. Checks run, with numbers — and anything you could not verify without a device.
