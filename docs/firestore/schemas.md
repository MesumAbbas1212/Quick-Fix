# QuickFix Firestore Schemas

Firebase project: `quickfix-fyp` (Spark plan). Rules: `docs/firestore/firestore.rules`.
Field names below match the Dart models in `mobile/lib/models/` and the collection names in the rules. Timestamps are Firestore `timestamp`; money is PKR (number).

## users

Document id = auth `uid`. Written by `AuthService` (signup) / `ProfileService`.

| Field | Type | Notes |
|---|---|---|
| email | string | |
| fullName | string | |
| phone | string | |
| role | `'user' \| 'worker' \| 'admin'` | drives RBAC (`isAdmin()` in rules) and AppShell routing |
| avatarUrl | string? | |
| rating | number | 0–5, worker rating |
| completedJobs | number | worker job count |
| preferredLanguage | string | BCP-47 code chosen at sign-up (e.g. `'en'`, `'ur'`); review content is translated into it; the interface remains English. Options come from the `languages` collection below |
| createdAt / updatedAt | timestamp | |

## workers

Document id = auth `uid`. Written by `ProfileService` (`WorkerProfile` model). Mirrors the profile fields the rules gate for self-managed updates.

| Field | Type | Notes |
|---|---|---|
| fullName / email / phone | string | |
| about | string? | |
| professions | string[] | worker skill tags (JobCategory enum names) |
| languages | string[] | |
| location | geopoint? | last known position (consent-based) |
| minBudget / maxBudget | number | quote range (PKR) |
| rating | number | 0–5 |
| completedJobs | number | |
| reviews | number | review count |
| isAvailable | bool | worker availability |
| serviceRadiusKm | number | delivery radius (km), default 5 |
| avatarUrl | string? | |
| createdAt / updatedAt | timestamp | |

## jobs

Written by `JobService` (`JobModel`).

| Field | Type | Notes |
|---|---|---|
| userId | string | client uid |
| workerId | string? | assigned worker (null while open) |
| title / description | string | |
| category | string | JobCategory enum name (manual selection) |
| address | string | |
| location | geopoint | real GPS from `LocationService` |
| budgetMin / budgetMax | number | PKR |
| preferredDate / preferredTime | timestamp? | |
| images | string[] | local app-storage paths |
| status | `'open' \| 'assigned' \| 'inProgress' \| 'completed' \| 'cancelled'` | |
| rating / review | number? / string? | set on completion |
| createdAt / updatedAt | timestamp | |
| assignedAt / completedAt | timestamp? | |

## jobRequests

Written by `JobRequestService` (`JobRequest`).

| Field | Type | Notes |
|---|---|---|
| jobId | string | |
| workerId | string | worker who applied |
| userId | string | job owner |
| status | `'pending' \| 'accepted' \| 'declined'` | |
| message | string? | worker note |
| createdAt | timestamp | |
| respondedAt | timestamp? | when accepted/declined |

`JobRequestService.acceptApplicant` uses one transaction to call
`JobService.assignJob`, mark the chosen request accepted and decline the other
pending requests in the decision snapshot. The job and request owner/status are
re-checked before writing; an already-assigned job cannot be reassigned through
this flow. Retrying the same acknowledged assignment is a no-op. No new fields
are introduced. The request reference list is queried before the transaction
(Firestore mobile transactions cannot query collections), so a concurrently
arriving late application may remain pending, but it cannot be accepted once the
job is assigned. Server-side reconciliation of such late arrivals remains a
production-hardening task.

## conversations

Document id = sorted pair `user1_user2`. Written by `ChatService`.

| Field | Type | Notes |
|---|---|---|
| participants | string[] | both uids |
| lastMessage | string | |
| lastMessageAt | timestamp | |
| lastSenderId | string | |
| unreadCount | number | |

### conversations/{id}/messages

| Field | Type | Notes |
|---|---|---|
| senderId / receiverId | string | |
| text | string | |
| attachmentType | `'image' \| 'location' \| 'file'`? | |
| attachmentUrl | string? | for location: `"lat, lng"` |
| isRead | bool | |
| createdAt | timestamp | |

## reviews

Written by `ReviewService` (`ReviewModel`).

| Field | Type | Notes |
|---|---|---|
| jobId | string | |
| reviewerId | string | client uid |
| workerId | string | reviewed worker |
| rating | number | 1–5 stars |
| originalText | string | review text in the reviewer's language |
| originalLang | string | BCP-47 code inferred from the reviewer's app language + text script (e.g. `'ur'`, `'en'`, `'fr'`) |
| translatedText | string? | legacy English translation (TranslationService) |
| translations | map<string, string> | per-language cached translations keyed by target language code (e.g. `{'en': 'Very good work', 'ur': '…'}`) |
| createdAt | timestamp | |

Reviews are translated on demand into the *viewer's* app language
(`users/{uid}.preferredLanguage`); results are shown inline under the
Translate button.

## categories

Read by the app for the manual category dropdown (admin-managed).

| Field | Type | Notes |
|---|---|---|
| name | string | JobCategory enum name |
| icon | string | |
| isActive | bool | |

## languages

Admin-managed list of languages the app can be shown in. Read by the
sign-up language picker and the profile "App Language" menu (via
`LanguageService`); readable before authentication since the sign-up
screen queries it. **This collection is the source of truth for the
multilingual feature — it is not hard-coded in the app.** The app merges
it with the translation proxy's `GET /languages` (languages the backend
translation engine supports), so adding/removing a language here — or on
the proxy — is all that is needed; no app release required.

| Field | Type | Notes |
|---|---|---|
| code | string | BCP-47 code, also the document id (e.g. `'ur'`) |
| nativeName | string | native display name (e.g. `'اردو'`) |
| englishName | string | English name, used for sorting and fallback labels |
| isActive | bool | soft-deactivate flag (default true when missing) — `LanguageService` skips inactive docs; never delete a language because existing `preferredLanguage` values reference the code |
| createdAt | timestamp | |

## Worker ranks

Computed client-side from `jobs` (no stored field): a worker's rank is
the highest tier in `WorkerRank.tiers` whose threshold is met or
surpassed by the number of that worker's jobs completed in the trailing
12 months (`workerId = uid`, `status = 'completed'`, `completedAt` in the
last 365 days).

Policy: **one rank step = 156 completed jobs per year** (~3 jobs a week
across a full work year), so thresholds are cumulative multiples of 156.

| Rank | Min jobs / 12 months |
|---|---|
| Apprentice | 0 |
| Journeyman | 156 |
| Expert | 312 |
| Master | 468 |
| Grandmaster | 624 |

Each rank has a dedicated badge — a proper vector emblem (shield,
hexagon, star, diamond, crown) plus color — shown on the worker's
public profile (`WorkerDetailScreen`) and the worker's own profile.

## reports

| Field | Type | Notes |
|---|---|---|
| reporterId | string | |
| reportedId | string | |
| jobId | string? | optional context |
| reason | string | |
| details | string? | optional free text, max 500 chars |
| status | string | `'open' \| 'resolved' \| 'dismissed'` |
| resolutionNote | string? | admin note, required when resolving/dismissing |
| resolvedAt | timestamp? | |
| resolvedBy | string? | admin uid |
| createdAt | timestamp | |

## payments

Written by `PaymentService` (`Payment` model). Doc id = payment reference.

| Field | Type | Notes |
|---|---|---|
| jobId | string | |
| payerId | string | client uid |
| workerId | string | worker uid |
| amount | number | PKR |
| status | `'pending' \| 'paid'` | |
| method | string | `'mock'` (simulated) for now |
| createdAt | timestamp | |

### Earnings calculation (C1)

The earnings screen reads the existing worker payments and completed-job streams;
no additional fields or collections are stored. Totals use **paid receipt dates**
(cash basis), not job budgets. Multiple paid receipts for one job are summed but
count as one paid job. Unpaid completed jobs show an estimated budget separately,
never as received income. Calendar periods use the device's local timezone and
weeks start Monday; the chart always covers the last eight calendar weeks.

### Tracking read/transition policy (B6)

Tracking reuses the existing job, worker/user profile and conversation-message
streams. A location is a validated `location` attachment from the **other**
participant, addressed to this participant, at/after `assignedAt` (or `createdAt`
for legacy jobs). It is not job-scoped GPS and the UI does not claim it proves
travel. `On the way` is display-only; the job-status enum is unchanged. Unknown
start times are labelled, not reconstructed. Starting no longer overwrites the
acceptance timestamp.

Worker start/completion and the assigned-only client cancellation shortcut use
transactions that recheck document ownership/status before writing existing
fields. Cancellation records `status: cancelled` and `updatedAt`; full reason,
rescheduling and notifications belong to B10. There are no new stored fields,
collections or query shapes, so no index/schema migration is needed. These
client-side guards do not replace the broader §8 Firestore-rules hardening,
which remains pending.

### Browse criteria and annual-rank lookup (B3)

`WorkerFilter` is immutable and route-local; no filter fields are persisted.
Browse fetches one **unfiltered** workers pool (at most 500), then applies name,
service, inclusive overlapping PKR price ranges, geodesic distance, rating,
availability, annual-rank and spoken-language criteria locally. Widening filters
therefore does not stay trapped in the previous profession's server query.
Unknown locations are included without a distance constraint and excluded with
one. Losing the client's location clears the distance constraint explicitly.

`CategoryService` reads the existing admin `name` identifiers and legacy seed
`category`/display-name/id forms without rewriting documents. An absent catalog
falls back to the enum; a present inactive catalog is not silently re-enabled.
`LanguageService.getSpokenLanguages` exposes real catalog/proxy failure (no
fixed-language fallback). Filter choices also include observed profile data.
Selected immutable `AppLanguage` values retain code/English/native aliases for
legacy worker `languages` values; this is matching, not a translation dictionary.
The existing sign-up offline fallback/API is retained.

Annual ranks are loaded **only on demand**, using the existing `getWorkerJobs`
query and the unchanged 365-day/156-per-tier engine (`completedAt`, legacy
`updatedAt` fallback). Reads have at most eight concurrent requests, a five-second
per-read deadline and a twenty-second total deadline. Failed/unknown ranks are
never inferred from lifetime counters or counted as Apprentice. A successful
in-memory snapshot is reused for up to five minutes, with manual refresh; leaving
or resetting filters cancels further queued reads. This avoids new stored
aggregates/indexes, at the cost of reading worker histories when a rank filter is
first selected. Slow/large histories surface a retry/clear-filter state rather
than silently reporting inaccurate ranks. No Firestore shape/index change or
dependency was introduced.


## config/app — release gate (D5)

Optional public-readable document, writable by an existing admin only. Fields:
`minBuild` and `latestBuild` nonnegative integral numbers (`latestBuild >= minBuild`),
`message` optional string, `storeUrl` HTTPS Google Play details URL with `id` or
Apple App Store `/id<number>` URL. Invalid/missing documents and read failures skip
checking; config is never an availability dependency. Only **installed build <
minBuild** hard-blocks, including after a downgrade. `latestBuild` alone never blocks.
`last_seen_build` is device-local SharedPreferences state, not authority over the
installed build. For each release keep `pubspec.yaml`/`--build-number` and
`--dart-define=APP_BUILD_NUMBER=<same number>` in sync (default 1 for current 1.0.0+1).
The gate covers Splash's login/fallback destinations and AppShell itself, preventing
direct sign-in/sign-up shell entry from bypassing a successful check. Reads are
bounded; opening the store is awaited and reports launch errors. No new composite
index: this is a single-document read. Rules now also reject client admin creation
and owner role escalation; existing seeded admin accounts are unaffected.


### D6 language selection

`LanguagePickerScreen` reads `LanguageService.getAvailableLanguages()`; Firestore's
active catalog and optional ML proxy catalog supply choices, with an explicitly
labelled limited fallback only when unavailable/empty. Retry clears that cached
fallback. Search matches native/English names and codes. Profile/Settings writes the
existing `preferredLanguage` field, while sign-up receives the selected model. Preview
requests use the **chosen** target through the ML proxy; original-text fallbacks
are labelled unavailable, never presented as machine translation. RTL is detected
from actual preview content, so Hindi remains LTR. No new collection/index is needed.

## Worker identity verification (D7)

**Security-motivated deviation from the proposed inline CNIC fields:** `workers`
is readable to signed-in users, so proof paths and rejection notes are **not**
written there. Optional `workers/{uid}.verification` contains only `status`
(`notStarted|pending|verified|rejected`), `submittedAt?`, `reviewedAt?`. Old workers
without this map remain Not started. Full profile saves merge rather than erase
admin-owned status. Owners cannot set approval/block flags or self-verify.

New private **`workerVerifications/{uid}`** (owner/admin read only):
`status`, `cnicFrontPath`, `cnicBackPath`, `selfiePath`, `submittedAt`, `consent: true`,
`consentVersion: '2026-10-local-demo-v1'`; manual review adds `reviewedAt`,
`reviewedBy`, `reviewMethod: 'manual-external'`, `note` (private). Submit and public
status update are atomic; pending/verified cannot be overwritten by owners;
rejected requests may resubmit. Rules require matching transaction/batch timestamps
and public/private pending states. No composite index (document reads only).

Photos are **device-local, app-private**, namespaced by safely encoded UID and
read only after resolving paths/symlinks inside that account's directory. No
Storage upload, OCR or automated identity/background check. Remote web admins
cannot fetch these photos. WorkersPage shows a separate Verified column and a
manual review/revoke dialog; approval requires explicit confirmation of a separate
approved secure/in-person identity check, a complete consented request, and an
atomic private/public update. Rejection requires a note. This is a clearly labelled
**demo workflow, not production remote KYC**. A real encrypted upload/review/
retention policy is needed before production identity collection. Local captures
persist until app-data/account cleanup; uninstall does not remove server references.
Do not migrate any legacy public proof paths into the public summary; any deployed
legacy inline proof data would require a privileged privacy migration.

### D8 data-practice UI

Terms/Privacy are static, numbered, scrollable clauses in `LegalScreen` (18 October
2026); Settings, Profile and verification consent link to them. Text identifies
actual collections, one-shot stored pins, device-local images, selected-language
Google Cloud Translation/proxy processing, simulated payments, deletion/resume
behavior and explicit retention/other-device limits. No fake support email,
background tracking, remote-KYC image access, automatic retention expiry or legal
compliance is claimed. The former dead Help shortcut is now honestly labelled
Terms & App Guide; B14 HelpCentreScreen remains for the breadth batch. Settings is
a working companion entry for D6/D8/D9, not yet the full B15 preferences screen.

### D9 account deletion, recovery and existing-collection access

**Prototype workflow, not a complete legal erasure service.** No dependency,
Storage upload, continuous tracking, trusted Cloud Function or scheduled purge is
added. Views invoke services, never Firestore directly.

- New private `accountDeletions/{uid}`: `state: checking|cleaning|authPending`,
  `startedAt: Timestamp`, `updatedAt?: Timestamp`. No name, password, email,
  photos, file paths or job list is stored here. Owner/admin read; owner writes
  require Firebase `auth_time` within five minutes. The owner can remove only a
  `checking` marker (no destructive cleanup yet); post-cleanup tombstones must
  be reviewed/removed by an administrator only after verifying Auth deletion and
  that stale sessions/tokens can no longer recreate data. No expiry/automatic purge is claimed.
- `AccountAccessService` reauthenticates the **current** email/password account
  and refreshes its ID token before any marker or destructive write.
  `AccountDeletionService` prevents parallel attempts per UID. Every server call
  is bounded. `AccountDeletionRepository` waits for pending writes, uses server
  snapshots and rejects cached/pending preflight data. It creates the pause
  marker **before** checking assigned/in-progress jobs in both participant roles;
  normal job assignment, applications, chat/review/payment creation cannot race
  a paused participant. An active job cancels a checking-only marker and blocks
  cleanup; a previously destructive run stays paused for operator review.
- Cleanup drains first pages of 100 records rather than offsetting over mutated
  results; each pass is capped at 1,500 observed documents / roughly two minutes
  plus any bounded in-flight call. Further passes reauthenticate and resume the
  same account-scoped work. Timed-out SDK writes may acknowledge later: no
  rollback or successful completion is claimed on uncertainty.
- Delete applications by client/worker; reviews written by the UID **or about its
  worker profile**; all participating conversations and their messages (children
  before parents); posted/assigned non-active jobs not retained for a counterparty.
  Completed job/receipt transformations re-read transactionally, so stale data
  cannot overwrite a concurrent edit. This does not use MatchingService.
- Optional `jobs.anonymized: true`: completed counterparty records replace the
  deleted participant field with the reserved shared ID `deleted-account`.
  Replacement maps retain category, budgets, schedule/timestamps and payment
  status only; title becomes `Completed job`. Description, address, coordinates,
  photos, review text and **unknown** legacy fields are removed. If no other
  counterparty remains, the job is removed. The model defaults this flag to false;
  history UI does not launch fallback coordinates, contact/chat, pay/review or
  reporting against the shared sentinel. Existing document/reference IDs stay;
  de-identification is not a guarantee of irreversible anonymity, particularly
  for identifying imported IDs or copies already held by a counterparty.
- Optional `payments.anonymized: true`: retain job reference, amount, status,
  method and date, replace the actor ID and remove all unknown fields. Receipts
  remain for counterparty history. Anonymous aggregate rating/count statistics
  may remain even when individual review documents are erased. Moderation
  reports remain as submitted, including references/free text, for admin review.
- Remove private verification, worker and user documents in an acknowledged
  batch (with marker `authPending`) **before** deleting Auth. Auth failure after
  profile deletion is recoverable: `AuthService.getUserProfile()` derives a
  non-persisted `UserModel.deletionPending` for the current UID; a missing profile
  plus private marker produces a minimal recovery model. AppShell routes that
  model to DeleteAccountScreen rather than recreating a profile. Sign-out/sign-in
  is available on recovery/failure. A legacy `deleteAccount()` call without a
  password now explicitly rejects the unsafe shortcut.
- Current-device cleanup deletes this UID's proof directory plus legacy shared
  job/avatar app-document cache folders and cached job/category preferences.
  Other UID proof directories, gallery/camera originals, platform/plugin caches,
  Firebase SDK persistence, other devices, quoted copies and provider logs/backups
  are **not** forcibly wiped. Onboarding/build flags contain no identity and stay.
  Public image readers now allow only managed avatar/job folders and reject proof
  paths, traversal and symlinks into proof folders; onboarding no longer bypasses
  this boundary with direct Image.file on a Firestore-provided avatar reference.
- Optional `workers.ratingReviewId` links an aggregate addition to a newly
  created review in the same commit. Rules validate participant/completed-work
  provenance, count and weighted average; owners cannot forge ratings/counts or
  approval/block/verification flags. Profile saves merge only editable fields.
  Because current review submission pre-reads aggregates, conflicting concurrent
  reviews can require retry; this is not a trusted aggregation backend. New form
  reviews use `originalLang: und` rather than guessing a source language from
  script or the user's preference. Optional ML translation uses the chosen target
  and runs bounded **after** the acknowledged save, without blocking submit.
  Unchanged/unavailable translations remain originals, not labelled translations.
- Tightened jobs updates to the owner/assigned worker/admin with status/field
  boundaries; worker browsing now sends an application rather than self-assigning
  open work. Normal owner deletion of open/cancelled jobs remains permitted.
  Conversations/messages are participant-private (admin reads permitted); first
  parent/message creation is atomic with getAfter checks. Empty parent bootstrap
  happens transactionally before private message listening, never by making
  absent-parent message reads public. Receipts are participant/job-party/admin
  readable; reports are reporter/admin readable. No new role escalation is added.

Two indexes are appended without changing the prior 15: `jobs(userId ASC,
status ASC)` and `jobs(workerId ASC, status ASC)` for active-work preflight.
Root `firebase.json` already points to this rules/index manifest. Future breadth
collections (notifications/quotes/disputes/payouts) require their own rules AND
an explicit deletion/retention-policy extension when introduced.

**Deployment verification still required:** Flutter analyzer/tests, Firebase Rules
compiler/emulator and real multi-device/offline/revoked-auth tests have not run in
this sandbox. Do not deploy these new rules on the strength of source inspection.
Check at least: stranger chat/receipt/report reads denied; first empty/first reply
bootstrap allowed for both participants; applicant-only self-assignment denied;
owner selection and assigned-worker progress allowed; pause-before-assignment
races denied; fresh-login cleanup allowed after user/profile removal; stale-token
recreation and tombstone rollback denied; completed-history/amount tampering
and owner verification/role/stat forgery denied; failed/large cleanup resumes.
The third-party parser available here predates Rules v2 and could not validate
this file. No emulator pass, deletion-hook enforcement outside this app flow,
backend cleanup worker, automatic report/tombstone expiry or production KYC is
claimed. Legacy deletion/orphaned data needs operator review.

### Step8 B5 — saved workers

Optional `users.savedWorkers: string[]` (default empty), at most 200 on owner
writes. Store IDs only; ProfileService applies an idempotent desired-state
transaction and resolves profiles with bounded concurrency/deadlines. A missing
worker remains an unavailable/removable reference, not a fake profile. Removal
waits for the write and Undo restores the ID. Saved-worker ranks reuse actual
trailing-year work history, never lifetime counters; distance is unknown until an
explicit, consent-gated one-shot position or supplied origin. No new index.
Own account deletion already removes this array; references on other accounts
resolve unavailable after the worker is removed. Under the current public-basic
user-profile rules, bookmark IDs are signed-in readable; UI/privacy text does not
promise a private contact vault. Flutter/analyzer/rules verification remains unrun.

### Step8 B8 — editable one-shot pins (dependency of B7)

LocationSelection validates finite Earth-coordinate ranges and rounds to five
places. LocationPickerScreen starts without GPS I/O; its explicit GPS action uses
the existing permission explainer, with a manual latitude/longitude fallback.
Addresses/landmarks are typed, not fake-geocoded. Maps opens externally only.
PostJobScreen accepts the returned pin (or an optional initial selection) without
requesting a second GPS fix that could overwrite the correction. With no selection
it keeps its consent-first one-shot path. No Firestore shape/index change. B8 is
implemented immediately before B7 within Step8 because address-book navigation
needs it. Flutter/visual validation remains unrun.

### Step8 B7 — private address book (intentional privacy override)

Instead of putting precise home/office pins on signed-in-readable `users/{uid}`,
store `{addresses: [{id, label, address, location: GeoPoint}], updatedAt}` at
`users/{uid}/private/addressBook`. Only owner/admin read. Owner creates/updates
require an existing, non-paused account; deletion cleanup is separately permitted.
Up to 50 addresses; IDs are stable and legacy missing IDs receive migration IDs.
ProfileService migrates a valid legacy public addresses array atomically into this
private document and removes the public field. Malformed legacy data is not
silently discarded. Rules prohibit new public address-book arrays. Admins must
review any legacy public address data not yet migrated; rules cannot hide fields
already present on a publicly readable document. No new index.

AddressBookScreen is reachable from client Profile and Post Job. Add/edit uses the
consent/manual LocationPicker; selecting returns SavedAddress to its caller, and
Profile's manage mode can prefill a new job. Delete confirms and awaits its write.
The account cleanup batch now removes this private child before its public parent;
its existing assertion is preserved and expanded from three to four deletes.
Legal/deletion UI reflects the actual storage. This departs from B7's proposed
public-field location to honor C9's privacy constraint. Flutter/analyzer/emulator
validation remains unrun.

### Step8 B13 — in-app notifications (foundation for job/dispute/quote actions)

New `notifications/{id}`: `userId`, `type`, `refId`, generic `title`/`body`,
`isRead`, server `createdAt`. Owner-only read and read-state update; sender
creation must match a job, application, conversation, review or payment involving
that authenticated sender and recipient (or an admin). Paused accounts cannot
create/receive new events. Account cleanup drains the owner's inbox; generic
reference IDs in other recipients' inboxes may remain, not quoted message/address
or banking data. No FCM, OS notification permission, email or delivery SLA.

Optional `users.notificationPrefs: {jobUpdates, messages, promotions}` defaults
true/true/false. These filter the in-app list/badge, not storage; no push or actual
marketing channel is claimed. The latest 200 records are shown/grouped Today/
Earlier, with unread indicators and guarded routes to real job/chat/review/receipt
pages; removed destinations fail clearly. Mark-all drains server-confirmed unread
pages with a bounded repeat path for large accounts. Header bells are mounted in
both shells' home pages without adding a second/nested app bar.

Existing chat, review, simulated payment, application, selection and worker-status
operations emit bounded best-effort updates **after** acknowledging their primary
write, never holding submit hostage. Client shutdown/network/auth failure can
lose or delay these events; without trusted server triggers they are not a
reliable audit log. The transaction/batch helper permits atomic notifications in
new workflows. Notifications are intentionally built before the dependent B9/B10/
B11 workflows within Step8. Added two indexes: user/date and user/read-state.
Flutter/analyzer/rules-emulator results remain unavailable.

### Step8 B10 — schedule/cancellation flow

Optional `jobs.cancelReason: string`, `cancelledAt: Timestamp`; DTO/copy/cache
serialization stay backward-compatible. Owning clients can reschedule or cancel
assigned/in-progress work, never completed/anonymized records. UI and service
validate future schedules, require a cancellation reason and confirm before the
bounded transaction; it writes a generic notification for the assigned worker
atomically. Profile/job tracking and job-detail overflow link to the screen.
The existing assigned-only cancel API/shortcut stays compatible and now records
a default reason/date plus best-effort notice. No new index.

Spec conflict: `status: cancelled` cannot also return a job to the open board.
Followed the explicit cancelled state, preserved history/worker reference, and
used truthful impact copy: post a new job to hire again. No automatic reopening,
background tracking or unimplemented worker agreement is promised. Runtime and
rules-emulator verification remain unrun.

### Step8 B12 — written-review page

MyReviewsScreen reuses watchReviewsByUser, a pure count/valid-average helper, cached
worker-name/avatar lookups and read-only ReviewListTile (no Translate action for
one's own text). It distinguishes pending, empty, error/retry and content, and
handles a removed worker without fabricating a profile. Client Profile's former
inline expansion is now a compact navigation card; existing public constructor
parameters are unchanged. No fields, rules or indexes added. Flutter tests remain
unrun; added source tests cover missing averages and all list states.

### Step8 B14 — help centre and operator contact

Static searchable FAQ/accordion copy covers actual posting, owner-selected work,
simulated finance, cancellation, selected-language reviews, annual ranks, local
images and resumable deletion. No-match reset works. Profile and Settings link to
the page. `SupportService` uses existing url_launcher/Clipboard abstractions; a
valid `--dart-define=SUPPORT_EMAIL=...` is required for email launch. Missing config
is labelled non-interactive info rather than inventing a project email or sending
to the developer's personal address. No mail handler has a copy/select fallback;
launch/copy await bounded results. No support SLA is claimed. No schema/index
change; added source tests remain unrun without Flutter.

### Step8 B15 — full Settings controls

Settings now groups Account, Preferences, Privacy, About and Danger zone. It
retains the passed/last loaded profile on refresh errors with a working Retry;
uses the existing dynamic language picker; saves each notification preference as
a nested single-field update (no stale-map overwrite), with per-toggle busy/error
handling; and requests password reset for the actual authenticated email, not a
mutable Firestore profile address. Location opens the existing one-shot permission
explainer. Help/Terms/Privacy and the D9 typed/reauthenticated deletion flow remain
reachable. No new dependency. Preferences are validated as optional booleans in
rules. `APP_VERSION` (default current pubspec 1.0.0) and APP_BUILD_NUMBER must be
kept aligned by release tooling; no package-info SDK was added. No new index.
Existing language-picker assertions remain; added tests cover awaited preference
writes and current-account reset. Flutter/analyzer/visual checks remain unrun.

### Step8 C3 — availability and service area

Optional public worker `workingHours` maps mon…sun to enabled/fromMinutes/toMinutes;
`daysOff` is a date-string list. Existing `isAvailable` and radius semantics stay
unchanged. Hours/day-off records are informational local-clock values, not an
automatic availability scheduler or background tracking. The UI makes that limit
explicit, offers a consent/manual service-area pin, avoids invented city coverage,
validates non-overnight windows and preserves unsaved drafts on back. Profile and
worker dashboard link to it; parent worker snapshots now update Profile even when
the UID stays the same. Dedicated writes avoid stale identity saves overwriting
hours/days off. Rules retain owner-only bounded scheduling-field writes; no new
index. Public nature of the service-area pin/hours is disclosed. Tests written,
Flutter/analyzer/rules checks unrun.

### Step8 C4 — worker job preferences, consumed on the board

Optional `workers.jobPrefs`: categories (enum names, nonempty when saved),
maxDistanceKm (null/show all or 1–100), nonnegative minBudget, onlyVerifiedClients.
Dedicated ProfileService writes preserve other worker fields; generic identity
saves no longer overwrite this map. The editor explains that these are in-app
board filters, not push alerts. Distance needs a saved service pin; budget matches
the posted maximum, not an invented agreed price. Dashboard consumes its live
WorkerProfile prefs and filters the existing loaded query result; it does not
claim a complete database scan or invoke MatchingService. Missing origins never
mean zero distance. Default/no prefs preserves the original board behavior.

Optional `users.verifiedClient` is admin-owned, defaults false and is excluded from
client DTO serialization. The checkbox explicitly calls this an admin flag, not
an automated client identity check; no flagged clients yields an honest empty
state. No new client-KYC process is invented. Flag lookups are bounded/concurrent,
with error/retry instead of silently admitting unknown users. Rules prohibit owner
flag escalation and validate saved preference shapes. No new index. Profile/
Settings/dashboard entries are wired; source tests written, SDK/emulator unrun.
