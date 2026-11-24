# QuickFix — Defense Preparation Pack

**For the supervisor meeting / final evaluation.** Written to be read the night before, then
spoken from. Every command, path and number here was verified against the repository and the
live Firebase project on **24 November 2026**.

Read §1, §2 and §5 twice. Those are the three things you will actually be asked to do:
set up the room, explain how the app is built, and walk the scenario.

---

## 1. Room setup — what to open, in what order

### Bring

| Item | Why |
|---|---|
| Laptop, charged | Codebase + Firebase console + this document |
| Phone, charged, with the app installed and **already signed in once** | Demo |
| USB cable | Only if something needs reinstalling mid-demo |
| Phone hotspot or a reliable Wi-Fi | The app is useless offline beyond cached screens |
| A second account on the phone (or a second phone) | Chat needs two people to look convincing |

### Laptop — open these four windows before he walks in

1. **VS Code / Android Studio** with the repo open at
   `C:\Users\MOON COMPUTERS\WorkBuddy AI\2026-10-18-16-18-16\quick-fix`
2. **Firebase console**, project `quickfix-fyp`, on the **Firestore → Data** tab
3. **Firebase console**, second tab on **Authentication → Users**
4. **A terminal** in `quick-fix\mobile`, so you can show `flutter build apk` if asked

Keep the dossier (`docs/EVALUATION-DOSSIER.md`) and this file open in a third tab.

### Phone — before he walks in

- App installed (build 6), **signed in as the client**, sitting on the home screen
- Location permission **already granted** (asking during the demo wastes a minute)
- Brightness up, notifications silenced
- Know the three logins by heart:

| Role | Email | Password |
|---|---|---|
| Client | `user@quickfix.test` | `User@123` |
| Worker | `worker@quickfix.test` | `Worker@123` |
| Admin | `admin@quickfix.test` | `Admin@123` |

---

## 2. "How did you build the app and install it?"

This is the most common opening question, and it has a precise answer. Say it in this order.

### 2.1 The toolchain

| Piece | Version | What it does |
|---|---|---|
| Flutter SDK | 3.44.9 | Compiles Dart and bundles the Flutter engine |
| Dart | 3.12.2 | The language the app is written in |
| Android SDK | platforms 34/35/36 | Compiles the Android shell around the Flutter code |
| Gradle | 9.1 | Android's build system — assembles and signs the APK |
| JDK | 17 (Temurin) | Runs Gradle |
| Firebase SDKs | `firebase_core`, `firebase_auth`, `cloud_firestore` | Talk to the backend |

**Say this:** *"It's a Flutter app, so one Dart codebase produces the Android build. Flutter
compiles the Dart ahead-of-time into native ARM code, and Gradle wraps that in an Android
package."*

### 2.2 The build, line by line

```bash
cd quick-fix\mobile
flutter pub get
flutter build apk --release --dart-define=APP_VERSION=1.0.0 --dart-define=APP_BUILD_NUMBER=6
```

What each line actually does — be ready for "what does that do?":

| Command | What happens |
|---|---|
| `flutter pub get` | Reads `pubspec.yaml`, downloads the declared packages (Firebase, geolocator, image_picker…), writes `.dart_tool/package_config.json` so imports resolve |
| `flutter build apk --release` | Compiles Dart **ahead of time** to ARM machine code (`libapp.so`), tree-shakes icons and fonts, then hands off to Gradle |
| Gradle `assembleRelease` | Merges native libraries for each CPU architecture, packages assets, applies `google-services.json`, and **signs** the APK |
| `--dart-define=...` | Injects compile-time constants into the Dart code — used for the version string shown in Settings and the ML proxy URLs |

Output:

```
build\app\outputs\flutter-apk\app-release.apk    ~60 MB
```

First build on a clean machine takes 25–30 minutes (Gradle downloads its dependencies).
Subsequent builds take about two minutes. **Say that** — it explains why you don't rebuild live.

### 2.3 What is inside the APK

If he asks "what's actually in there?":

| Component | Purpose |
|---|---|
| `lib/arm64-v8a/libapp.so` | Your Dart code, compiled to native ARM |
| `lib/arm64-v8a/libflutter.so` | The Flutter engine (rendering, Dart runtime) |
| `assets/flutter_assets/` | Fonts, images, the Dart asset manifest |
| `AndroidManifest.xml` | Permissions: INTERNET, camera, location, notifications |
| `res/values/strings.xml` | Generated from `google-services.json` — the Firebase project id, API key, app id |
| `classes.dex` | The small Android/Java shell that boots Flutter |
| `META-INF/*.RSA` | The signature |

**The key sentence:** *"`google-services.json` isn't read at runtime — the Google Services
Gradle plugin converts it into Android string resources at build time, and
`Firebase.initializeApp()` reads those resources when the app starts."*

That is exactly what `main.dart` does:

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('en');
  await Firebase.initializeApp();   // reads the generated resources
  runApp(const QuickFixApp());
}
```

### 2.4 Signing — and why yours says "debug"

Android refuses to install an APK that isn't signed. `android/app/build.gradle.kts` says:

```kotlin
release {
    // TODO: Add your own signing config for the release build.
    signingConfig = signingConfigs.getByName("debug")
}
```

So the release build is signed with the **debug keystore** (`~/.android/debug.keystore`),
which Flutter generates automatically.

**Be honest about this if asked:** *"It's signed with the debug key because we're distributing
internally, not through Play Store. For Play Store we'd generate a release keystore, keep it
out of git, and configure `signingConfigs.release`."*

Practical consequence to know: an APK signed with a **different** debug key cannot install over
yours. If a teammate gets `INSTALL_FAILED_UPDATE_INCOMPATIBLE`, they uninstall first.

### 2.5 Three ways to install

| Method | Command / action | When to use |
|---|---|---|
| **adb** | `adb install -r build\app\outputs\flutter-apk\app-release.apk` | Phone plugged in, USB debugging on |
| **flutter** | `flutter install` | Same, but Flutter picks the device |
| **Manual** | Copy the APK to the phone (USB, WhatsApp, Drive), tap it, allow "Install unknown apps" | Sending to a group member |

`-r` means "replace an existing install, keep the data".

### 2.6 Building the installer for someone else

You already have it:

```
quick-fix\dist\QuickFix-1.0.0-build6.apk        61 MB
SHA-256 179d4815a70c1676a5dc9b9d7cd801d2d42cd518f8bbb416dd08ffd78c7a77e9
```

Send the file plus the hash, so they can verify it arrived intact. Tell them two things up
front, or they'll report them as bugs:

- Uninstall any older QuickFix first (different signature).
- **Translate will not work** on their phone: it needs the translation proxy running on your
  laptop, and the APK was built without the proxy URL. It returns the original text by design.

### 2.7 If the build fails in front of him

| Symptom | Cause | Fix |
|---|---|---|
| `There is not enough space on the disk` | C: is nearly full | Free space, or build on another drive |
| `INSTALL_FAILED_UPDATE_INCOMPATIBLE` | Different signing key | `adb uninstall com.quickfix.quickfix` |
| `flutter: command not found` | PATH | Use the full path, or reopen the terminal |
| Gradle "Unsupported class file major version" | Wrong JDK | Point `JAVA_HOME` at JDK 17 |
| Analyzer reports ~30 000 errors | Stale package config | `flutter pub get` |

---

## 3. Firebase — everything you're using, and why

### 3.1 The project

| | |
|---|---|
| Project id | `quickfix-fyp` |
| Android app id | `1:683569535486:android:bf3986152c45ec8df288af` |
| Package | `com.quickfix.quickfix` |
| Config file | `mobile/android/app/google-services.json` (committed — it's not a secret) |

**Say this:** *"Firebase is our backend-as-a-service. We don't run a server for the app — the
phone talks to Firebase directly, and Firebase enforces our security rules."*

### 3.2 Authentication

**What it does here:** creates accounts, verifies passwords, and issues the identity token that
every database request carries.

- Method: **email + password** only
- `services/auth_service.dart` wraps it: register, sign in, sign out, password reset,
  delete account, profile read
- Passwords never touch our code — Firebase stores salted hashes
- The SDK persists the session, so the app doesn't ask for a password on every launch
- Every request to Firestore carries a short-lived **ID token**; the rules read
  `request.auth.uid` from it

**What to show in the console:** Authentication → Users. Point out that the password column is
not visible even to you — that's the point.

### 3.3 Cloud Firestore — the database

**What it does here:** stores every document the app uses, and **pushes changes to the phone in
real time**.

- 18 top-level collections:

```
users  workers  jobs  jobRequests  conversations  reviews  payments  payouts
disputes  notifications  reports  categories  languages  workerVerifications
quoteRequests  quotes  accountDeletions  config
```

- Subcollections carry private data so it never sits on a public document:
  `users/{uid}/private/addressBook`, `workers/{uid}/private/payout`,
  `jobs/{id}/private/location`, `conversations/{id}/messages`
- **Realtime:** 35 places in the app use `snapshots()`. When a document changes, Firestore
  pushes the new result and the widget rebuilds — no refresh button, no polling
- **Offline:** Firestore keeps a local cache; previously loaded screens still render without a
  connection, and queued writes flush on reconnect
- **Transactions:** used where two documents must change together — resolving a report plus
  its dispute, submitting a review plus the worker's rating, accepting a quote

**What to show:** Firestore → Data. Open `jobs` and point at `status`, `userId`, `workerId`;
open `conversations` and show the messages subcollection.

### 3.4 Security Rules — the authorisation layer

**This is the most impressive part of the project. Lead with it.**

- 469 lines in `docs/firestore/firestore.rules`
- Every read and write is checked **on Google's servers**, not in the app
- The central idea: the client is untrusted, so permission is decided by data

Examples worth quoting:

```js
// Who is an admin? Read from the database, not from the app.
function isAdmin() {
  return signedIn() && exists(/databases/$(database)/documents/users/$(request.auth.uid))
    && get(...).data.get('role', 'user') == 'admin';
}

// Nobody can make themselves an admin:
allow create: if ... request.resource.data.role in ['user', 'worker']
```

- Users can edit their own profile but **not** `role`, `blocked`, `approved`
- A conversation is readable only by its two participants
- A blocked account cannot post jobs, send messages, or leave reviews (`notBlocked()`)
- 26 emulator tests in `validation/firestore/` prove these boundaries

**What to show:** Firestore → Rules tab. Scroll to `match /users/{uid}` and read the `create`
line aloud — that's the anti-privilege-escalation guarantee.

### 3.5 Indexes

28 composite indexes in `docs/firestore/firestore.indexes.json`, e.g.
`jobs: status + createdAt` (the job board) and `users: role + createdAt` (the admin list).

**Say this:** *"Firestore can't run a filtered + sorted query without a composite index, so we
declare them in the repo and deploy them — they're part of the schema, not a console
afterthought."*

### 3.6 What you do **not** use — say it before he asks

| Service | Status | Why |
|---|---|---|
| Cloud Storage | **Not used** | Needs the paid Blaze plan; images are stored on the device instead (see §8) |
| Cloud Functions | Not used | No server-side logic beyond the rules; ML runs in our own Node proxy |
| Hosting | Not used | Admin dashboard runs locally; could be hosted |
| Cloud Messaging | Not used | In-app notifications only, no push |
| Analytics / Crashlytics | Not used | Out of scope |

Being upfront about this is stronger than being caught.

### 3.7 The path a request takes

Good answer for "how does the phone actually talk to the database?":

1. `Firebase.initializeApp()` reads the config baked in from `google-services.json`
2. The SDK opens a persistent HTTPS/WebSocket channel to Firestore
3. Each request carries the user's **ID token**
4. Firestore evaluates the **security rules** against that token and the document
5. If allowed, the write is applied and **pushed to every listening client**
6. If denied, the client receives `permission-denied` — which is exactly the error we chased
   in the chat bug

---

## 4. Functional requirements → implementation → demo

Use this table to answer "show me where that happens". Each row is a requirement you can
demonstrate in under a minute.

| ID | Requirement | Where it lives | How to demo |
|---|---|---|---|
| **FR-01** | Register / sign in as client or worker | `views/auth/signup_screen.dart`, `login_screen.dart`, `services/auth_service.dart` | Sign out, sign in as worker |
| **FR-02** | Choose the language used for translated reviews | `views/settings/language_picker_screen.dart`, `services/language_service.dart` | Settings → Language |
| **FR-03** | Post a job with photos, GPS pin, budget, date | `views/jobs/post_job_screen.dart`, `services/job_service.dart`, `services/local_image_store.dart` | Post a job; show it in Firestore with `status: open` |
| **FR-04** | Browse, search and filter workers | `views/client/workers_screen.dart`, `search_filter_screen.dart`, `services/worker_filter_service.dart` | Search a trade, apply a filter |
| **FR-05** | Worker profile: rating, reviews, portfolio, rank, verification | `views/client/worker_detail_screen.dart`, `worker_reviews.dart`, `views/worker/portfolio_screen.dart`, `models/worker_rank.dart` | Open a worker |
| **FR-06** | Workers see only jobs matching their professions | `views/jobs/worker_dashboard_screen.dart` (`_professionFiltered`), `services/job_service.dart` | Sign in as worker; toggle "All jobs" |
| **FR-07** | Worker applies; client hires | `services/job_request_service.dart`, `views/jobs/job_applicants_screen.dart` | Apply as worker, accept as client |
| **FR-08** | Chat, including sharing a live location | `views/chat/chat_screen.dart`, `services/chat_service.dart` | Send a message and a pin |
| **FR-09** | Job lifecycle: assigned → in progress → completed | `services/job_service.dart`, `views/jobs/job_tracking_screen.dart`, `models/job_model.dart` | Worker marks complete |
| **FR-10** | Simulated payment | `views/payments/payment_screen.dart`, `services/payment_service.dart` | Pay after completion |
| **FR-11** | Review with translation | `views/reviews/review_screen.dart`, `services/review_service.dart`, `services/translation_service.dart`, `core/widgets/review_list_tile.dart` | Write an Urdu review, tap Translate |
| **FR-12** | Automatic summary of a worker's reviews | `services/summary_service.dart` (TF-IDF, on-device) | Open the worker's profile → Overall summary |
| **FR-13** | Worker rank from yearly completions | `models/worker_rank.dart` (156 per step), `services/performance_service.dart` | Open Rank progress |
| **FR-14** | In-app notifications | `services/notification_service.dart`, `views/notifications/notifications_screen.dart` | Bell icon after a hire |
| **FR-15** | Admin moderation: accounts, jobs, reports, catalogue | `views/admin/*` (8 screens), `services/admin_service.dart`, `admin_catalog_service.dart` | Sign in as admin |
| **FR-16** | Account deletion | `views/settings/delete_account_screen.dart`, `services/account_deletion_service.dart` | Settings → Delete account (don't complete it live) |
| **FR-17** | Works on a poor connection | `services/network_status_service.dart`, `core/widgets/offline_banner.dart`, Firestore cache | Turn on airplane mode on a loaded screen |

---

## 5. The scenario — narrate it like a story

This is the demo. Each step lists **what you do**, **what happens in the database**, and **what
you say**. Keep the Firestore tab open on the laptop so he can watch documents change.

### Step 1 — The client posts a job

**Do:** Sign in as `user@quickfix.test`. Home → Post a job. Category *Plumbing*, description,
two photos, pick the address on the map, budget 1500–3000, date tomorrow. Submit.

**In Firestore:** a new document in `jobs` with
`userId`, `category: plumbing`, `status: open`, `images: [path, path]`, `location: GeoPoint`,
`budgetMin/Max`, `createdAt`.

**Say:** *"The photos never leave the phone — we store the local file path, because Firebase
Storage needs a paid plan. The job document itself is what every worker will see."*

### Step 2 — A nearby worker sees it, in real time

**Do:** On the second phone (or after signing out) sign in as `worker@quickfix.test`. The job
appears on the board within a second.

**In Firestore:** nothing new — the worker's app is **listening** to
`jobs where status == 'open'`. Firestore pushed the new document to it.

**Say:** *"Nobody refreshed anything. That's a Firestore snapshot listener — 35 of them across
the app."*

Also point out the board is filtered to the worker's professions; tap **All jobs** to show the
toggle.

### Step 3 — Apply, then hire

**Do:** As the worker, tap **Apply**. As the client, open the job → applicants → **Accept**.

**In Firestore:** a `jobRequests` document with `status: pending`, then `accepted`; the job's
`workerId` is set and `status` becomes `assigned`.

**Say:** *"Two documents change, so the write is guarded by the rules — a worker can't assign
themselves to a job, and a client can't accept a request that isn't theirs."*

### Step 4 — Chat

**Do:** Open the chat from the job. Send "I'll be there at 10". Share location.

**In Firestore:** `conversations/{sortedPair}` with `lastMessage`, `unreadCount`; each message
in the `messages` subcollection.

**Say:** *"Only those two uids can read this thread — that's a rule, not a filter in the UI."*

**If it fails**, don't debug live. Say: *"We hit a rules bug here last week — the app was
rewriting the conversation's participants on every message, which the update rule rejects.
Fixed by writing participants only when the conversation is created."* That answer is stronger
than a working demo, because it shows you understand the layer.

### Step 5 — Complete the job

**Do:** As the worker, **Start job**, then **Mark complete**.

**In Firestore:** `status: inProgress` → `completed`, `completedAt` set.

### Step 6 — Pay

**Do:** As the client, pay. (Simulated.)

**In Firestore:** a `payments` document linked to the job.

**Say:** *"Payment is simulated — there's no gateway. The record and the flow are real; the
money isn't."*

### Step 7 — Review, in Urdu

**Do:** As the client, leave 5 stars and an Urdu review.

**In Firestore:** a `reviews` document with `originalText`, `originalLang: 'und'`, rating; and
the worker's `rating` / `reviews` count updated in the same batch.

**Say:** *"The review is stored in the language it was written. Translation happens on demand,
not at write time, so nothing is lost."*

### Step 8 — Translate

**Do:** Tap **Translate**.

**Say:** *"The phone calls our own Node proxy, which holds the API key server-side — the key
never ships in the APK. If the proxy isn't running, we show the original text rather than a
fake translation."*

**Important:** translation only works if the APK was built with `TRANSLATE_PROXY_URL` and the
proxy is running. If it isn't, say so plainly — see §8.

### Step 9 — The summary

**Do:** Open the worker's profile → **Overall summary**.

**Say:** *"This one needs no server and no API. It's TF-IDF extractive summarisation running on
the phone: sentence scoring by term frequency × inverse document frequency, weighted by a
sentiment lexicon, then one or two sentences chosen. It works in airplane mode."*

This is a genuinely defensible ML component — present it confidently.

### Step 10 — Rank

**Do:** Worker profile → Rank progress.

**Say:** *"One rank step per 156 completed jobs in a rolling year — Apprentice, Journeyman,
Expert, Master, Grandmaster. It counts completions in the last 365 days, not lifetime, so a
worker has to stay active."*

### Step 11 — Admin moderation

**Do:** Sign in as `admin@quickfix.test`. Overview → Reports → open one → resolve with a note.
Then Accounts → block a worker.

**Say:** *"The admin role is provisioned out of band — there's no sign-up option and the rules
forbid the client writing `role: admin`. Resolving a report updates the report and its linked
dispute in one transaction."*

### Step 12 — Prove the block is real

**Do:** Sign in as the blocked worker. You get "This account has been suspended."

**Say:** *"That check runs at sign-in against the server copy of the profile, not the cache, so
it can't be bypassed by being offline."*

---

## 6. Codebase tour — for the laptop

### 6.1 The shape

```
mobile/lib/
├── main.dart          Firebase init, then runApp
├── app.dart           MaterialApp, theme, home
├── views/             72 screen files, grouped by area
├── services/          38 services — all Firestore and network I/O
├── models/            33 models — fromMap / toMap
└── core/              theme, shared widgets, utils
```

### 6.2 The pattern to explain

**Say this:** *"Views never touch Firestore. Every screen takes an optional service and
defaults to a real one — `widget.jobService ?? JobService()`. That's what lets us run 943
widget tests without a database."*

That one sentence explains the architecture, the testing strategy, and why the code is
testable — three answers in one.

### 6.3 If he says "show me the code for X"

| He asks about | Open |
|---|---|
| Login / auth | `services/auth_service.dart`, `views/auth/login_screen.dart` |
| Posting a job | `views/jobs/post_job_screen.dart`, `services/job_service.dart` |
| Realtime | `services/job_service.dart` — any `snapshots()` |
| Chat | `services/chat_service.dart` (the transaction in `sendMessage`) |
| Translation | `services/translation_service.dart` |
| Summary | `services/summary_service.dart` (TF-IDF, bottom half) |
| Rank | `models/worker_rank.dart` |
| Security | `docs/firestore/firestore.rules` |
| Admin | `views/admin/admin_shell.dart` and the 8 screens beside it |
| Tests | `mobile/test/` — 125 files |

---

## 7. Questions he will ask, with answers

**"Why no backend server?"**
*"Firebase is the backend. What a server would normally do — authenticate, validate, authorise
— is done by Firebase Auth and 469 lines of security rules, enforced on Google's servers. The
only server we wrote is the translation proxy, because an API key can't live in an APK."*

**"How do you stop someone becoming an admin?"**
*"The `users` create rule only allows `role in ['user','worker']`. The client cannot write
`role` at all. `isAdmin()` is evaluated server-side from the stored document. Admins are
provisioned through the console or a script with a service account."*

**"Where are the images stored?"**
*"On the device, in the app's documents directory. Firestore stores the path. Storage needs the
paid plan, so we deliberately deferred it — the cost is that a photo doesn't cross devices."*

**"How many users can it handle?"**
*"Firestore scales horizontally and the client holds no shared state. Colliding writes use
transactions. What we haven't built is pagination, presence, and push notifications."*

**"What did you actually train?"**
*"Nothing yet, and I'd rather say that plainly. The summariser is TF-IDF, which needs no
training. The translation engine is statistical MT trained at startup on a small corpus. The
production path calls Google Translate through our proxy. Training a real model is the
remaining work."*

**"How do you know it works?"**
*"943 automated tests, roughly 81 % line coverage, plus 26 rules-emulator tests that prove a stranger
can't read your messages or promote themselves."*

**"What's the weakest part?"**
*"Images don't sync between users, and the ML isn't trained. Both are in our report as
limitations, not hidden."*

**"How would you deploy this for real?"**
*"Release keystore for signing, Storage on Blaze for images, the proxy on Cloud Run, and the
admin dashboard on Hosting."*

**"Why Flutter?"**
*"One codebase, and the widget testing story — 943 tests without a device. The trade-off is
APK size, around 60 MB."*

---

## 8. What is not finished — say it before he finds it

| Gap | Honest framing |
|---|---|
| Images are device-local | Storage needs the paid plan; the interface is isolated in one service, so switching is a day's work |
| Translation needs a proxy + API | If APIs are disallowed, the local engine in `docs/demo/` is the compliant path, but its corpus is 44 sentences |
| No trained ML model | Summariser is classical TF-IDF; that's a method, not a trained model |
| No push notifications | In-app inbox only, updates while the app is open |
| No pagination | Lists cap at 50 |
| Payments are simulated | No gateway |
| Quotes feature exists but is switched off | `config/features.quotesEnabled = false` |

---

## 9. Failure drills

| If this happens | Do this | Say this |
|---|---|---|
| No internet | Turn on hotspot | "Everything except writes is cached; let me reconnect." |
| Chat says permission denied | Skip it | "We fixed a rules bug here last week — the conversation update was rewriting participants. It's committed; the installed build predates it." |
| Translate does nothing | Skip it | "Translation needs the proxy running with the API key; the key is deliberately not in the APK." |
| App won't install | `adb uninstall com.quickfix.quickfix` then install | "Signature mismatch from an earlier build." |
| Firebase console shows no data | Check the project selector says `quickfix-fyp` | — |
| Build takes forever | Don't build live | "First build is 25 minutes because Gradle downloads its dependencies; the APK is already built." |

---

## 10. The one-paragraph summary to memorise

*"QuickFix is a Flutter app with Firebase as its backend. A client posts a job with photos and
a GPS pin; workers whose professions match see it instantly through a Firestore snapshot; they
apply, the client hires, they chat, the worker completes it, and the client reviews it in any
language — the review is translated for the reader and summarised on the worker's profile.
Security is enforced by 469 lines of Firestore rules, not by the app. 943 automated tests cover
the behaviour, and the parts that aren't finished — cloud image storage and trained ML models —
are documented as limitations rather than hidden."*
