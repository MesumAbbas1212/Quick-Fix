# QuickFix — Technical Dossier for Evaluation

**Prepared:** 23 November 2026 · **Code state:** `arena/f4c30e79-quick-fix` @ `e1561c1`
**Authors:** Mesum Abbas · Ubaid Hassan · COMSATS University Islamabad, Attock Campus

This document describes **what the code actually does**, not what was planned. Where the
implementation falls short of the proposal, it says so — an examiner who finds a gap you
did not mention is far worse than one you explain first.

---

## 0. The one-paragraph version

QuickFix is an Android marketplace that connects customers with local service workers in
Pakistan. A customer posts a job with photos and a GPS pin; nearby workers apply; the
customer hires one; the two chat; the worker completes the job; the customer pays
(simulated) and leaves a review in their own language. Reviews are machine-translated
into the reader's language, and each worker profile carries an automatically generated
summary of all their reviews. Workers earn ranks from their completed-job volume. A React
web dashboard and a five-tab admin section inside the app let an administrator moderate
users, workers, jobs and reports.

The application layer is essentially complete. **The machine-learning layer is the part
that is not finished** — see §10 and §11, which are the sections to read before the viva.

---

## 1. System architecture

There is **no traditional application server**. QuickFix is a *Backend-as-a-Service*
architecture: Firebase supplies the database, authentication and real-time transport, and
the Flutter client talks to it directly. Two small Node services sit alongside it.

```
┌──────────────────────────┐        ┌───────────────────────────┐
│  Flutter app (Android)   │        │  React admin dashboard    │
│  client / worker / admin │        │  (Vite + TypeScript)      │
└───────────┬──────────────┘        └─────────────┬─────────────┘
            │  Firebase SDK (HTTPS + WebSocket)   │  Firebase JS SDK
            ▼                                     ▼
     ┌──────────────────────────────────────────────────┐
     │            Firebase project `quickfix-fyp`       │
     │  Authentication · Cloud Firestore · Security     │
     │  Rules · Composite indexes · Hosting-ready       │
     └──────────────────────┬───────────────────────────┘
                            │ HTTPS (only for ML)
                            ▼
     ┌──────────────────────────────────────────────────┐
     │  Node/Express translation proxy                  │
     │  /translate  /summarize  /languages              │
     │  holds the API key server-side                   │
     └──────────────────────┬───────────────────────────┘
                            ▼
              Google Cloud Translation API  ◄── external service

     ┌──────────────────────────────────────────────────┐
     │  Offline tooling (not part of the running app)   │
     │  seed.js · seed-reports.js · create-accounts.js  │
     │  docs/demo/server.js (local statistical MT)      │
     └──────────────────────────────────────────────────┘
```

**Consequence worth understanding:** because there is no app server, business logic lives
in the client and the **security rules are the only server-side enforcement**. That is a
legitimate architecture, and this project leans on it hard — 469 lines of rules, 28
composite indexes, and a 26-test emulator suite — but it means any rule you do not write
is a permission you have granted.

---

## 2. Technology stack

| Layer | Technology | Version | Role |
|---|---|---|---|
| Mobile UI | Flutter / Dart | 3.44.9 / 3.12.2 | Android app, Material 3 |
| Auth | `firebase_auth` | 5.3.1 | Email + password sessions |
| Database | `cloud_firestore` | 5.4.4 | All application data, live streams |
| Core | `firebase_core` | 3.6.0 | SDK initialisation |
| Location | `geolocator` | 13.0.1 | One-shot GPS, permission handling |
| Media | `image_picker` + `path_provider` | 1.1.2 / 2.1.4 | Camera/gallery, device-local storage |
| HTTP | `http` | 1.2.0 | Calls to the translation proxy |
| Links | `url_launcher` | 6.3.0 | Maps deep links, support email |
| Local state | `shared_preferences` | 2.3.2 | Onboarding flag, small preferences |
| Formatting | `intl` | 0.19.0 | Dates and numbers |
| Web admin | React + Vite + TypeScript | 19 / 8 / 6 | Moderation dashboard |
| Proxy | Node + Express | 22 / 4 | Key-protected ML endpoints |
| Seed tooling | Node + firebase-admin | 22 / 13 | Dataset and demo accounts |
| CI | GitHub Actions | — | Analyze, 908 tests, rules emulator, admin build |

Declared in `pubspec.yaml` but **imported by zero files** — know this before someone greps
for it: `provider` (no state-management library is used), `firebase_storage` (no cloud
uploads), `google_maps_flutter` (no embedded map). There is **no ML Kit dependency**.

---

## 3. The backend, precisely

The question "what backend do you have?" has a three-part answer. Give all three.

### 3.1 Firebase — the actual backend

| Service | Used for |
|---|---|
| **Authentication** | Email/password accounts, password reset, account deletion, ID-token issuance |
| **Cloud Firestore** | 18 top-level collections; every read is a live stream or a one-shot query |
| **Security Rules** | The entire authorisation model — 469 lines, role- and ownership-based |
| **Composite indexes** | 28 declared in `firestore.indexes.json` |
| *Not used* | Storage (see §7), Functions, Hosting, Messaging, Analytics |

There is no server you can SSH into. Firebase handles scaling, replication, backups and
transport.

### 3.2 The translation proxy — the only server you wrote

`backend/translation-proxy/index.js` — a small Express service:

| Endpoint | Request | Response |
|---|---|---|
| `POST /translate` | `{ q, target }` | `{ translated }` |
| `POST /summarize` | `{ workerName, reviews, target }` | summary object |
| `GET /languages` | — | `{ languages: [...] }` |

Why it exists: to keep `GOOGLE_TRANSLATE_API_KEY` **off the phone**. An API key shipped in
an APK can be extracted from the binary in minutes; on a server it never leaves the
process. It also gives one place to swap providers, add timeouts and rate-limit.

It is stateless, roughly 90 lines, and has no database.

### 3.3 Offline tooling — not part of the running system

- `backend/seed/seed.js` — generates the deterministic Pakistan-wide dataset
  (49 workers across 49 cities, ~15 000 jobs, reviews in 12 languages). Dry-run by default.
- `backend/seed/seed-reports.js` — 12 moderation reports + 2 disputes, fixed IDs, idempotent.
- `backend/seed/create-accounts.js` — the five demo logins and their profiles.
- `docs/demo/server.js` — a **local statistical MT engine** (see §10.2), plus a browser demo.

These run on a laptop, not in production.

---

## 4. Data model

| Collection | Doc id | Contents |
|---|---|---|
| `users` | auth uid | Profile, `role` (`user`/`worker`/`admin`), `preferredLanguage`, `blocked` |
| `workers` | auth uid | Public worker profile: professions, languages, geopoint, budget range, rating, `approved`, `blocked`, verification summary |
| `jobs` | auto | Owner, assigned worker, category, address, geopoint, budget, images, status lifecycle |
| `jobRequests` | auto | A worker's application: `pending`/`accepted`/`declined`/`withdrawn` |
| `conversations` | `uidA_uidB` sorted | One per pair; `lastMessage`, `unreadCount` |
| `conversations/{id}/messages` | auto | Text, image, shared location |
| `reviews` | auto | `originalText`, `originalLang: 'und'`, cached `translations`, rating |
| `payments` | auto | Simulated payments |
| `payouts`, `disputes`, `notifications` | auto | Withdrawals, dispute cases, in-app inbox |
| `reports` | auto | Moderation queue: reason, reporter, target, status |
| `categories`, `languages` | name / BCP-47 | Admin-managed catalogues |
| `workerVerifications` | uid | Manual KYC submissions |
| `config/app`, `config/features` | fixed | Release gate, `quotesEnabled` (false) |
| `users/{uid}/private/addressBook`, `workers/{uid}/private/payout`, `jobs/{id}/private/location` | fixed | Owner/admin-only subcollections — deliberately kept off public documents |

Job status lifecycle: `open → assigned → inProgress → completed`, plus `cancelled`.

---

## 5. Real-time — yes, and here is how

**35 call sites** use Firestore `snapshots()`; **16 service methods return a `Stream`.**
Examples: `watchOpenJobs`, `watchUserJobs`, `watchReviewsForWorker`,
`watchCompletedJobsForWorker`, chat messages, unread counts, the admin report queue, the
admin user list, and `watchUser` (which re-routes the app if your role changes).

How it works: the client opens a long-lived connection to Firestore. When any document in
a watched query changes, the server pushes the new result set; the widget rebuilds through
`StreamBuilder`. No polling, no refresh button, no manual cache invalidation.

Two practical consequences to be able to explain:

1. **Chat is genuinely live.** Send a message on one phone; it appears on the other in
   well under a second, including when the receiver is on a different network.
2. **Offline is partially handled.** Firestore keeps a local cache, so previously loaded
   data still renders without a connection; writes queue and flush on reconnect. The app
   also has an offline banner (`core/widgets/offline_banner.dart`) that appears when a
   stream errors.

Limits worth admitting: there is **no pagination** (lists cap at 50), **no presence
system** (the `online` dot on `UserAvatar` is a widget parameter that is never driven by
real presence), and **no server-side full-text search** (search filters the loaded page
client-side).

---

## 6. Authentication and authorisation

### 6.1 Authentication (who you are)

Firebase Authentication, email + password. `services/auth_service.dart` (231 lines) wraps
it: `registerWithEmailAndPassword`, `signInWithEmailAndPassword`, `signOut`,
`sendPasswordReset`, `deleteAccount`, `getUserProfile`, `watchUser`.

Flow:

1. `SplashScreen` listens to `authStateChanges`. A live session goes straight to the right
   shell; no session goes to `LoginScreen`.
2. `LoginScreen` calls Firebase, then reads `users/{uid}` **from the server** (`serverOnly:
   true`) — a cached copy could be stale after an admin blocks you.
3. The `role` field in that document decides the shell: `worker → WorkerShell`,
   `admin → AdminShell`, `user → ClientShell`.
4. No profile document → `ProfileMissingScreen`, which names the UID and explains how to
   provision it. (Before this existed, a correct password produced "check your
   credentials" — the single most misleading bug in the project.)
5. `blocked == true` → immediate sign-out with "This account has been suspended".

Passwords never touch your code — Firebase stores salted hashes. The app holds only a
refresh token in platform secure storage.

### 6.2 Authorisation (what you may do)

Two layers:

- **Client-side routing** — the shell you land in. This is convenience, not security.
- **Firestore Security Rules** — the real boundary. Every read and write is checked
  server-side against `request.auth.uid`, the document's owner fields, and `isAdmin()`.

Key rules to be able to quote:

```js
function isAdmin() {
  return signedIn() && exists(/databases/$(database)/documents/users/$(request.auth.uid))
    && get(...).data.get('role', 'user') == 'admin';
}
```

- Profiles are readable by any signed-in user (a marketplace must show names and ratings)
  but writable only by their owner or an admin.
- `users` create is limited to `role in ['user','worker']` — **an admin can never be
  self-provisioned from the app**.
- Conversations are restricted to their two participants.
- `blocked` is enforced on job creation, message creation, review creation and job
  acceptance through a `notBlocked(uid)` helper.

The rules are tested: `validation/firestore/` runs 26 cases against the emulator, covering
stranger/participant/admin boundaries, first-message bootstrap, and race conditions.

---

## 7. Images — where they actually go

**This is the answer to prepare carefully, because it is the project's biggest functional
compromise.**

`services/local_image_store.dart` (156 lines) writes images into the **phone's own
storage**, in the app documents directory:

```
<app documents>/quickfix_job_images/     job photos
<app documents>/quickfix_avatars/        profile pictures
<app documents>/quickfix_verification/   CNIC + selfie evidence
```

Firestore stores only the **file path** — e.g. `jobs/{id}.images: ['/data/user/0/
com.quickfix.quickfix/app_flutter/quickfix_job_images/xyz.jpg']`.

There is **no upload**. `firebase_storage` is declared in `pubspec.yaml` and imported by
zero files. `storage.rules` exists but nothing calls it.

What that means, stated plainly:

- ✅ Photos work perfectly for the person who took them, offline, with no bandwidth cost.
- ❌ **A photo attached by a client is invisible to the worker on another phone.** They see
  a broken thumbnail, not the picture.
- ❌ Verification evidence cannot be reviewed by an admin — the admin UI says so explicitly
  rather than pretending.
- ❌ Reinstalling the app orphans every image reference.

Why it is like this: Firebase Storage requires the Blaze (pay-as-you-go) plan; the project
runs on Spark (free). Uploading was deliberately deferred rather than half-built.

**If asked "how would you fix it":** add `firebase_storage`, upload on capture, store the
download URL instead of the path, and keep the local path as a cache key. The interface is
already isolated in one service, so the change is contained — roughly a day's work plus the
plan upgrade.

---

## 8. Multiple simultaneous users

Yes. Three different senses, and you should separate them:

**Concurrent clients.** Firestore is multi-user by design. Every phone holds its own
connection; there is no shared session, no server thread to exhaust, no lock in your code.
Fifty users browsing, chatting and posting at once is ordinary load for Firestore.

**Consistent writes.** Where two users can collide, the code uses a Firestore
**transaction** rather than read-then-write:

- `resolveReport` — updates the report *and* its linked dispute atomically.
- `reviewVerification` — updates the verification record *and* the worker's summary.
- Review submission — the review document and the worker's rating/count move together in
  one batch.
- Quote acceptance — status transitions are guarded.

The rules emulator has explicit race tests (concurrent quote accept, withdrawal revision,
duplicate report prevention).

**Not handled.** There is no optimistic-concurrency token on ordinary profile edits (last
write wins), no presence, and no push notification when someone messages you while the app
is closed — the in-app inbox only updates when the app is open. Be ready for that question;
the honest answer is "in-app only, FCM is future work".

---

## 9. Where the ML actually stands

This is the section to rehearse. The application is strong; the ML is the gap.

### 9.1 Translation — three different things exist

| Implementation | Where | Status |
|---|---|---|
| **Cloud path** | `backend/translation-proxy` → Google Cloud Translation | Works, but is an **external API** |
| **Local statistical MT** | `docs/demo/server.js` | Works, your own code, but a 44-sentence corpus in 4 languages |
| **App fallback** | `services/translation_service.dart` | Returns the original text unchanged |

The local engine is real work and worth demonstrating: a word-level Bayes model
`P(target|source)` with Laplace smoothing, a 2–3 word phrase table mined from aligned
sentences, and a translation memory with fuzzy Jaccard matching. Zero dependencies, ~740
lines of JavaScript. But it is trained at startup from **44 sentence quadruples**
(English/Urdu/French/Hindi) — it translates review-like sentences it has seen, and degrades
quickly outside them.

**The compliance problem, stated plainly:** the shipped app calls the proxy, and the proxy
calls Google's API. If your rule is "no external APIs", then **as built, the app's
translation feature does not satisfy that rule**. The local engine satisfies it but is not
wired into the app.

The smallest honest fix, if you want a no-API demo: the demo server already exposes
`POST /api/translate`, but it expects `{text, target}` while the app sends `{q, target}`.
Accepting both (`const text = body.text ?? body.q`) makes the app able to point at your own
engine with `--dart-define=TRANSLATE_PROXY_URL=...`. One line, and the whole flow becomes
API-free — with a 44-sentence vocabulary you must disclose.

### 9.2 Summarisation — no training required, and it works

`services/summary_service.dart` (233 lines) is **extractive TF-IDF**, computed on-device in
Dart: sentence scoring by term frequency × inverse document frequency, with sentiment
lexicons for English/Urdu/Hindi/French, then 1 paragraph for ≤ 4 reviews and 2 for more.

This is a classical IR technique, not a trained neural model — which means **it needs no
training and works offline today**. If your examiner accepts "classical ML", this box is
ticked. If they require a trained model, it is not.

### 9.3 What "training the models" would actually involve

You said the summarisation and multilingual models are not trained yet. Concretely:

- **Translation:** you need a parallel corpus. Public options exist (OPUS, Tatoeba, JW300
  for low-resource languages). A realistic FYP-scale approach is a small transformer
  trained from scratch on ~100k–500k pairs, or fine-tuning a multilingual checkpoint —
  but "no APIs" usually still permits *downloading a pre-trained model* and running it
  locally. That distinction is worth clarifying with your supervisor before you start: a
  locally-executed pre-trained model uses no API at inference time.
- **Summarisation:** an abstractive model (mT5-small, or a distilled variant) fine-tuned on
  review data, exported to TFLite or run server-side in the proxy. You would need a
  labelled review-summary dataset; the seed corpus can bootstrap it synthetically, but you
  must say so.
- **Serving:** either ship the model in the app (TFLite, ~100–300 MB, painful) or run it in
  the proxy (recommended — same interface you already have, just swap the implementation).

The architectural good news: **the app talks to an interface, not to Google.** Replacing
the proxy's internals with your own model changes nothing on the phone.

---

## 10. Progress assessment

Weights reflect what the project claims to be — an ML-centred system — not what is easiest
to finish.

| Area | Weight | Complete | Evidence |
|---|---|---|---|
| Client + worker app | 25 % | **95 %** | ~60 screens, full job → apply → hire → chat → complete → review flow |
| Admin (web + in-app) | 10 % | **90 %** | 14 React pages, 5-tab mobile shell, job moderation, report resolution |
| Data layer & rules | 15 % | **85 %** | 19 collections, 469-line rules, 28 indexes, 26 emulator tests |
| Auth & security | 10 % | **90 %** | Firebase Auth, role routing, fail-closed admin gate, suspension enforcement |
| **ML — translation** | **20 %** | **30 %** | Local engine is real but 44 sentences / 4 languages, not wired to the app; app path uses a disallowed API |
| **ML — summarisation** | **10 %** | **40 %** | TF-IDF works offline; no trained model |
| Testing & QA | 5 % | **85 %** | 908 tests, 81.7 % line coverage, analyze clean |
| Documentation & report | 5 % | **80 %** | Report accurate as of `e1561c1` |
| **Weighted total** | **100 %** | **≈ 73 %** | |

Read it as: **application ≈ 92 %, ML contribution ≈ 33 %.**

What moves the number fastest:

1. Train/serve one real translation model behind the existing proxy interface → **+12 %**.
2. Wire the local engine into the app and disclose its limits → **+4 %** immediately, and it
   removes the API-compliance objection.
3. Train an abstractive summariser → **+6 %**.
4. Device verification pass + report finalisation → **+5 %**.

---

## 11. Where everything lives

### 11.1 Directory map

```
quick-fix/
├── mobile/                        Flutter app
│   ├── lib/
│   │   ├── main.dart              entry point, Firebase init
│   │   ├── app.dart               MaterialApp, theme, home route
│   │   ├── views/                 72 screen files by area
│   │   │   ├── auth/              splash, login, signup, app_shell, profile_missing
│   │   │   ├── client/            home, workers, detail, comparison, filters, addresses
│   │   │   ├── worker/            dashboard, earnings, rank, portfolio, verification
│   │   │   ├── jobs/              post, applicants, tracking, schedule, dispute
│   │   │   ├── chat/              conversations, chat, new chat
│   │   │   ├── reviews/           review, my reviews
│   │   │   ├── admin/             shell + dashboard, reports, accounts, catalog, jobs
│   │   │   ├── payments/          payment, history
│   │   │   ├── settings/          settings, language, legal, delete account
│   │   │   ├── notifications/     in-app inbox
│   │   │   └── onboarding/        carousel, worker wizard
│   │   ├── services/              38 services, all Firestore/network I/O
│   │   ├── models/                33 models
│   │   └── core/                  theme, shared widgets, utils
│   └── test/                      125 test files, 908 passing
├── admin/                         React dashboard (14 pages, 8 api modules)
├── backend/
│   ├── translation-proxy/         Express ML gateway
│   └── seed/                      dataset, reports, demo accounts
├── docs/
│   ├── firestore/                 rules, indexes, storage rules, schemas
│   ├── demo/                      local statistical MT + browser demo
│   └── prompts/                   build briefs used during development
├── validation/firestore/          rules emulator suite
└── .github/workflows/validate.yml CI
```

### 11.2 "If they ask you to change X, open Y"

| Request | File |
|---|---|
| Brand colours, typography, spacing | `mobile/lib/core/theme/app_theme.dart` |
| Card / surface style everywhere | `app_theme.dart`, `core/widgets/app_card.dart` |
| Rank thresholds (156/yr ladder) | `mobile/lib/models/worker_rank.dart` |
| Job categories | `models/job_model.dart` (`enum JobCategory`) + Firestore `categories` |
| Add/remove a bottom-nav tab (client) | `views/client/client_shell.dart` |
| … (worker) | `views/worker/worker_shell.dart` |
| … (admin) | `views/admin/admin_shell.dart` |
| Login screen behaviour or error copy | `views/auth/login_screen.dart` |
| Auth logic, sign-up, password reset | `services/auth_service.dart` |
| Which shell a role lands in | `views/auth/app_shell.dart` |
| Review form / rating submission | `views/reviews/review_screen.dart`, `services/review_service.dart` |
| Review row UI, Translate button | `core/widgets/review_list_tile.dart` |
| Translation call and timeout | `services/translation_service.dart` |
| Summary generation | `services/summary_service.dart` |
| Chat, unread counts, attachments | `services/chat_service.dart`, `views/chat/chat_screen.dart` |
| Job lifecycle, status transitions | `services/job_service.dart`, `models/job_model.dart` |
| Worker applications / hiring | `services/job_request_service.dart`, `views/jobs/job_applicants_screen.dart` |
| Image capture and storage | `services/local_image_store.dart` |
| GPS, permissions, consent | `services/location_service.dart`, `core/utils/location_access.dart` |
| Maps deep link | `services/map_launcher.dart` |
| Admin moderation writes | `services/admin_service.dart` |
| Admin categories / languages | `services/admin_catalog_service.dart` |
| Who may read or write what | `docs/firestore/firestore.rules` |
| Query performance / missing index | `docs/firestore/firestore.indexes.json` |
| Seed dataset, reports, demo logins | `backend/seed/seed.js`, `seed-reports.js`, `create-accounts.js` |
| Proxy endpoints, API key handling | `backend/translation-proxy/index.js` |
| The statistical MT engine | `docs/demo/server.js` |
| Web dashboard pages | `admin/src/pages/*.tsx` |
| Web dashboard data access | `admin/src/api/*.ts` |
| CI pipeline | `.github/workflows/validate.yml` |

---

## 12. Three things to fix before you demo

### 12.1 The APK you install must carry the proxy URLs

All three ML endpoints read `String.fromEnvironment` with **no default**:

```dart
static const String _proxyUrl = String.fromEnvironment('TRANSLATE_PROXY_URL');
```

A plain `flutter build apk` therefore ships with **no translation, no proxy summarisation
and no live language list** — Translate silently returns the original text. Build with:

```bash
flutter build apk --release \
  --dart-define=APP_VERSION=1.0.0 \
  --dart-define=APP_BUILD_NUMBER=4 \
  --dart-define=TRANSLATE_PROXY_URL=http://<your-lan-ip>:8080/translate \
  --dart-define=SUMMARY_PROXY_URL=http://<your-lan-ip>:8080/summarize
```

Use your laptop's LAN IP, not `localhost` — `localhost` on a phone means the phone. And the
phone must be on the same Wi-Fi as the proxy.

If you want the no-API route instead, point `TRANSLATE_PROXY_URL` at the demo server's
`/api/translate` after the one-line request-shape fix in §9.1.

### 12.2 Deploy the missing index

`jobs (workerId, status, completedAt)` is declared but not live, so the admin Workers list
shows all 49 rows with no rank badges. Deploy all indexes at once:

```bash
firebase deploy --only firestore:indexes --project quickfix-fyp
```

### 12.3 Know your demo accounts

| Role | Email | Password |
|---|---|---|
| Admin | `admin@quickfix.test` | `Admin@123` |
| Client | `user@quickfix.test` | `User@123` |
| Worker | `worker@quickfix.test` | `Worker@123` |

All three are provisioned and verified. The 26 seeded clients and 49 seeded workers are
**data only** — they have no Auth accounts and cannot be logged into.

---

## 13. A demo script that cannot fail

Practise this order; each step has a visible result.

1. **Sign in as the client.** Post a job: category, budget, GPS pin, two photos.
2. **Sign in as the worker** (second phone, or sign out/in). The job appears in the board
   within a second — that is real-time, not a refresh.
3. Apply. **Back as the client**, the applicant appears; accept. Job goes `assigned`.
4. **Chat**: send a message and a shared location. It arrives live on the other device.
5. **As the worker**, mark the job complete.
6. **As the client**, pay (simulated) and write a review **in Urdu**.
7. Tap **Translate** — the review renders in English (needs the proxy define from §12.1).
8. Open the worker's profile: the **Overall summary** card (TF-IDF, works offline) and the
   **rank badge**.
9. **As the admin**: Overview counts → Reports (12 seeded) → resolve one with a note →
   Accounts → block the worker → try signing in as that worker and watch the suspension
   message.

Step 9 is the strongest part of the demo; it is entirely your own code and needs no
external service.

---

## 14. Questions you will be asked

**"Is this a real backend?"**
It is a managed backend (Firebase) plus one custom Node service. There is no application
server because Firestore and Auth provide the persistence, transport and identity layers.
The custom code is the proxy, the rules, the indexes and the seed tooling.

**"Why no REST API of your own?"**
Because a BaaS removes the need for CRUD endpoints. What a conventional API would do —
validate ownership, restrict fields, prevent privilege escalation — is done in 469 lines of
security rules, which are enforced server-side and tested against the emulator.

**"How do you prevent someone making themselves an admin?"**
The `users` create rule permits only `role in ['user','worker']`, the client cannot write
`role` at all, and `isAdmin()` is evaluated server-side from the stored document. An admin
can only be created through the Firebase console or the Admin SDK.

**"Where are the images stored?"**
On the device, in the app documents directory; only the path is in Firestore. Be ready to
say why (Storage needs the paid plan) and what it costs you (photos do not cross devices).

**"Does it scale to many users?"**
Firestore scales horizontally; the client holds no shared state; colliding writes use
transactions. What is missing is pagination, presence and push notifications.

**"What did you actually train?"**
Nothing yet — and say it plainly. The summariser is TF-IDF (no training needed), the
translation engine is statistical MT trained at startup on 44 sentences, and the production
path calls Google. Training the real models is the remaining work.

**"Why not use an off-the-shelf model?"**
If APIs are disallowed at inference time, a locally-executed pre-trained model is usually
still acceptable — that is a question to settle with your supervisor, not to guess at.

---

## 15. Honest limitations list

Keep this list; volunteering it is more credible than being caught.

1. Translation depends on an external API as shipped; the local engine covers 4 languages
   and 44 sentences.
2. No trained summarisation model — TF-IDF only.
3. Images are device-local; they do not sync between users.
4. No push notifications; the inbox updates only while the app is open.
5. No presence, no typing indicators.
6. Lists cap at 50 with no pagination.
7. Search is client-side over the loaded page.
8. Payments and payouts are simulated; no gateway.
9. Verification is a manual, self-declared process; admins cannot see the uploaded proof
   from another device (same image limitation).
10. Quotes feature exists but is switched off (`config/features.quotesEnabled = false`).
11. Admin mobile list enrichment covers the first 20 rows only.
12. One open index deployment (§12.2).
