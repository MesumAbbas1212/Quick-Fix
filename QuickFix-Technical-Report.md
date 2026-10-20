# QuickFix — Technical Report

> Current executed validation is recorded in §14. Earlier batch sections retain
> their historical source-only/unrun status; they are not the latest test result.
> Automated passes do not substitute for the still-unperformed native/live checks.


**Final Year Project: Multilingual Home-Service Marketplace for Pakistan**

---

## 1. Project Overview

QuickFix is a mobile marketplace that connects clients who need home services
(plumbing, electrical, cleaning, carpentry, painting, moving, tutoring, etc.)
with vetted service workers. A client posts a job with a real GPS location and
a budget range; nearby workers browse open jobs and send job requests; the
client accepts one; the two chat (including sharing live map locations); the
worker completes the job; the client rates and reviews it. Reviews are
written in the reviewer's own language — Urdu, English, Punjabi, Pashto,
Sindhi, and more — and are machine-translated into whichever language the
*viewer* is using, with an ML-generated overall summary on every worker
profile. Workers earn ranks (Apprentice → Grandmaster) from their volume of
completed work.

The project is built from three components:

| Component | Technology | Role |
|---|---|---|
| `mobile/` | Flutter (Dart 3), Material Design | The client-facing app (Android) |
| `backend/translation-proxy/` | Node.js + Express + Google Cloud Translation | Key-protected ML translation & summarization API |
| `docs/demo/` | Node.js, zero dependencies | Self-contained interactive ML demo (runs with no API key) |
| `backend/seed/` | Node.js + firebase-admin | Realistic Pakistan-wide seed dataset |

---

## 2. Technology Stack

### 2.1 Mobile app (`mobile/`)

| Package | Purpose |
|---|---|
| `firebase_core` / `firebase_auth` | App initialization and email/password authentication |
| `cloud_firestore` | NoSQL document database — all app data, live streams |
| `firebase_storage` | Cloud file storage (avatars, job images) |
| `geolocator` | One-shot GPS position + permission management |
| `google_maps_flutter` | In-app map rendering |
| `url_launcher` | Deep-linking shared locations into Google Maps |
| `image_picker` / `path_provider` | Job photos; local image storage paths |
| `http` | Calls to the translation/summarization proxy |
| `provider` | State management |
| `shared_preferences` | Light-weight local persistence (session, caches) |
| `intl` | Date/number formatting |

### 2.2 Architecture

The app is a standard Flutter layered structure:

```
views/        screens (client shell, worker shell, auth, jobs, reviews, chat, profile)
  └─ services/   data layer: JobService, ReviewService, ChatService,
                    ProfileService, AuthService, LocationService,
                    TranslationService, SummaryService, LanguageService…
       └─ models/  plain-Dart domain objects: UserModel, WorkerProfile,
                     JobModel, Review, JobRequest, ChatMessage, WorkerRank…
```

- **Views** are declarative UI. They never talk to Firebase directly; they
  call services.
- **Services** own all Firestore queries/streams and map documents to
  models. Every service is constructor-injectable, which is what lets the
  whole suite of widget tests run against mock services.
- **Models** are immutable data classes with `toMap()` / `fromMap()` that
  match the Firestore schemas exactly (documented in
  `docs/firestore/schemas.md`).

Two role-based shells: after login, `AppShell` reads the user's `role` field
(`user`, `worker`, `admin`) and routes to **ClientShell** (Home / Workers /
Messages / Profile) or **WorkerShell** (job board, requests, profile with
availability toggle). Admins additionally use the React admin dashboard; on
mobile they map to the client shell.

---

## 3. Storage & Database Design

### 3.1 Firebase Firestore (project `quickfix-fyp`, Spark plan)

All data is documents in collections; timestamps are Firestore `timestamp`;
money is PKR as numbers. Security rules (`docs/firestore/firestore.rules`)
implement role-based access: users read/write only their own documents,
workers can update only a whitelisted set of self-managed profile fields,
and the `languages`/`categories` collections are world-readable because the
sign-up screen queries them before authentication.

| Collection | Document id | Purpose |
|---|---|---|
| `users` | auth `uid` | Account: email, name, phone, **role**, avatar, **preferredLanguage** |
| `workers` | auth `uid` | Public worker profile: professions, languages, **location (geopoint)**, budget range, rating, completedJobs, reviews, availability |
| `jobs` | auto | A posted job: owner, optional assigned worker, category, address, **location (geopoint)**, budget min/max, preferred date, images, `status` lifecycle, rating |
| `jobRequests` | auto | A worker's application to a job (`pending / accepted / declined`) |
| `conversations` | `uidA_uidB` (sorted pair) | One conversation per user pair; `lastMessage`, `unreadCount` |
| `conversations/{id}/messages` | auto | Chat messages incl. attachments: `image`, **`location`** (`"lat, lng"`), `file` |
| `reviews` | auto | Rating + `originalText`/`originalLang` + **per-language cached `translations`** |
| `payments` | auto | Mock payment records (`method: 'mock'`) |
| `categories` | name | Admin-managed job categories |
| `languages` | BCP-47 code | Admin-managed list of app languages (source of truth for multilingual feature) |
| `reports` | auto | User/worker reporting flow |

Key design decisions:

- **Document id = auth uid** for `users` and `workers` means a worker's
  account and public profile are one document to update, and the profile is
  trivially gate-kept by the security rules.
- **Conversation id = sorted participant pair** guarantees exactly one
  conversation per two users, computed identically on both clients.
- **Live streams everywhere**: the app uses Firestore `snapshots()` streams
  (`watchOpenJobs`, `watchReviewsForWorker`, `watchCompletedJobsForWorker`,
  `watchUserJobs`, chat messages, …). Any change — by any user — appears
  instantly on every connected client with no refresh.
- **No denormalized rank field**: a worker's rank is *computed* from the
  `jobs` collection at display time (Section 7.2), so it can never drift
  from the actual completion records.

### 3.2 Other storage

- **Firebase Storage**: avatar uploads and job images.
- **Local app storage** (`path_provider`): picked job images are stored in
  the app's directory first; their local paths are kept in `jobs.images`
  (`local_image_store.dart`), with cloud upload as the durable copy.
- **Shared preferences**: session cache and light UI state so cold start is
  instant.

### 3.3 Seed dataset

`backend/seed/seed.js` (deterministic, seeded PRNG) populates the project
with a synthetic Pakistan-wide dataset: **49 workers** across multiple cities
and regions including Attock (the first nine fixtures cover all five rank
tiers), each worker's rank pinned by *real completed-job documents* spread
over the trailing 12 months, **100–140 reviews per worker in 12 languages**
(Urdu, English, Punjabi, Pashto, Sindhi, Balochi, Saraiki, Hindko, Hindi,
Arabic, Persian, Bengali — non-Latin reviews carry a cached English
translation), ~15,000 completed jobs, 40 open jobs, 25 client accounts and
conversations. The later validation pass disables broad CLEAN deletion, guarantees
at least 100 reviews and every configured corpus language per worker, and makes
the CLI dry-run by default. It does not guarantee a free-tier write allowance; see
the current seed audit and validation record below.

---

## 4. Feature Walkthrough (How Each Function Works)

### 4.1 Authentication & roles

Sign-up collects email, name, phone and — crucially — a **language choice**
whose options come from the `languages` collection merged with the
translation proxy's `GET /languages` (dynamic, never hard-coded). The chosen
code is stored as `users/{uid}.preferredLanguage` and drives (a) the app
display language and (b) which language reviews are translated *into* for
that user. Login is email/password via Firebase Auth; the `role` field then
routes the user into the correct shell.

### 4.2 Posting a job (client)

The client fills title, description, category (from the admin-managed
`categories` collection), address, budget range, preferred date, and photos.
On submit the app calls `LocationService.getCurrentLocation()` and stores the
**real GPS fix as a `geopoint`** on the job document together with the typed
address. The job appears live in the worker job board (`status = open`).

### 4.3 Job requests & assignment (worker)

Workers browse open jobs (filterable by category). Tapping a job shows its
details — including the address/location — and lets the worker send a
**job request** with a message. Requests land on the client's job detail
screen as `pending`; the client accepts one (the job becomes
`status = assigned`, `workerId` set) and declines the rest. Completing the
job sets `status = completed` with a `completedAt` timestamp — this timestamp
is what the rank engine counts (Section 7.2).

### 4.4 Chat & location sharing

`ChatScreen` is a standard Firestore chat: one conversation document per
pair with a `messages` subcollection streamed live, read receipts, image
attachments, and **location sharing** (Section 5.2).

### 4.5 Reviews (multilingual)

After completion, the client opens `ReviewScreen`: star rating + free text
in *their own* language. On submit:

1. The review is **saved first** — `originalText` plus `originalLang`, which
   is inferred from the reviewer's app language and the script of the typed
   text (Arabic script → Urdu, Devanagari → Hindi, etc.).
2. A best-effort translation then runs through the ML proxy **into English**
   and is cached on the document, so English viewers can read it instantly.
   The call has **hard 8 s/10 s timeouts**; if the proxy is unreachable the
   review is still saved and the UI shows an error — it can never hang.
3. Translations are cached on the document: `translations: { 'en': …, 'ur': … }`
   plus a legacy `translatedText` field. A viewer in any language sees the
   review instantly (cached translation), and the **Translate** button
   re-translates on demand into *the viewer's* app language and caches that
   language too.
4. The worker's rating and review count are updated in the same write batch
   (guarded so a missing worker doc can never fail the review write).

### 4.6 Worker profile

The public profile (`WorkerDetailScreen`) shows: avatar, availability,
**rank badge** (vector emblem), professions, spoken languages, live stats
(rating / jobs done / reviews), an **About** card, a **Work History**
preview (3 most recent completed jobs) with a "See all N jobs" page, an
**Overall summary** card (ML, 1–2 paragraphs, Section 6.2) with an "ML"
badge, a **Reviews** preview (3 most recent) with a "See all N reviews"
page, and a **Chat with Worker** button kept reachable without scrolling
through long lists.

### 4.7 Client profile

The client's profile shows their details (name, email, phone, Customer chip),
a live **My Activity** card (Posted / In Progress / Completed counts from
their own `jobs` stream), their **My Reviews** (reviews they have written,
with translation), plus app-language switching and logout.

### 4.8 Payments & reports

Payments are a **mock** flow (`payments` collection, `method: 'mock'`) that
demonstrates the state machine without real money movement. A reporting
flow (`reports` collection) lets users flag others with a reason; reports
start `open` and are handled in the admin surface.

---

## 5. Location Feature — How It Works

### 5.1 Acquiring a position (one-shot, consent-based)

All location logic lives in `LocationService` wrapping the `geolocator`
package through an injectable `LocationProvider` interface (tests inject a
fake provider; the real one is `DeviceLocationProvider`).

`getCurrentLocation()` performs, in order:

1. `isLocationServiceEnabled()` — is GPS on device-wide? If not → return
   `null` (callers degrade gracefully).
2. `checkPermission()` — if the fine-location permission was never granted,
   `requestPermission()` shows the Android system dialog. Denied or
   denied-forever → return `null`.
3. `getCurrentPosition()` — a **single** GPS fix, returned as a Firestore
   `GeoPoint`.

Design decision: the app requests location **only on explicit user action**
(entering the Workers tab, posting a job, tapping "share location" in chat).
There is **no background or continuous tracking** anywhere — this is stated
in the class documentation and verified by the rules: `workers.location` is
written only by the worker's own service call, never by the server.

### 5.2 Where the position is used

| Feature | How the position is used |
|---|---|
| **Nearby Workers list** | The Workers tab fetches the worker pool, computes haversine distance (Geolocator) from the client's fix to each `workers/{uid}.location`, and **sorts the list closest-first** (workers without a stored location go to the end). First 10 cards + "Show all N workers". Each card shows "X km away". If the client denies location, the same list shows without distances. |
| **Job posting** | The real GPS fix is stored on the `jobs` document as a `geopoint` next to the typed address, so workers see exactly where the job is. |
| **Chat location sharing** | See below. |

### 5.3 Sharing location (in chat)

The chat input bar has a location-share button. Tapping it:

1. Calls `getCurrentLocation()` (same consent flow; a snackbar explains how
   to enable location if permission was denied).
2. Sends a chat message with `text: 'Shared my location'`,
   `attachmentType: 'location'` and `attachmentUrl: "lat, lng"` (5-decimal
   precision) into the shared `messages` subcollection — so it is just
   another chat event: it arrives live, is persisted, and keeps
   `lastMessage` on the conversation up to date.
3. The **recipient** sees a tappable location chip in the conversation.
   Tapping it calls `MapLauncher.openLocation(lat, lng)`, which first tries
   the `geo:lat,lng?q=lat,lng` deep link (on Android this resolves directly
   to the installed maps app) and falls back to the universal Google Maps
   URL `https://www.google.com/maps/search/?api=1&query=lat,lng` — so the
   pinned location opens in Google Maps on any device.

Because the share is a *message*, it works even if the receiver's own
location permission is off; they only need a maps app installed.

---

## 6. Machine Learning Features

### 6.1 Translation (two implementations, same contract)

**Production path (the app).** A small Express **translation proxy**
(`backend/translation-proxy/`) sits between the app and the **Google Cloud
Translation** API (neural MT). The API key is stored **only on the server**
(`GOOGLE_TRANSLATE_API_KEY`) and never shipped in the APK. Endpoints:

- `POST /translate { q, target } → { translated }`
- `POST /summarize` (below)
- `GET /languages` — the dynamic list of languages the engine supports; the
  app merges it with the Firestore `languages` collection, so the sign-up
  language picker is **data-driven, not hard-coded**.

The app side (`TranslationService`) is built around failure: the proxy call
has an 8-second timeout; on any failure it falls back to a local pass-through
so the UI never hangs (this fixed the original "review submit loads forever"
bug). Target language is always the **viewer's** `preferredLanguage`, never
a constant. Results are cached per language on the review document, so a
translation is paid for once and then served from data.

**Demo path (no key required).** `docs/demo/` contains a genuinely
*trained*, zero-dependency SMT engine to demonstrate the ML pipeline offline:

- **Parallel corpus**: 44 sentence quadruples aligned across English, Urdu,
  French and Hindi (`data/parallel_corpus.json`), drawn from real review
  phrasing.
- **Word model**: word-level Bayes translation model P(w_tgt | w_src) with
  maximum likelihood + Laplace smoothing, using English as the pivot language
  for pairs without a direct side.
- **Phrase table**: 2- and 3-word phrases mined from the aligned sentences
  with longest-match application, so common review phrases ("very good
  work", "time par kaam karna") translate as units rather than word salad.
- **Translation memory**: fuzzy sentence matching against the corpus — an
  exact/near hit returns the known-correct translation (measured hit quality
  of 0.97 on a held-out Urdu→English test sentence in the demo).

### 6.2 Summarization (extractive ML)

The "Overall summary" card on each worker profile is produced by an
**extractive** summarizer (it selects and ranks the reviewers' own sentences
rather than generating new prose — no hallucinated claims about the worker):

1. **Language alignment** — every review is machine-translated into the
   viewer's target language first (neural MT in the proxy), so a mix of
   Urdu/Punjabi/Pashto/English reviews can be summarized together.
2. **Sentence segmentation** — RTL-aware (Urdu `۔`, `؟`; Hindi; Arabic
   punctuation).
3. **TF-IDF scoring** — each sentence is scored by
   `Σ tf(w) · log(1 + N/df(w))`, length-normalized — the standard
   extractive-salience function.
4. **Sentiment-lexicon guidance** — per-language positive/negative lexicons
   (English, Urdu, Hindi, French) steer selection: the top-scoring
   non-negative sentences form paragraph 1; the top negative sentences form
   paragraph 2 (complaints are surfaced, not hidden).
5. **Output contract** — a lead sentence ("Overall, customers rate Hina
   Shahzadi 4.2/5 across 127 reviews.") + **1 paragraph for ≤4 reviews, 2
   paragraphs for more**, exactly as specified for the FYP.

The Flutter side (`SummaryService`) calls the proxy; if the network is down it
runs the *identical* TF-IDF + lexicon algorithm implemented in Dart, so the
card works offline. Both implementations are covered by the
`summary_service_test` suite.

### 6.3 Ranking (deterministic rule engine)

Worker rank is **not** ML — it is a transparent, verifiable rule:

- Count the worker's `jobs` with `status = 'completed'` whose
  `completedAt` falls inside the **trailing 365 days** (rolling window,
  recomputed live from the stream).
- Thresholds: **Apprentice 0 / Journeyman 156 / Expert 312 / Master 468 /
  Grandmaster 624** — one rank step = 156 completions per year (~3 jobs a
  week across a full working year).
- Displayed as a proper vector **emblem** (shield, hexagon+lightning,
  star+dot, nested diamonds, crown+jewels) plus the count-to-next-rank, on
  the public profile and the worker's own profile.

---

## 7. How Worker Profiles Are Ordered (Top vs. Bottom)

There are **two different "rankings"** in the app — worth distinguishing
clearly:

### 7.1 The browse list (who appears at the top of "Nearby Workers")

Order is **pure proximity**, computed live:

1. The Workers tab takes the client's current GPS fix.
2. For every worker in the pool (up to 500, profession-filtered), it
   computes the great-circle distance to `workers/{uid}.location`.
3. The list is sorted **closest first** (ascending km). Workers with no
   stored location sort to the **bottom**, preserving collection order among
   themselves.
4. The first 10 are shown; "Show all N workers" expands the rest.

So: a worker is "at the top" because they are geographically closest to the
viewer, and "at the bottom" because they are farthest (or missing a
location). Ratings do **not** reorder this list — the star rating is shown
on each card as information. (If the viewer denies location, distances are
unknown and the list falls back to collection order.)

Implementation note: distance is computed client-side over the fetched pool
(haversine). At the project's scale this is a deliberate, simple choice; a
Firestore geospatial extension would be the production upgrade path and is
documented as such.

### 7.2 The worker's rank (Apprentice → Grandmaster)

This is the badge on the profile, and it is ordered by **productivity
within the last year**, as defined in Section 6.3: the worker's completed
jobs inside a rolling 365-day window are counted, and the highest threshold
met (0 / 156 / 312 / 468 / 624) determines the tier. It is computed live
from the `jobs` stream (no stored field that can go stale), and a worker can
lose a rank if they stop completing jobs — the window rolls forward.

---

## 8. Security & Privacy

- **Firestore security rules** enforce role-based access (own-document
  self-management only; worker profile field whitelist; public-read for
  `languages`/`categories` used pre-auth).
- **API key protection**: the translation key lives only in the proxy's
  environment, never in client code.
- **Location privacy**: one-shot, consent-based position acquisition only;
  no background tracking; sharing a location is an explicit chat action.
- **Auth**: Firebase Auth (email/password) with hashed credentials managed
  by Google; the app stores no passwords.

---

## 9. Testing & Quality Assurance

- **Widget/unit test suite** in `mobile/test/` (mocktail-based, all services
  injectable): auth flows, language selection at sign-up and in profile,
  review submission & translation (including non-Latin scripts), rank
  thresholds (boundary tests at 155/156, 311/312, …), work-history rendering
  with 150+ jobs, summarizer output contract, translation timeouts,
  location-permission paths, chat and job flows, profile screens.
- **Deterministic seed** with a fixed PRNG seed: the same dataset every
  run, verified by dry-run assertions (tier windows, review counts, unique
  ids, language coverage).
- **Interactive demo** (`node docs/demo/server.js`, port 8090): a
  zero-dependency walkthrough of translation (SMT + TM), summarization,
  ranks and the client flows — usable in a classroom without an API key.

---

## 10. Known Limitations & Future Work

| Area | Current state | Planned |
|---|---|---|
| Geo queries | Client-side haversine over a fetched pool (≤500) | Firestore geospatial extension; server-side radius + pagination |
| Payments | Mock state machine | Real gateway (e.g., JazzCash / ePay) integration |
| Translation | Neural MT (production), corpus SMT (demo) | Bigger parallel corpus; phrase-boosted SMT for low-resource languages (Sindhi, Balochi, Saraiki, Hindko) |
| Summarization | TF-IDF extractive + lexicons (en/ur/hi/fr deep, others via TF-IDF) | Transformer extractive/abstractive summarization via the proxy |
| Location | One-shot fixes only | Optional continuous sharing during an active job (explicit, revocable) |
| Offline | Graceful degradation (originals shown, local summarizer) | Firestore offline persistence + queueing for writes |

---

## 11. Repository Map (quick reference)

```
mobile/lib/
  views/            client/, worker/, auth/, jobs/, reviews/, chat/, profile/
  services/         *Service.dart — all Firestore & network I/O
  models/           user, worker_profile, job_model, review_model,
                    worker_rank, app_language, …
  core/             theme, shared widgets (rank badge, review tile,
                    completed-job tile, avatars)
backend/
  translation-proxy/  index.js — /translate, /summarize, /languages
  seed/             seed.js  — full Pakistan dataset
docs/
  demo/             zero-dependency ML demo (server.js, parallel corpus)
  firestore/        schemas.md, firestore.rules
mobile/test/        full widget/unit test suite
```


---

## 12. Step 7 source implementation record — 18 October 2026

**Status: source implemented, NOT §12-complete.** Flutter/Dart, the analyzer,
widget runtime, visual/keyboard checks and the Firebase Rules compiler/emulator
are unavailable here. Syntax inspection is not a substitute for those checks.
No Firebase deployment, production KYC or real payment integration was performed.

### Screens added (paths relative to `mobile/lib/`)

| Spec | Screen | Source |
|---|---|---|
| D2 | OnboardingCarousel | `views/onboarding/onboarding_carousel.dart` |
| D3 | PermissionExplainerScreen | `views/settings/permission_explainer_screen.dart` |
| D4 | OfflineScreen / shared banner | `core/widgets/offline_banner.dart` (both variants) |
| D5 | ForceUpdateScreen | `views/auth/force_update_screen.dart` |
| D6 | LanguagePickerScreen | `views/settings/language_picker_screen.dart` |
| D7 | VerificationScreen | `views/worker/verification_screen.dart` |
| D8 | LegalScreen | `views/settings/legal_screen.dart` |
| D9 | DeleteAccountScreen | `views/settings/delete_account_screen.dart` |

Settings is a working companion entry for language, Terms/Privacy and the danger
zone, **not yet the full B15 breadth screen**. Profile/dashboard, Splash/auth,
signup, browse/posting/chat location access and the admin Workers page are wired
to the corresponding flows. The old dead Help action is honestly labelled Terms
& App Guide until B14 provides the real help centre. Admin manual verification
requires a separately approved secure/in-person identity check: device-local
CNIC/selfie references cannot be remotely viewed. Use test/demo images here.
Shared admin dialogs now trap keyboard focus, support Escape, restore focus,
lock background scrolling and provide a 44px close target; browser validation is
still pending.

### Services, models, policy and Firestore

- Preferences/onboarding/build flags; explicit one-shot location access; a
  Firebase-stream-inferred outage monitor with retry/retained-data banners; a
  fail-open release gate. `APP_BUILD_NUMBER` must match pubspec/--build-number.
- Dynamic language catalog/search/fallback acknowledgement and chosen-target ML
  previews. Review submit acknowledges the save without awaiting optional bounded
  ML translation/caching; target is the chosen language, never fixed English.
  Source is `und` rather than guessed from script/preference. Originals remain
  originals on unavailable/unchanged translations. English navigation is unchanged.
- Optional public verification status/dates on WorkerProfile; private proof
  references, consent and notes in owner/admin-only `workerVerifications/{uid}`.
  No Storage upload or automated remote identity check. Encoded per-UID photo
  folders, resolved-path checks, and public-image-reader proof isolation are added.
- AccountAccessService + AccountDeletionService + AccountDeletionRepository:
  password reauth/token refresh first; pause-before-preflight in both job roles;
  bounded, first-page-draining, resumable cleanup; profile/private-proof deletion
  acknowledged before Auth deletion; missing-profile recovery at next sign-in.
  Typed confirmation and dialog precede destructive work. Active work blocks it.
- Optional private `accountDeletions/{uid}` progress/tombstone; non-persisted
  `UserModel.deletionPending`; optional `jobs/payments.anonymized`. Completed
  counterparty jobs/receipts are replaced with allowlisted de-identified records,
  while individual reviews/applications/chats and non-retained jobs are removed.
  Identifying job fields and unknown legacy fields are dropped, not merged.
  History does not launch erased coordinates or contact/pay/review a shared sentinel.
- Moderation reports, minimal tombstones, document/reference IDs and anonymous
  aggregate ratings/counts can remain; no automatic expiry, irreversible anonymity,
  other-device wipe or provider/SDK-cache erasure is claimed. Local managed shared
  job/avatar folders and this UID's proof folder/preferences are cleared, not
  camera/gallery originals or other UID proof folders. Future breadth collections
  must extend cleanup and the policy when introduced.
- Jobs updates now require the owner/assigned worker/admin with status/field
  boundaries; workers apply rather than self-assign. Chats/messages are private
  to participants (admin read permitted); first parent/message creation is atomic
  and private listening bootstraps safely. Receipts/reports have scoped reads.
  Role, verification, admin flags and worker aggregates are protected; optional
  `workers.ratingReviewId` proves a weighted aggregate addition alongside a new
  participant-authorized completed-job review. Concurrent aggregate conflicts may
  require retry; no trusted aggregation backend is claimed.
- Schemas/rules/indexes are updated together. The existing 15 indexes are retained
  and two active-work preflight indexes appended (17 total); root firebase.json
  continues to reference the docs rules/index manifest. Rules are **not deployed
  or emulator-verified**. See the D9 section of `docs/firestore/schemas.md` for the
  required positive/negative permission and race-test checklist.

### Validation and test counts

**137 new mobile test cases written; 0 executed. Pass/fail and coverage are not
available.** They cover onboarding, permission, outage/recovery, release gating,
dynamic languages/ML preview, verification/consent/local isolation, legal tabs,
reauth/current-account checks, cleanup ordering/limits/partial retry, retention
allowlists, missing-profile recovery, deletion confirmation/busy/error paths,
first-chat bootstrap, no self-assignment, original-translation labels and a hanging
proxy not delaying review submission. Existing assertion intentions are retained;
obsolete self-assignment/pre-save-translation expectations were updated to the
secure owner-selection/save-first contracts. The absent-worker aggregate test
keeps its ID/rating checks on the saved review and now explicitly verifies that
no missing worker aggregate is updated, matching the actual existing contract.

Checks actually run: all 93 changed/new Dart files parsed by tree-sitter; local
package imports resolved; JSON/index manifests and preservation of prior indexes
checked; git diff --check passed. Admin `npx tsc -b --force`, `npm run lint` and
`npm run build` passed after the final dialog change (lint: 0 errors/warnings;
Vite warns about the approximately 837 kB production bundle). No visual, keyboard,
Flutter type/analyzer/runtime or Rules-emulator result is implied. The available
third-party Rules parser predates v2 and could not validate this file.

### Deliberate deferrals and spec/code conflicts (§15)

1. Do not mark any of these screens fully done until Flutter analyze/tests and
   runtime/visual/accessibility checks are run; validate rules in the emulator
   before deploying. No failed SDK-install method was repeated.
2. Device-local proofs cannot satisfy remote admin image inspection. Followed the
   no-Storage constraint and exposed an honest manual external-check workflow,
   not pretend remote KYC. A production identity process is outside this batch.
3. The original two-delete Auth shortcut could not support D9's deletion promises.
   Followed the spec with real existing-collection cleanup/recovery, and explicitly
   disclosed retained safety/operational/anonymous data and erasure limits.
4. Original open-job worker self-assignment conflicted with owner-only assignment
   authorization. Changed it to a worker application, preserving public callbacks
   and single-pop/theme/duplicate-submit assertions. The later application-withdrawal treatment
   is not claimed complete merely because this legacy flow was corrected.
5. Fixed-English/guessed-source review caching conflicted with chosen-language ML
   and could keep submit waiting on optional I/O. Followed chosen-target, bounded
   post-save translation; preserved/expanded service and widget assertions.
6. The remaining Step 8 breadth screens, full B14/B15 controls, permission gating
   for a future LocationPickerScreen, future-collection cleanup/rules and the
   Pakistan dataset/local Flutter run remain outside this Step 7 implementation.


---

## 13. Step 8 source implementation record — 19 October 2026

**Status: source implementations added, NOT §12-complete.** No Flutter/Dart SDK,
analyzer/widget runtime, visual device verification or Firebase Rules emulator
was available. No screen is marked fully done, no rules were deployed and no
real money moved. Quote invitations/booking remain explicitly server-gated OFF.

The local checkout's metadata started this turn at the original base while its
saved files matched the pushed Step7 commit. File hashes were checked against
`cbd1e69`; only the current branch reference/index was restored, without changing
any working file, before these independent screen commits were made.

### Screen source paths (relative to mobile/lib/)

| Spec | Screen | Path |
|---|---|---|
| B5 | SavedWorkersScreen | views/client/saved_workers_screen.dart |
| B8 | LocationPickerScreen | views/client/location_picker_screen.dart |
| B7 | AddressBookScreen | views/client/address_book_screen.dart |
| B13 | NotificationsScreen | views/notifications/notifications_screen.dart |
| B10 | RescheduleJobScreen | views/jobs/reschedule_job_screen.dart |
| B12 | MyReviewsScreen | views/reviews/my_reviews_screen.dart |
| B14 | HelpCentreScreen | views/settings/help_centre_screen.dart |
| B15 | SettingsScreen (completed companion) | views/settings/settings_screen.dart |
| C3 | AvailabilitySettingsScreen | views/worker/availability_settings_screen.dart |
| C4 | JobAlertPreferencesScreen | views/worker/job_alert_preferences_screen.dart |
| C5 | PerformanceScreen | views/worker/performance_screen.dart |
| C7 | PortfolioScreen | views/worker/portfolio_screen.dart |
| C8 | CertificationsScreen | views/worker/certifications_screen.dart |
| C9 | ClientProfileScreen | views/worker/client_profile_screen.dart |
| C10 | JobScheduleScreen | views/worker/job_schedule_screen.dart |
| C11 | WithdrawRequestScreen | views/jobs/withdraw_request_screen.dart |
| C12 | NavigateToJobScreen | views/jobs/navigate_to_job_screen.dart |
| B11 | DisputeScreen | views/jobs/dispute_screen.dart |
| C2 | PayoutScreen | views/worker/payout_screen.dart |
| B9 | QuoteRequestScreen (gated) | views/jobs/quote_request_screen.dart |
| B2 | WorkerComparisonScreen | views/client/worker_comparison_screen.dart |

B2 is defined in §6 but missing from §13's order table. It is included last to
honor the complete screen list instead of silently omitting it. Within Step8,
B8 precedes its B7 caller, and notifications precede dependent workflows. There
is one conventional feature commit for each screen above.

### Services/models and Firestore

- ProfileService adds ID-only saved workers, private saved-address migration/CRUD,
  working hours/days off/radius, board preference updates, and stable-ID portfolio /
  certification array mutations. Generic identity saves preserve auxiliary fields.
  Missing photos/removed bookmarks are meaningful, not fabricated data. Worker
  detail keeps Chat fixed at the bottom; comparison has aligned horizontal columns,
  frozen headers and sticky contact actions with actual annual rank history.
- LocationSelection validates finite coordinate ranges/five-place precision; Post
  Job accepts corrected/saved pins rather than fetching GPS over them. Navigation
  uses explicit consent, straight-line distance and optional **worker-entered** ETA,
  never a fabricated route time, embedded map or background location subscription.
  Derived locationProvided distinguishes a missing legacy pin from real 0,0.
- NotificationService owns generic in-app records and recipient-only read state.
  Profile preferences filter the list/badge, not storage/push/email. Existing core
  actions emit bounded best-effort post-ack updates; new dispute/change/quote flows
  can create notices atomically. Client shutdown/network failure can lose/delay
  updates; no trusted server notification/audit service is implied.
- AuthService adds bounded current-auth-email password reset and independent nested
  preference writes. Settings retains last loaded data on refresh errors. Support
  email is operator-configured via SUPPORT_EMAIL; unset config is honestly labelled
  non-interactive info with no invented address. APP_VERSION/APP_BUILD_NUMBER must
  remain aligned with the release's pubspec/build flags.
- JobService adds confirmed active-client rescheduling/cancellation, a live booked
  calendar query and quote-booking companion. Existing APIs/callbacks remain.
  Withdrawn application history is preserved and transactionally protected against
  selection races; pending filters and performance exclude withdrawn requests.
- PerformanceService calculates plain-map ratios/valid rating/schedule proxies with
  unknown denominators and a three-completion unlock. ClientActivityService projects
  client identity/activity **without** addresses, coordinates, contact fields,
  descriptions or free-text job titles; it does not promise a retroactive private
  field-level migration of legacy signed-in-readable job documents.
- DisputeService atomically creates one completed-job case, linked report and generic
  notice; linked admin resolution updates the matching case/report together. Exact
  report/case link proofs prevent resolving an unrelated case. Evidence stays local,
  credential listings remain self-declared, and no automated KYC/refund/SLA is claimed.
- PayoutService uses server-confirmed paid receipts, integer paisa, reservation status,
  same-attempt IDs and revision/transaction checks for normal-client concurrency.
  Source tests cover uncertain-attempt reuse and original recorded amounts. This is
  a client-driven simulated ledger, **not** a production wallet or independent
  trusted-server aggregate proof against modified clients/admin overrides.
- QuoteService provides a bounded available-worker preview (≤500 pool, ten invitees),
  approximate public area/private exact pin, worker reply, price comparison and
  atomic selected-price/schedule booking. IDs and original booking returns are
  idempotent; no exhaustive matching/response-time promise is made. Feature service
  writes AND Rules require protected config/features.quotesEnabled == true.

**Shape changes are optional/backward-compatible and documented with their screen
commits in docs/firestore/schemas.md.** New collections: notifications, disputes,
payouts, quoteRequests, quotes. Private address/payout/quote-location documents
avoid putting newly collected exact addresses/account references on public profile
records. User saved/pref fields, admin-only verifiedClient, worker content/settings,
job cancellation/provenance and withdrawn status are additive. Existing 17 indexes
are preserved; five appended = **22 total**. Root firebase.json links the manifests.

Account deletion now also drains own inbox/quotes/private exact pins, removes own
reply/invite references and detaches selected-worker pointers. Payout account
references/private preferences are removed while amount/status/date records are
de-identified. Safety disputes/reports remain under explicit moderation retention;
other inbox references/copies, legacy imported identifiers, provider logs, platform
caches and other devices are not pretended wiped. No automatic expiry is claimed.

### Actual validation / test count

**96 new mobile test definitions added; 0 executed.** Pass/fail/coverage are unknown.
Parameterized save/remove assertions are retained inside a single test. Existing
modified test assertion counts are preserved/increased; the deletion batch now
asserts five deletes and both private-parent lookup counts. No assertion was simply
removed to hide a changed constructor or failed feature.

- All **263** Dart lib/test files parsed by tree-sitter; **106** changed/new Dart
  source/import checks passed. This is not type analysis or runtime verification.
- All 40 Flutter target file paths and six admin target pages in the full brief
  exist after the B2 omission was caught. Existence is not a definition-of-done pass.
- Existing-index preservation, root Firebase links, JSON and git diff --check pass.
- Admin npx tsc -b --force, npm run lint and npm run build pass after the final linked
  case/report change; lint 0 warnings/errors. Vite retains a roughly **838 kB** bundle
  warning. No browser/keyboard/Flutter/Rules-emulator result is implied.
- No app dependency/state-management/chart/calendar/maps package, MatchingService,
  rank-engine/SummaryService rewrite, Storage upload, real gateway or FCM added.

### Deliberate gates, omissions and spec conflicts (§15)

1. **Quotes not enabled/shipped:** the brief explicitly gates B9 on A1–A4 green.
   The SDK is unavailable, so config/features is never activated. Only an operator
   may enable it after prerequisite AND quote/rules tests pass; missing config is
   fail-closed. No dead CTA or fake sent invitation is exposed by default.
2. **Private-schema override:** proposed public users.addresses and
   workers.payoutMethod.accountRef conflict with the existing signed-in profile
   reads/privacy requirement. New exact saved pins and account references are
   owner/admin-private instead, with type-only public payout metadata and a legacy
   address migration. Imported public sensitive fields still need operator review.
3. **Cancellation:** cancelled does not also mean open. Kept cancelled history,
   used truthful impact copy and did not secretly reopen it on the board.
4. **Review SLA/credential evidence:** 48h is labelled a target, not a guaranteed
   response; credentials are self-declared, verification is a separate manual demo,
   and local evidence cannot magically be seen remotely. No automatic refund.
5. **ETA:** no route-time API exists. Used straight-line distance and optional
   worker-supplied minutes with a fresh explicit one-shot Chat position, not guessed
   travel time. No new Maps billing or location tracking.
6. **Single dispute per job:** the demo uses one deterministic case record instead
   of multiple closed cases; this stricter limit is disclosed and prevents duplicate
   open claims/reports under concurrency/uncertain responses.
7. **B2/order:** full list wins over §13's accidental omission; dependency order is
   used within the remaining-breadth step. The earlier Step7 wording incorrectly
   called the legacy application flow C2; C2 is payout, C11 is withdrawal.
8. **Operational config:** SUPPORT_EMAIL is intentionally not fabricated; configure
   it at release for email intent. Version/build defines must match the real build.
9. **Still unverified, not waved through:** Flutter analyze/tests/coverage, required
   device/text-scale/RTL/accessibility checks, Firebase Rules permission/budget/race
   tests, production-data migration and the Pakistan seed/local Flutter run remain
   outstanding. No failed SDK-install method was repeated and no deployment done.

### Required next validation before marking screens done

With the repository's supported Flutter/Dart toolchain: run flutter pub get,
flutter analyze and flutter test --coverage in mobile. Run the Rules emulator
matrix for stranger/participant/admin privacy; first chat/bootstrap; pending
selection/withdrawal races; exact quote pin privacy; feature OFF; concurrent quote
accept/idempotent retry; withdrawal revision/amount/reference confidentiality;
profile-before-Auth deletion, late writes and resumable cleanup. Verify narrow
320px/text scale 2.0, long RTL content, frozen comparison/calendar scrolling,
keyboard/dialog focus and every live entry/retry path. Keep quotes disabled until
these checks pass. Dataset breadth and proxy-backed language coverage must be
verified separately; no live Firebase seed run is claimed here.


---

## 14. Executed validation and regression fixes — 19 October 2026

This section supersedes the **historical source-only / unrun** status of §12/§13.
It does not convert unperformed native-device/manual or live-provider checks into
passes. No production Firebase access, deployment, quote activation or live seed
was performed. No mobile runtime dependency/state-management package was added.

### Actual executed evidence

Application-code checkpoint `d4ec965` passed hosted run
https://github.com/MesumAbbas1212/Quick-Fix/actions/runs/39231706600:

| Check | Actual result |
|---|---|
| Flutter 3.44.9 / Dart 3.12.2 dependency resolution | Passed |
| flutter analyze --no-pub | No issues found |
| Full flutter test --coverage suite | **715 passed / 0 failed / 0 skipped** |
| Official Firestore Rules compiler + emulator | **24 passed / 0 failed** |
| ML proxy HTTP/provider-contract tests | **7 passed / 0 failed** |
| Pure seed-generator/safety/corpus tests | **7 passed / 0 failed** |

Final tooling checkpoint `fed9334` passed all four jobs in
https://github.com/MesumAbbas1212/Quick-Fix/actions/runs/39232533612:

- Flutter 3.44.9 / Dart 3.12.2: analysis **no issues**, **715 passed / 0 failed /
  0 skipped**, machine completion true. Full-run LCOV: **7,833 / 9,565 lines
  (81.89%)**. Coverage is an overall line measure, not proof of every native path.
- Real Firestore emulator: **24 / 24 passed**, including concurrent selection /
  withdrawal, competing quote acceptance, stale payout revision and amount-
  preserving erasure. No production project was accessed.
- Backend contracts: **7 / 7 proxy + 7 / 7 seed tests passed**; dry-run audit passed.
- Admin `tsc -b --force`, lint and production build passed; lint zero warnings /
  errors. The pre-existing **837.79 kB** bundle-size warning remains, not hidden.

CI uses maintained SHA-pinned official actions on Ubuntu 24.04, publishes the
full-run line coverage and distinguishes admin build checks from browser tests.
Full logs/coverage are artifacts; per-test failures, when present, are available
individually in Check Run annotations. The final report-only successor does not
change application, test, Rules, dependency or workflow code after this run.

**A preliminary CI green was explicitly rejected:** the initial tee pipeline
masked failing command exit codes. It is NOT counted as a pass. All commands now
use bash pipefail, the final job enforces each outcome, and the diagnostic script
also independently requires Flutter machine completion success. The initial
compile errors were found by reading actual diagnostics, not accepted on status
color. New runs with genuine failures correctly returned failure until fixed.

### Files and behavior fixed (no new screen batch)

- `.github/workflows/validate.yml`, `.github/scripts/publish-validation.mjs`:
  reproducible development-only mobile/Rules/backend/admin jobs, bounded runs,
  restricted permissions/no persisted checkout credentials, machine-readable test
  diagnostics, failure annotations and coverage reporting. No production secrets.
- `validation/firestore/*`, `firebase.validation.json`: real Rules compilation in
  the isolated local `demo-quickfix-validation` emulator. Negative tests demand
  permission-denied, not arbitrary SDK/setup exceptions. Tests cover role/trust
  escalation, private records, owner assignment/worker progression, first chat,
  receiver read state, review proof, receipt/report/notification scope, payout
  revision, fresh-auth cleanup/stale-token recreation, history de-identification,
  quote OFF/exact-pin/booking and bidirectional dispute-report links. Added actual
  concurrent selection/withdrawal, quote acceptance and payout-revision races,
  plus amount-preserving payout erasure. These are regression checks, not a blanket
  security certification or independent financial audit.
- `rank_badge.dart`, `review_list_tile.dart`, `profile_service.dart`,
  `job_schedule_screen.dart`, `report_screen.dart`: real compiler failures fixed
  (void-returning drawing/cascade calls, mutable nullable promotion, ambiguous
  nested conditional, const-for expressions and typed mock interfaces). Report /
  payment radios use current RadioGroup APIs and a proper Material ink ancestor.
- `summary_service.dart`: invalid const closure map made final and optional proxy
  I/O bounded/injectable. Existing extractive algorithm/paragraph contract is NOT
  rewritten. Locale-safe public APIs and original constructor names are retained.
- `app_card.dart`: adds an inner transparent Material while preserving the exact
  card decoration/padding so ListTile/radio ink is not hidden by a DecoratedBox.
  `rank_progress_screen.dart`: numeric progress semantics satisfy current Flutter
  accessibility invariants; rank emblems/threshold policy unchanged.
- `main.dart`, `test/flutter_test_config.dart`: explicit English Intl date-symbol
  initialization in app and each test isolate, not dependency on test order.
- `worker_onboarding_screen.dart`: profession keys use enum names; an existing
  profile is actually retained so counts/rating/creation date survive resave. New
  profiles preserve the provided account membership date. No aggregate forgery.
- `client_home_screen.dart`, shell location injection, narrow header rows and
  payment identity: graceful optional-service errors, responsive wrapping and
  correctly separated RTL-safe name/date information. Existing public parameters
  remain and added services stay nullable/default-real.
- `workers_screen.dart`, `category_grid_screen.dart`: removed null-returning
  timeout callbacks on covariant Future<GeoPoint> providers. Genuine timeouts
  still take the existing unknown-location catch path; a valid granted fix is no
  longer swallowed by a runtime callback type error. No fake 0 km or new consent.
- Test fixtures use correct Firestore query snapshots/transaction types, controlled
  async image/provider data and typed Mocktail fallback values. Nested stubbing
  and invalid captured-map casts were repaired. Lazy controls are built/scrolled
  and a frame rendered before tapping; missed-hit warnings/assertions are not
  suppressed. Report completion is tested over a real caller route. Existing
  assertions were preserved/expanded; no failing test was skipped/deleted to get
  a green run. Read-only own reviews correctly omit a no-op Translate action.

### Live-ML boundary checks, actually local/CI tested

`backend/translation-proxy/index.js` now exposes an injectable app factory while
its normal entry still starts the server. The actual Cloud Translation v2 contract
returns a tuple of `{code,name}` languages; the old v3-style field assumption
produced unusable catalog data. It now unwraps the real v2 shape, returns English
UI labels without falsely calling them native names, and preserves admin-catalog
native-name priority. Review text (including ASCII) and the requested target reach
the ML provider without a fixed-English/dictionary shortcut. Provider/summary
I/O and input sizes are bounded; missing/hung/failed providers give explicit
503/504/502 responses without returning provider secrets. Node HTTP tests execute
against injected providers, not paid Google API calls. Therefore actual live
translation quality/low-resource language support remains unverified, not claimed.

### Seed audit, safe operation and remaining language scope

The default **dry run** (no Firebase module/credential/network/write) now reports:
49 synthetic workers / 49 named cities, including Attock; **5,870 reviews**, minimum
**100 per worker**; every worker has every language in the configured corpus:
ur/en/pa/ps/sd/bal/skr/hnd/hi/ar/fa/bn. Rank distribution is 11 Apprentice,
13 Journeyman, 11 Expert, 9 Master, 5 Grandmaster based on actual generated annual
completion timestamps at the unchanged 156-step policy. Fixed-clock generation
is deterministic. Default estimate is **24,319 document writes**, which may exceed
free-tier daily quota; no free-tier capacity guarantee is made.

Weighted chance alone previously left 20/49 workers without a corpus language.
The first coverage cycle is now guaranteed before weighted sampling; low review
count overrides cannot fall below 100. Balochi uses ISO bal; brh is the distinct
Brahui language, confirmed against CLDR metadata. Existing mislabeled imports
need operator review, not blind overwrite of legitimate Brahui data/preferences.
An operator-reviewed SEED_REVIEW_CORPUS JSON file extends language metadata and
native/English sentiment examples without changing application code. No native
text is fabricated to pretend support for an absent language.

**This curated 12-language corpus is NOT exhaustive coverage of every language /
dialect spoken in Pakistan.** Authentic corpus extension and native-language
quality review remain needed for that broader user requirement. Synthetic fixture
locations/reviews are not verified provider addresses or genuine testimonials.
See `backend/seed/README.md` for the format/scope. Default CLI is dry-run; an actual
write requires explicit --write/operator credentials. The former broad CLEAN=1
collection-delete loop is disabled before Firebase initializes. No live seed,
Auth account/password generation or real payments took place in this validation.

### Release configuration batch (19 October 2026)

- **Admin bundle split** (`admin/vite.config.ts`): `build.rollupOptions.output
  .manualChunks` now routes Firebase per product and the React runtime into
  separate cacheable chunks. Locally verified production build (Vite 8.2.0 /
  rolldown): app `55.57 kB`, `react-vendor` `228.15 kB`, `firebase-core`
  `50.65 kB`, `firebase-auth` `105.36 kB`, `firebase-firestore` `396.86 kB` —
  **no chunk exceeds the 500 kB budget and the ~838 kB warning is gone**
  (previously one ~838 kB vendor chunk). `tsc -b`, lint and build pass; all
  five chunks were fetched HTTP 200 from `vite preview` of the built output.
  No in-browser render check was performed in this sandbox (none available);
  CI's admin job likewise covers types/lint/build, not browser tests.
- **Version/build defines**: `README.md` now states the canonical release
  command with `--dart-define=APP_VERSION=1.0.0 --dart-define
  =APP_BUILD_NUMBER=1` matching `mobile/pubspec.yaml` `1.0.0+1`, and
  instructs bumping all three together with `--build-number` per release.
  The Settings "prototype" footer and `AppReleaseService` consume these
  defines; defaults already match pubspec, so a plain debug run stays
  consistent.
- **`firebase.json` vs `firebase.validation.json` confirmed separated**:
  the production `firebase.json` references only `docs/firestore/firestore.rules`,
  `docs/firestore/firestore.indexes.json` and `docs/firestore/storage.rules`;
  it contains **no project ID and no emulator block** (project association is
  operator-supplied via `.firebaserc`/`--project`, which is not in the repo).
  `firebase.validation.json` is emulator-only (host `127.0.0.1:8080`, UI
  disabled, `singleProjectMode`), and the fixed project `demo-quickfix-validation`
  is pinned solely inside the validation harness command
  (`validation/firestore/package.json`). The production configuration therefore
  cannot point at the validation project.
- **`SUPPORT_EMAIL` remains unset** — the support address is an operator
  decision and is not fabricated; `SupportService.isConfigured` stays false
  and the Help surface honestly labels the non-interactive state until an
  operator passes `--dart-define=SUPPORT_EMAIL=<address>`.

### Visual, RTL and accessibility test batch (20 October 2026)

Durable widget tests now pin the narrow-layout, RTL and
accessibility contracts that were previously manual-only claims:

- **Narrow-layout sweep** (`mobile/test/core_state_widgets_test.dart`):
  every pumped screen renders at 320 px logical width at text scale
  1.0 **and** 2.0 with no layout exception (a RenderFlex overflow is
  an exception under test and fails the assertion); frozen-header
  tests prove the schedule calendar and comparison worker header stay
  fixed while their lists scroll; dialog tests prove the report,
  delete-account and cancel-job confirmations trap Tab focus while
  open and return it on dismiss, with 44 px touch targets; WCAG
  contrast is computed (relative luminance per WCAG 2.1) for the
  muted-text token on both surface colours; keyboard-inset tests
  prove the post-job and review forms stay reachable with a 300 px
  simulated keyboard.
- **RTL surfaces** (`mobile/test/content_direction_test.dart`): a
  300-character Urdu review wraps without overflow in
  `ReviewListTile` at 320 px and at 2.0 scale; Urdu names render RTL
  in `WorkerDetailScreen`, chat bubbles and the comparison grid; an
  English control stays LTR.

**Code the tests caught and repaired** (behaviour changes, all in
this batch's commits):

- `mobile/lib/core/theme/app_theme.dart`: `textMuted` `#64748B`
  (4.36:1 on `bgLight`, below AA 4.5:1) → `#5C6B80` (≈5.42:1 on
  white, ≈4.97:1 on `bgLight`); `TextButton` theme minimum size
  44×44.
- `mobile/lib/views/worker/job_schedule_screen.dart`: month nav and
  calendar are pinned above the bookings list (only bookings scroll);
  the pinned calendar has a fixed height budget (260 logical px) with
  the grid cell aspect derived from it and a 440 px width cap, so a
  six-row month always fits and the list keeps a usable viewport on
  wide, short surfaces.
- RTL direction: chat bubbles (`chat_screen.dart`), review original
  text and translations (`review_list_tile.dart`) and worker display
  names (`worker_detail_screen.dart`) now set
  `textDirection: contentDirection(...)`; the comparison grid
  already did.
- `EmptyState` and `LoadingList` (`mobile/lib/core/widgets/`) are
  scrollable, so tall empty/loading states never overflow a tight
  viewport at large accessibility text scales; rendering is
  unchanged when space is ample.
- The report, delete-account and cancel-job confirmation dialogs
  autofocus their safe first action, so focus enters the dialog on
  open (the trap/return contract the tests assert).
- Narrow-layout repairs found by the 2.0-scale sweep: flexing or
  expanding previously natural-width text in job request, post job,
  worker reviews, profile, client home, new chat, notifications and
  worker dashboard rows; `isExpanded` on the post-job category
  dropdown; scale-aware compaction of the conversations header,
  workers header subtitle and dashboard verification nudge.

**Executed evidence** — CI run
https://github.com/MesumAbbas1212/Quick-Fix/actions/runs/39372802600
(commit `f11952a`, all six jobs green):

| Check | Actual result |
|---|---|
| flutter analyze --no-pub | No issues found |
| flutter test --coverage | **853 passed / 0 failed / 0 skipped**, machine completion true |
| Full-run line coverage | **7,913 / 9,599 lines (82.44%)** (baseline at `c4f1432`: 7,833 / 9,565, 81.89%) |

The intermediate attempts in this batch genuinely failed first and
were fixed, not accepted: two runs failed on test-file compile errors
(61 analyze issues: missing imports, `Rect.dy`, positional vs named
mock arguments, `EdgeInsets` vs `FakeViewPadding`, removed
`Element.parent`); the pre-existing schedule reveal test failed
because the pinned calendar starved the bookings viewport (fixed by
the height budget); and the first full sweep execution failed 16
overflow assertions plus 3 dialog-focus assertions, each repaired in
the screens as listed above. Final numbers are from the green run
only.

### Deliberately still not marked done (§15)

No new screens were added in this validation batch; existing source implementations
were repaired and actually exercised. All screen files remain. Narrow-layout,
RTL direction, dialog focus, touch-target and contrast contracts are now pinned
by automated widget tests (above), but full §12 completion still requires
native-device camera/GPS/settings/deep-link behavior, manual visual confirmation
on real devices, live configured translation-language quality,
operator-reviewed legacy-data migrations and explicit staging/release
approval. Quotes remain OFF; emulated quote flags never activate real config.
Financial flows remain simulated/client-driven, evidence/portfolio photos remain
device-local, and data retention/other-device/provider-cache erasure limits remain
explicit. No test pass is claimed for those unperformed tasks.
