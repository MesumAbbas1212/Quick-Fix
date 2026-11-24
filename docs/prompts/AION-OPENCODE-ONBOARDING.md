# QuickFix — onboarding brief for a new coding agent

> **Read this whole file before touching any code.** It exists so you do not have to
> rediscover the project by trial and error. Everything below was verified against the
> repository and the live Firebase project on **22 November 2026**.

---

## 1. What you are joining

**QuickFix** is a final-year project (BSE, COMSATS University Islamabad, Attock Campus) by
**Mesum Abbas** and **Ubaid Hassan**, supervised by Mr. Umar Zia.

It is an on-demand local-services marketplace for Pakistan: a client posts a job with
photos and a GPS location, nearby workers apply, the client hires one, they chat, the
worker completes the job, and the client leaves a review. Reviews are written in any
language and are machine-translated into the *viewer's* language, with an ML-generated
summary on every worker profile. Workers earn ranks from their completed-job volume.

It is a real, working system — not a prototype — and it has to survive a live demo on a
physical Android phone against the production Firebase project.

---

## 2. Where the code lives

| | |
|---|---|
| **GitHub** | https://github.com/MesumAbbas1212/Quick-Fix |
| **Branch to work on** | `arena/f4c30e79-quick-fix` — **not** `main`, not `master` |
| **Local clone (this machine)** | `C:\Users\MOON COMPUTERS\WorkBuddy AI\2026-10-18-16-18-16\quick-fix` |
| **Current HEAD** | `e1561c1` — *fix(admin): server-side role filter, resilient worker enrichment, report seeding* |

Start every session with:

```bash
cd "C:\Users\MOON COMPUTERS\WorkBuddy AI\2026-10-18-16-18-16\quick-fix"
git fetch origin arena/f4c30e79-quick-fix
git status --short
git log --oneline -5
```

If `git status` shows modified `mobile/linux/...`, `mobile/macos/...` or
`mobile/windows/...` files, those are build-generated noise — discard them:

```bash
git checkout -- mobile/linux mobile/macos mobile/windows
```

---

## 3. The end goal — read this before choosing any task

**The goal is a defensible demonstration, not more features.**

Concretely, when this project is finished, an examiner must be able to sit down and go
through this flow on the phone, start to finish, with no dead ends:

1. A **client** signs up, picks their language, and posts a job — title, category,
   description, photos, address, GPS pin, budget, preferred date.
2. **Workers** nearby see it, apply, and the client sees the applicants and hires one.
3. The two **chat**, share a live location, and the worker marks the job in progress and
   then complete.
4. The client **pays** (simulated) and leaves a **review in Urdu**. A viewer whose app
   language is English taps **Translate** and reads it in English. The worker's profile
   shows an **ML summary** of all their reviews.
5. The worker's **rank** (Apprentice → Grandmaster, 156 completions per year) updates from
   the completed jobs.
6. An **admin** moderates: sees the dashboard counts, works the report queue, resolves a
   report, blocks an account, approves a worker's verification, cancels a job.

And the technical report must describe **only what the code actually does**. A claim in
the report that the code does not support is a defect, not a marketing decision.

Anything that does not serve that flow is lower priority than something that does.

---

## 4. Current state (verified 22 November 2026)

### 4.1 Code

- `mobile/` — Flutter app, **61 files in `lib/views/`**, roughly 59 screens, split into
  `ClientShell` (Home / Workers / Messages / Profile), `WorkerShell` (Jobs / My Jobs /
  Messages / Profile) and `AdminShell` (Overview / Reports / Accounts / Catalog / Profile).
- `admin/` — React 19 + Vite + TypeScript moderation dashboard (14 pages).
- `backend/translation-proxy/` — Express + Google Cloud Translation (`/translate`,
  `/summarize`, `/languages`).
- `backend/seed/` — deterministic dataset generator, plus `seed-reports.js` for moderation
  fixtures and `create-accounts.js` for demo logins.
- `docs/firestore/` — `firestore.rules`, `firestore.indexes.json`, `storage.rules`,
  `schemas.md`.
- `validation/firestore/` — Firestore Rules emulator suite (needs Node ≥ 24 and Java 21).
- `.github/workflows/validate.yml` — CI: Flutter analyze + tests + coverage, rules
  emulator, proxy + seed contracts, admin tsc/lint/build.

### 4.2 Verification status

- `flutter analyze --no-pub` → **no issues**.
- `flutter test` → **908 passing**. Three tests in `test/local_image_store_test.dart`
  fail **only on Windows** (`errno 1314`, cannot create symlinks without Developer Mode);
  they pass on the Ubuntu CI runner. Do not "fix" them by deleting assertions.
- Backend seed tests → 10 passing.
- Coverage ≈ 81.7 %.

### 4.3 Live Firebase project `quickfix-fyp`

| | |
|---|---|
| Users | 77 — 26 `role: user`, 50 `role: worker`, 1 `role: admin` |
| Workers | 49 |
| Jobs | ~15 000 |
| Reports | 12 (7 open, 3 resolved, 2 dismissed) + 2 disputes |
| Admin login | `admin@quickfix.test` / `Admin@123` (uid `ct84PISHIHbjHkg71BC3NSZsBg13`) |
| Rules | **deployed** |
| Indexes | `users (role, createdAt)` **live**; `jobs (workerId, status, completedAt)` **NOT live** |

---

## 5. Toolchain on this machine

| Tool | Where | Note |
|---|---|---|
| Flutter 3.44.9 | `D:\flutter` | In Git Bash prefix every call: `env "ProgramFiles(x86)=C:\Program Files (x86)" flutter ...` or it fails with a `PROGRAMFILES(X86)` error |
| JDK 17 | `D:\jdk` (`JAVA_HOME`) | `java` on PATH is 1.8 — ignore it, Gradle uses `JAVA_HOME` |
| Android SDK | `D:\android-sdk` | platforms 34/35/36, build-tools, ndk, platform-tools |
| adb | `D:\android-sdk\platform-tools\adb.exe` | phone `mflrizqk6hvcvko7` when connected |
| Node | 22 (managed) | `npm` works |
| Firebase CLI | **not installed** | Use `npx firebase-tools`, or the Firebase console |
| Service-account key | `C:\Users\MOON COMPUTERS\Downloads\quickfix-fyp-firebase-adminsdk-fbsvc-8fc8ad9984.json` | **SECRET.** Never commit, never paste into a chat, never move it inside the repo |

Build and install:

```bash
cd mobile
env "ProgramFiles(x86)=C:\Program Files (x86)" flutter pub get
env "ProgramFiles(x86)=C:\Program Files (x86)" flutter build apk --release \
  --dart-define=APP_VERSION=1.0.0 --dart-define=APP_BUILD_NUMBER=3
"D:/android-sdk/platform-tools/adb.exe" install -r build/app/outputs/flutter-apk/app-release.apk
```

A cold Gradle build takes ~25 minutes; a warm one ~2 minutes. Release builds are signed
with the **debug** key, so installing over an APK built on another machine fails with
`INSTALL_FAILED_UPDATE_INCOMPATIBLE` — uninstall `com.quickfix.quickfix` first.

---

## 6. Architecture and conventions (binding)

The app deliberately has **no state-management library**. Do not add one.

```
views/     declarative UI only — never touches Firestore
  └─ services/   all Firestore and network I/O; maps documents to models
       └─ models/  immutable classes with toMap()/fromMap()
core/      theme tokens (app_theme.dart) + shared widgets
```

Rules that must hold:

1. **No `provider`, no Bloc, no Riverpod.** `StatefulWidget` + `StreamBuilder` +
   constructor injection. (`provider` is declared in `pubspec.yaml` and imported by zero
   files — that is intentional history, leave it.)
2. **Every service is constructor-injectable**:
   `late final XService _x = widget.xService ?? XService();` — this is what makes 900+
   widget tests possible without a Firebase emulator.
3. **Four states on every list**: loading, empty, error, data. A silent empty list is a bug.
4. **`AppTheme` tokens only** — zero inline hex. Card style: radius 20, `borderGray`
   border, 4 % black shadow, blur 8, offset (0,2).
5. **No new packages** without asking.
6. **Do not weaken security rules or delete test assertions** to make something pass.
7. **Views never create screens for other roles.** Admin UI lives in `views/admin/` and is
   reachable only through `AdminShell`, which re-verifies the role on resume and fails
   closed.

---

## 7. Traps that have already cost hours — do not repeat them

1. **Git cannot create a branch whose name contains a slash on this filesystem.**
   `git update-ref refs/heads/arena/...` silently no-ops, and `git clone --branch
   arena/...` leaves an unborn branch. Work around it with a slash-free local branch:
   ```bash
   git fetch origin arena/f4c30e79-quick-fix
   git checkout -B f4c30e79 FETCH_HEAD
   ```
   and push with `git push origin HEAD:arena/f4c30e79-quick-fix`.
2. **After any checkout, run `flutter pub get`.** Without it, `flutter analyze` reports
   ~30 000 phantom errors from a stale package config. It is not a code problem.
3. **Firestore `orderBy` silently drops documents missing that field.** A profile created
   by hand in the console without `createdAt` is invisible to every ordered query.
4. **`limit()` before a client-side filter is a data-loss bug.** The admin Users list had
   exactly this: it fetched the 50 newest accounts (49 workers + 1 client), then filtered to
   `role == 'user'` and showed one row. Filter on the server.
5. **A missing composite index surfaces as an empty or erroring list**, not as an obvious
   failure. `firestore.indexes.json` is the source of truth; deploying it is an operator
   step and indexes take minutes to build.
6. **The live project and the repo can drift.** Always verify against the live project
   before claiming a screen works.

---

## 8. What is actually left (in priority order)

1. **Create the missing `jobs` index** — until it exists, the admin Workers list shows all
   49 rows but with no rank badges (the count query is caught and skipped). One-click:
   ```
   https://console.firebase.google.com/v1/r/project/quickfix-fyp/firestore/indexes?create_composite=Cklwcm9qZWN0cy9xdWlja2ZpeC1meXAvZGF0YWJhc2VzLyhkZWZhdWx0KS9jb2xsZWN0aW9uR3JvdXBzL2pvYnMvaW5kZXhlcy9fEAEaCgoGc3RhdHVzEAEaDAoId29ya2VySWQQARoPCgtjb21wbGV0ZWRBdBABGgwKCF9fbmFtZV9fEAE
   ```
   or deploy every index at once with `npx firebase-tools deploy --only
   firestore:indexes --project quickfix-fyp` (needs `firebase login`).
2. **Live translation quality.** The proxy has never been run with a real
   `GOOGLE_TRANSLATE_API_KEY`. Verify a held-out set of Urdu/Punjabi/Pashto/Sindhi
   sentences and record honest adequacy numbers. The bundled demo corpus is 44 sentences —
   it is a demonstration, not a production translator, and no claim should imply otherwise.
3. **On-device pass** on a real phone: camera capture (portfolio, verification, job
   photos), GPS permission flows including deny-forever → settings deep link, maps deep
   links, keyboard behaviour in forms, and cold-start persistence of local images.
4. **Manual visual / RTL / accessibility review** at 320 px width and text scale 2.0, with
   long Urdu content. Some of this is already covered by widget tests; the rest needs eyes.
5. **Optional polish**: a web `appId` for the React dashboard (`admin/.env`,
   `VITE_FIREBASE_APP_ID`), and spreading the seeded reports across more workers.

**Gated — do not do these without explicit approval from the owner:**
deploying rules to production, running the live seed, enabling quotes
(`config/features.quotesEnabled` must stay `false`), or any release/publishing step.

---

## 9. Where the detail lives

Read these before writing code in the relevant area:

| File | What it covers |
|---|---|
| `QuickFix-Technical-Report.md` | The authoritative record: architecture, schemas, ML design, and §12–§14 validation history |
| `README.md` | Setup, seeding, provisioning an admin account, build commands |
| `docs/firestore/schemas.md` | Every collection and field |
| `docs/firestore/firestore.rules` | The real access model — read it before assuming a permission |
| `docs/prompts/ADMIN-ACCESS.md` | The brief that produced the mobile admin shell |
| `docs/prompts/ADMIN-LIST-FIX.md` | The brief that fixed the account lists and added report seeding |
| `validation/firestore/README.md` | How to run the Rules emulator |

Note: `docs/prompts/` is **untracked** — it exists only in this local clone.

---

## 10. How to work

1. Read the relevant section of the technical report **and** the actual code before
   proposing a change. The report is accurate as of `e1561c1`; older claims were corrected
   in a documentation truth pass.
2. Prefer the smallest change that makes the flow work. This project is close to done;
   regression risk is the main enemy.
3. Verify before you claim:
   - `flutter analyze --no-pub` must be clean.
   - `flutter test` must not regress (908 passing baseline; 3 Windows-only symlink failures
     are expected).
   - For anything touching data, check the live project, not just the code.
4. Commit in small, conventional commits (`feat(admin): …`, `fix(auth): …`, `docs: …`), and
   say in the message what you verified.
5. When you finish a batch, report: files changed, checks actually run with numbers, what
   you could not verify and why, and anything you deliberately left gated.

**Never report a task as done if you only changed code and did not run anything.** "Written,
not verified" is a useful answer; "done" when it is not is not.

---

## 11. First response expected from you

Before writing code, reply with:

1. The branch and HEAD you actually see after `git fetch` / `git status`.
2. A one-paragraph summary of the end-to-end flow from §3, in your own words.
3. The three remaining items you think matter most, and why.
4. Anything in this brief that contradicts what you find in the repository.

Then wait for direction, or proceed with item 1 of §8 if you are told to start.
