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

```
cd backend/seed
npm install firebase-admin
GOOGLE_APPLICATION_CREDENTIALS=path/to/service-account.json node seed.js
```

Options:
- `CLEAN=1 node seed.js` — deletes the seeded collections first (clean re-seed)
- `REVIEWS_PER_WORKER=40` — fixed review count per worker (default: 100–140)
- `JOBS_SCALE=0.3` — fewer completed jobs (rank tiers are preserved)

The script logs a per-worker rank table (name, city, tier, in-year jobs,
review count, rating) when it finishes.

Note on the free (Spark) plan: the full dataset writes ~24k documents, which
exceeds the 20k writes/day free quota. For the free plan use:

```
CLEAN=1 JOBS_SCALE=0.3 REVIEWS_PER_WORKER=60 node seed.js   # ~18k writes, fits one day
```

This still seeds every rank tier and 60 multilingual reviews per worker.

## Implementation Plan

See `QuickFix-Implementation-Plan.md` in this folder for the full task-by-task plan.
