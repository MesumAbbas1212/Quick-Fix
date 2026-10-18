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
| preferredLanguage | string | BCP-47 code chosen at sign-up (e.g. `'en'`, `'ur'`); the app shows itself and translates reviews into it. Options come from the `languages` collection below |
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
