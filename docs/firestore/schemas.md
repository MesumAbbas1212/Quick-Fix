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
| originalText | string | Urdu or English |
| originalLang | string | `'ur' \| 'en'` |
| translatedText | string? | English translation (TranslationService) |
| createdAt | timestamp | |

## payments (mock)

Written by `PaymentService` (`Payment`).

| Field | Type | Notes |
|---|---|---|
| jobId | string | |
| payerId | string | |
| workerId | string | |
| amount | number | PKR |
| status | string | `'pending' \| ...` |
| method | string | `'mock'` |
| createdAt | timestamp | |

## categories

Read by the app for the manual category dropdown (admin-managed).

| Field | Type | Notes |
|---|---|---|
| name | string | JobCategory enum name |
| icon | string | |
| isActive | bool | |

## reports

| Field | Type | Notes |
|---|---|---|
| reporterId | string | |
| reportedId | string | |
| jobId | string? | optional context |
| reason | string | |
| status | string | `'open' \| ...` |
| createdAt | timestamp | |
