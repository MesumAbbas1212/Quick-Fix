# QuickFix — An On-Demand Local Service Matching Platform

Final Year Project (BSE, COMSATS University Islamabad, Attock Campus) by **Mesum Abbas** (CIIT/FA23-BSE-048/ATK) and **Ubaid Hassan** (CIIT/FA23-BSE-026/ATK), supervised by Mr. Umar Zia.

QuickFix connects users with skilled local workers (plumbing, electrical, furniture repair, cleaning, and more) through image-based job posting, AI category suggestions, skill/location-based matching, real-time chat, and a multilingual smart review system.

## Folder Overview

- `mobile/` — Flutter (Android) app with User and Worker roles
- `admin/` — React + Vite + TypeScript web dashboard for moderation and analytics
- `docs/design/` — exported screen designs (HTML mockups)
- `docs/firestore/` — Firestore security rules and indexes
- `backend/` — seed data and server-side helpers

## Tech Stack

Flutter · Firebase (Auth, Firestore, Storage) · Google ML Kit · Google Cloud Translation · React · Vite

## Features

- **Worker profiles with full work history** — a client tapping a worker sees every job they have completed (title, category, date, budget, rating) in a live "Work History" section.
- **Worker rank system** — workers earn a rank from the jobs they complete within the trailing 12 months; each rank step is **156 completions per year**, so the ladder is **Apprentice (0) → Journeyman (156) → Expert (312) → Master (468) → Grandmaster (624)**. Each rank has a proper vector emblem badge (shield / hexagon / star / diamond / crown, drawn per tier) shown on the worker's public profile and the worker's own profile, with progress toward the next rank.
- **App language at sign-up** — during sign-up the app asks which language the user wants the app to show and the user picks from the available options. The choice is stored on the user profile (`preferredLanguage`) and can be changed later from Profile → App Language.
- **Reviews in any language, translated on demand** — reviews keep their original language; when a viewer taps **Translate** under a review, it is translated into *the viewer's app language* (e.g. an Urdu viewer reading an English review). Translations are cached per language on the review.
- **Not hard-coded multilingualism** — the list of selectable languages is data-driven: it comes from the admin-managed `languages` collection in Firestore, merged with the translation proxy's `GET /languages` (the languages the backend translation engine actually supports). Adding a language there makes it appear in the app without a code change or app release.
- **ML-powered review understanding** — translation is machine learning, not a static dictionary: in production the app calls the translation proxy (`backend/translation-proxy`, neural MT via Google Cloud Translation); a zero-dependency statistical MT implementation (word Bayes model + phrase table + translation memory, trained at startup from a parallel corpus) is included in the demo. Reviews are also summarized with an extractive TF-IDF summarizer into 1 paragraph (≤ 4 reviews) or 2 paragraphs (more), shown as an "Overall summary" card above the review list, in the viewer's app language.

## Interactive Demo (no account needed)

A self-contained, zero-dependency walkthrough of all the features above — ML translation, ML summarization, rank emblems with 156/yr thresholds, work history, review writing, chat, language management:

```
node docs/demo/server.js   # -> http://localhost:8090
```

## Seeding Firebase with full Pakistan data

The seed script creates a realistic dataset so the app has data to show:
**49 workers across every province (9 in Attock district, covering all five
rank tiers)**, each pinned to a rank by its completed jobs in the trailing
12 months (Apprentice 0 / Journeyman 156 / Expert 312 / Master 468 /
Grandmaster 624), **100–140 reviews per worker in the languages spoken
across Pakistan** (Urdu, English, Punjabi, Pashto, Sindhi, Balochi, Saraiki,
Hindko, Hindi, Arabic, Persian, Bengali — each with a cached English
translation), plus ~15,000 completed jobs, open jobs, client users and
conversations.

```sh
node backend/seed/seed.js --dry-run
node --test backend/seed/test/*.test.js
```

Default execution is a credential-free dry run. Each worker is guaranteed every
language in the configured review corpus and at least 100 reviews; this does not
claim exhaustive coverage of every Pakistani language/dialect. Add authentic,
reviewed corpus data via `SEED_REVIEW_CORPUS`, not fake language substitutions.
Balochi uses ISO `bal` (not the distinct Brahui code `brh`).

- `REVIEWS_PER_WORKER=115` sets a count (clamped to at least 100).
- `JOBS_SCALE=0.3` adjusts fixture volume within real 156/year rank boundaries.
- Broad `CLEAN=1` collection deletion is **disabled**, not a safe migration.
- A reviewed live write needs the explicit `--write` option and the operator's
  own configured credentials. No credentials belong in the repo or chat.
- The default plan estimates about 24,319 writes and may exceed a free-tier daily
  quota. Inspect the actual audit; do not assume it fits a daily allowance.

See `backend/seed/README.md` for safe operation, corpus format and limitations.
No live Firebase seed or real Auth accounts/payments are created by validation.

## Implementation Plan

See `QuickFix-Implementation-Plan.md` in this folder for the full task-by-task plan.


### Screen-source completion checkpoint and subsequent validation (19 October 2026)

The complete build brief's target screen files are present, including B2
comparison (omitted by its order table). The initial source checkpoint had not
run Flutter; the subsequent hosted validation pass now runs the real toolchain:
715 Flutter tests pass, Flutter analysis is clean, line coverage is 81.89%,
24 official Rules-emulator regressions pass, 14 proxy/seed tests pass, and admin
TypeScript/lint/build checks pass. See the current CI run and
`QuickFix-Technical-Report.md` §14 for executed evidence and coverage, not the old
source-only counts. Native device/manual visual checks, live provider quality and
operator-approved deployment/data migration are still separate requirements.
Do not deploy Rules or enable gated features merely because these regressions pass.

- Quote requests default OFF: the app and Rules require the admin-owned
  `config/features.quotesEnabled` flag. Do not activate it until A1–A4 and the quote
  workflow/Rules validation pass. No config activation is included here.
- Payouts/payments are simulated only. Device-local photos are not uploads, and
  certificate/identity displays are not automated professional verification.
- Configure `--dart-define=SUPPORT_EMAIL=<operator email>` to enable Help's email
  intent; no fake support address is shipped. Keep `APP_VERSION` (default 1.0.0)
  and `APP_BUILD_NUMBER` aligned with pubspec/`--build-number` for each release.
- New address-book and payout references are owner/admin-private. Review/migrate
  any imported public sensitive fields before release. Account cleanup/retention
  limits are explicit; there is no automatic safety-record/tombstone expiry.


Automated validation evidence (Flutter 3.44.9 / Dart 3.12.2, Node 24, Java 21):
https://github.com/MesumAbbas1212/Quick-Fix/actions/runs/39232533612

Run all CI jobs through `.github/workflows/validate.yml`; local Rules tests need
Node >=24.12 and Java 21 (`validation/firestore/README.md`). The initial masked
tee result was rejected and corrected with pipefail plus independent machine-
completion checks. No failed tests were skipped or assertions dropped for green.
Admin's large-bundle warning remains a performance follow-up; native camera/GPS,
manual visual/RTL/accessibility and live ML language quality still require testing.
