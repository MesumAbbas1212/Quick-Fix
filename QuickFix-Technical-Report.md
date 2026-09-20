# QuickFix — Technical Report

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
with a realistic Pakistan-wide dataset: **49 workers** across all five
provinces and Gilgit-Baltistan (9 in Attock district covering all five rank
tiers), each worker's rank pinned by *real completed-job documents* spread
over the trailing 12 months, **100–140 reviews per worker in 12 languages**
(Urdu, English, Punjabi, Pashto, Sindhi, Balochi, Saraiki, Hindko, Hindi,
Arabic, Persian, Bengali — non-Latin reviews carry a cached English
translation), ~15,000 completed jobs, 40 open jobs, 25 client accounts and
conversations. `CLEAN=1` wipes first; `JOBS_SCALE` / `REVIEWS_PER_WORKER`
scale it down to fit the free plan's write quota.

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
