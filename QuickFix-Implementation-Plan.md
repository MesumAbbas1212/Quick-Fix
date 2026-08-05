# QuickFix Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build QuickFix, an on-demand local service matching platform — a Flutter (Android) mobile app connecting users with workers (plumbing, electrical, furniture repair, etc.), plus a web admin dashboard, backed by Firebase.

**Architecture:** Monorepo with two apps sharing one Firebase project. The Flutter app holds both the User and Worker roles (role-based routing after login). A separate React + Vite web app is the admin dashboard. Firestore is the database with role-scoped security rules; Storage holds job/profile images; Authentication handles email/phone login. AI features: Google ML Kit on-device image classification (category suggestion) and Google Cloud Translation API (review translation). Chat is real-time via Firestore listeners.

**Tech Stack:** Flutter / Dart (mobile), React 18 + Vite + TypeScript (admin web), Firebase Auth, Firestore, Firebase Storage, Google ML Kit, Google Cloud Translation API, `geolocator` + `google_maps_flutter` (location), `flutter_chat_ui` or hand-rolled chat widgets.

---

## Table of Contents

1. [Design Reference](#design-reference)
2. [Repository Layout](#repository-layout)
3. [Firestore Data Model](#firestore-data-model)
4. [Firebase & Environment Setup](#firebase--environment-setup)
5. [Phase 0 — Repo Scaffold & Shared Design System](#phase-0--repo-scaffold--shared-design-system)
6. [Phase 1 — Authentication & Role Selection](#phase-1--authentication--role-selection)
7. [Phase 2 — User & Worker Profiles](#phase-2--user--worker-profiles)
8. [Phase 3 — Post a Job (Image + AI Category)](#phase-3--post-a-job-image--ai-category)
9. [Phase 4 — Find Jobs & Matching](#phase-4--find-jobs--matching)
10. [Phase 5 — Job Requests & Job Lifecycle](#phase-5--job-requests--job-lifecycle)
11. [Phase 6 — Real-time Chat + Location Sharing](#phase-6--real-time-chat--location-sharing)
12. [Phase 7 — Reviews & Multilingual Translation](#phase-7--reviews--multilingual-translation)
13. [Phase 8 — Admin Web Dashboard](#phase-8--admin-web-dashboard)
14. [Phase 9 — Mock Payments, Polish & Final QA](#phase-9--mock-payments-polish--final-qa)
15. [Cross-Cutting: Testing Strategy](#cross-cutting-testing-strategy)

---

## Design Reference

The exact screen designs are the 5 exported HTML files (currently in `~/Downloads` as `ai_studio_code.html`, `ai_studio_code (1..4).html`). Copy them into the repo during Phase 0:

- `Login` → `docs/design/login.html`
- `Find Jobs` → `docs/design/find-jobs.html`
- `Post a Job` → `docs/design/post-a-job.html`
- `Job Request` → `docs/design/job-request.html`
- `Chat` → `docs/design/chat.html`

### Design Tokens (from the HTML exports)

| Token | Value | Usage |
|---|---|---|
| `brandBlue` | `#004F9F` | Primary: headers, primary buttons, chat send |
| `accentYellow` | `#FFB800` | Logo icon bg, highlights, worker accent |
| `ctaOrange` | `#F36C00` | Primary CTA buttons (Login, Post Job, Accept) |
| `dangerRed` | `#E53935` | Decline button, destructive actions |
| `chatBlue` | `#0078D4` | Outgoing chat bubble |
| `bgLight` | `#F4F6F9` | Screen background |
| `surfaceWhite` | `#FFFFFF` | Cards |
| `borderGray` | `#E2E8F0` | Card borders |
| `textDark` | `#0F172A` | Headings (slate-900) |
| `textMuted` | `#64748B` | Secondary text (slate-500) |
| `textRed` | `#EF4444` | Price/location emphasis (red-500) |
| Radius | `12px` cards, `16px` buttons, `999px` pills | Cards/buttons |
| Font | System UI stack | Flutter default with fallback |

Phone frame: `340×680`, outer radius `48px`, screen radius `38px`, notch pill at top.

---

## Repository Layout

```
D:\OpenCode_Projects\FYP Project\
├── README.md
├── .gitignore
├── .gitattributes
├── docs/
│   ├── design/                  # the 5 HTML exports + this plan
│   └── firestore/
│       ├── firestore.rules
│       ├── firestore.indexes.json
│       └── storage.rules
├── mobile/                      # Flutter app (User + Worker)
│   ├── pubspec.yaml
│   ├── lib/
│   │   ├── main.dart
│   │   ├── app.dart
│   │   ├── core/
│   │   │   ├── theme/app_theme.dart       # design tokens -> Flutter ThemeData
│   │   │   ├── constants/app_strings.dart
│   │   │   └── utils/validators.dart
│   │   ├── models/
│   │   │   ├── user.dart
│   │   │   ├── worker.dart
│   │   │   ├── job.dart
│   │   │   ├── job_request.dart
│   │   │   ├── chat.dart
│   │   │   ├── message.dart
│   │   │   ├── review.dart
│   │   │   └── category.dart
│   │   ├── services/
│   │   │   ├── auth_service.dart
│   │   │   ├── profile_service.dart
│   │   │   ├── job_service.dart
│   │   │   ├── matching_service.dart
│   │   │   ├── chat_service.dart
│   │   │   ├── review_service.dart
│   │   │   ├── translation_service.dart
│   │   │   ├── location_service.dart
│   │   │   ├── image_classifier.dart
│   │   │   └── payment_service.dart
│   │   ├── state/                # simple ChangeNotifier controllers
│   │   │   ├── auth_controller.dart
│   │   │   ├── job_controller.dart
│   │   │   ├── chat_controller.dart
│   │   │   └── matching_controller.dart
│   │   └── ui/
│   │       ├── screens/
│   │       │   ├── login/login_screen.dart
│   │       │   ├── signup/signup_screen.dart
│   │       │   ├── onboarding/role_select_screen.dart
│   │       │   ├── home/home_screen.dart            # User dashboard
│   │       │   ├── find_jobs/find_jobs_screen.dart
│   │       │   ├── post_job/post_job_screen.dart
│   │       │   ├── job_request/job_request_screen.dart
│   │       │   ├── my_jobs/my_jobs_screen.dart
│   │       │   ├── chat/chat_list_screen.dart
│   │       │   ├── chat/chat_screen.dart
│   │       │   ├── profile/profile_screen.dart
│   │       │   ├── reviews/review_screen.dart
│   │       │   ├── payments/mock_payment_screen.dart
│   │       │   └── worker/worker_dashboard_screen.dart
│   │       └── widgets/          # shared widgets (cards, bottom nav, etc.)
│   │           ├── bottom_nav_bar.dart
│   │           ├── job_card.dart
│   │           ├── rating_stars.dart
│   │           ├── role_toggle_card.dart
│   │           └── primary_button.dart
│   └── test/
│       ├── unit/                 # model + service tests
│       ├── widget/               # screen smoke tests
│       └── fixtures/
└── admin/                        # React + Vite + TS web dashboard
    ├── package.json
    ├── index.html
    ├── vite.config.ts
    ├── src/
    │   ├── main.tsx
    │   ├── App.tsx
    │   ├── api/                  # Firebase services
    │   │   ├── auth.ts
    │   │   ├── users.ts
    │   │   ├── jobs.ts
    │   │   └── reports.ts
    │   ├── components/           # tables, modals, charts
    │   ├── pages/                # login, users, jobs, analytics
    │   └── styles/design.css
    └── test/
```

---

## Firestore Data Model

Collections and key fields (all timestamps stored as `Timestamp`):

### `users`
```
{ uid, email, displayName, phone, role: "user"|"worker"|"admin",
  profilePhotoUrl, location: {lat, lng, label}, createdAt, blocked }
```

### `workers`
```
{ uid, skills: [string], categories: [string], experienceYears,
  hourlyRate, availability: {[weekday]: [hourRange]}, serviceArea,
  location: {lat, lng, label}, rating: double, ratingCount: int,
  completedJobs: int, earningsTotal: double, status: "active"|"blocked" }
```

### `categories`
```
{ id, name, keywords: [string], icon }
```
Seed: Plumbing, Electrical, Furniture Repair, Cleaning, Painting, Appliance Repair, Carpentry, Other.

### `jobs`
```
{ id, userId, workerId?, title, description, imageUrl,
  categoryId, suggestedCategoryId, budgetMin, budgetMax,
  location: {lat, lng, label}, status: "open"|"assigned"|"completed"|"cancelled",
  createdAt, assignedAt, completedAt, distanceKm? }
```

### `jobRequests`
```
{ id, jobId, workerId, userId, quote, message, status:
  "pending"|"accepted"|"rejected"|"cancelled", createdAt, respondedAt }
```

### `chats`
```
{ id, participantIds: [uid1, uid2], jobId?, lastMessage, lastMessageAt,
  unread: {[uid]: int} }
```

### `messages`
```
{ id, chatId, senderId, text, type: "text"|"location", location?: {lat, lng, label},
  timestamp }
```

### `reviews`
```
{ id, jobId, reviewerId, workerId, rating: 1-5, originalText, originalLang,
  translatedText, createdAt }
```

### `reports`
```
{ id, reportedBy, reportedUserId, reason, status: "open"|"resolved"|"dismissed",
  createdAt }
```

### `payments` (mock)
```
{ id, jobId, payerId, payeeId, amount, status: "paid", method: "mock", createdAt }
```

---

## Firebase & Environment Setup

### Prerequisites
- Flutter SDK 3.x installed (`flutter doctor` passes).
- Node 18+ and npm.
- A Google/Firebase account.

### Steps
1. Create a new Firebase project (console.firebase.google.com), e.g. `quickfix-fyp`.
2. Enable **Authentication** → Email/Password (and Phone if desired).
3. Create **Cloud Firestore** database (test mode initially; lock down later with `docs/firestore/firestore.rules`).
4. Create **Storage** bucket (test mode initially).
5. Register an **Android** app in project settings (package name `com.quickfix.app`), download `google-services.json` into `mobile/android/app/`.
6. Create a **Web** app in project settings, copy the config into `admin/src/config/firebase.ts`.
7. Enable the **Google Cloud Translation API** (Cloud console) and create an API key with the service restricted; put the key in a server-only config (see Phase 7).
8. For local Firestore development, optionally install the **Firebase CLI emulators**.

> Keep API keys out of the repo. Use `--dart-define` for the mobile app and `.env` for the admin app.

---

## Phase 0 — Repo Scaffold & Shared Design System

> Goal: create the monorepo, initialize git, and establish the design tokens that all screens will use.

### Task 0.1: Create repository skeleton

**Files:**
- Create: `D:\OpenCode_Projects\FYP Project\.gitignore`
- Create: `D:\OpenCode_Projects\FYP Project\README.md`
- Create: `D:\OpenCode_Projects\FYP Project\docs\design\` (copy 5 HTML exports)
- Create: `D:\OpenCode_Projects\FYP Project\docs\firestore\firestore.rules`
- Create: `D:\OpenCode_Projects\FYP Project\docs\firestore\storage.rules`

- [ ] **Step 1:** Initialize git and create the root files.

```bash
cd "D:\OpenCode_Projects\FYP Project"
git init
```

Create `.gitignore`:
```
# Flutter
mobile/build/
mobile/.dart_tool/
mobile/.idea/
mobile/android/.gradle/
*.iml

# Node
admin/node_modules/
admin/dist/
admin/.env

# Misc
*.log
.DS_Store
```

Create `README.md` with a 5-line project summary, folder overview, and a pointer to this plan.

- [ ] **Step 2:** Copy the design exports.

```bash
mkdir -p docs/design
cp ~/Downloads/ai_studio_code.html            docs/design/login.html
cp ~/Downloads/"ai_studio_code (1).html"      docs/design/find-jobs.html
cp ~/Downloads/"ai_studio_code (2).html"      docs/design/post-a-job.html
cp ~/Downloads/"ai_studio_code (3).html"      docs/design/job-request.html
cp ~/Downloads/"ai_studio_code (4).html"      docs/design/chat.html
```

- [ ] **Step 3:** Add initial Firestore rules (locked-down base, refined later).

`docs/firestore/firestore.rules`:
```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    function signedIn() { return request.auth != null; }
    function isRole(role) { return signedIn() && request.auth.token.role == role; }

    match /users/{uid} {
      allow read: if signedIn();
      allow create: if signedIn() && request.auth.uid == uid;
      allow update: if signedIn() && request.auth.uid == uid;
      allow delete: if false;
    }
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

- [ ] **Step 4:** Commit.

```bash
git add .
git commit -m "chore: scaffold repo skeleton, gitignore, initial firestore rules"
```

### Task 0.2: Flutter app scaffold

**Files:**
- Create: `mobile/` via `flutter create`
- Modify: `mobile/pubspec.yaml`

- [ ] **Step 1:** Create the Flutter app.

```bash
cd "D:\OpenCode_Projects\FYP Project"
flutter create mobile --org com.quickfix --project-name quickfix
```

- [ ] **Step 2:** Add dependencies to `mobile/pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  firebase_core: ^3.6.0
  firebase_auth: ^5.3.1
  cloud_firestore: ^5.4.4
  firebase_storage: ^12.3.4
  firebase_ml_model_downloader: ^0.3.2
  google_mlkit_image_labeling: ^0.13.0
  google_mlkit_commons: ^0.9.0
  http: ^1.2.0
  provider: ^6.1.2
  image_picker: ^1.1.2
  path_provider: ^2.1.4
  geolocator: ^13.0.1
  google_maps_flutter: ^2.9.0
  shared_preferences: ^2.3.2
  intl: ^0.19.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^4.0.0
  mocktail: ^1.0.4
```

- [ ] **Step 3:** Run `flutter pub get` and verify the app builds a hello-world on an emulator:

```bash
cd mobile
flutter pub get
flutter run
```

- [ ] **Step 4:** Commit.

```bash
git add mobile
git commit -m "chore: scaffold Flutter app with Firebase dependencies"
```

### Task 0.3: Admin web scaffold

**Files:**
- Create: `admin/`
- Create: `admin/src/config/firebase.ts` (placeholder — real config added via `.env`)

- [ ] **Step 1:** Scaffold Vite + React + TS.

```bash
cd "D:\OpenCode_Projects\FYP Project"
npm create vite@latest admin -- --template react-ts
cd admin
npm install firebase react-router-dom
```

- [ ] **Step 2:** Replace `admin/src/App.tsx` with a minimal placeholder that renders `<h1>QuickFix Admin</h1>` so the build passes.

- [ ] **Step 3:** Verify:

```bash
npm run build
```

- [ ] **Step 4:** Commit.

```bash
cd ..
git add admin
git commit -m "chore: scaffold React+Vite admin app"
```

### Task 0.4: Shared design system (Flutter theme)

**Files:**
- Create: `mobile/lib/core/theme/app_theme.dart`
- Create: `mobile/lib/core/constants/app_strings.dart`
- Create: `mobile/lib/app.dart`
- Modify: `mobile/lib/main.dart`

- [ ] **Step 1:** Write the theme with the exact design tokens.

`mobile/lib/core/theme/app_theme.dart`:
```dart
import 'package:flutter/material.dart';

class AppColors {
  static const brandBlue = Color(0xFF004F9F);
  static const accentYellow = Color(0xFFFFB800);
  static const ctaOrange = Color(0xFFF36C00);
  static const dangerRed = Color(0xFFE53935);
  static const chatBlue = Color(0xFF0078D4);
  static const bgLight = Color(0xFFF4F6F9);
  static const surfaceWhite = Color(0xFFFFFFFF);
  static const borderGray = Color(0xFFE2E8F0);
  static const textDark = Color(0xFF0F172A);
  static const textMuted = Color(0xFF64748B);
  static const textRed = Color(0xFFEF4444);
}

class AppTheme {
  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.brandBlue,
        primary: AppColors.brandBlue,
        secondary: AppColors.accentYellow,
        error: AppColors.dangerRed,
        surface: AppColors.surfaceWhite,
      ),
    );
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.bgLight,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.brandBlue,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.ctaOrange,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceWhite,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.borderGray),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.borderGray),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2:** Wire the theme into the app.

`mobile/lib/app.dart`:
```dart
import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';

class QuickFixApp extends StatelessWidget {
  const QuickFixApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QuickFix',
      theme: AppTheme.light(),
      home: const Scaffold(
        body: Center(child: Text('QuickFix')),
      ),
    );
  }
}
```

`mobile/lib/main.dart`:
```dart
import 'package:flutter/material.dart';
import 'app.dart';

void main() {
  runApp(const QuickFixApp());
}
```

- [ ] **Step 3:** Run the app and confirm the background is `#F4F6F9` (design bgLight).

- [ ] **Step 4:** Commit.

```bash
git add mobile/lib
git commit -m "feat: add QuickFix design system theme"
```

---

## Phase 1 — Authentication & Role Selection

> Goal: email/password auth + choose role (User/Worker) on login screen, exactly matching `docs/design/login.html`.

### Task 1.1: Auth service (Firebase) + unit tests

**Files:**
- Create: `mobile/lib/services/auth_service.dart`
- Create: `mobile/test/unit/auth_service_test.dart`
- Create: `mobile/lib/models/user.dart`

- [ ] **Step 1:** Write the failing model test.

`mobile/test/unit/auth_service_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:quickfix/models/user.dart';

void main() {
  group('AppUser', () {
    test('fromJson maps all fields', () {
      final user = AppUser.fromJson(const {
        'uid': 'u1',
        'email': 'a@b.com',
        'displayName': 'Ali',
        'phone': '+92123',
        'role': 'user',
      });
      expect(user.uid, 'u1');
      expect(user.role, 'user');
      expect(user.displayName, 'Ali');
    });

    test('toJson round-trips', () {
      const user = AppUser(
        uid: 'u1', email: 'a@b.com', displayName: 'Ali',
        phone: '+92123', role: 'user',
      );
      expect(AppUser.fromJson(user.toJson()).toJson(), user.toJson());
    });
  });
}
```

- [ ] **Step 2:** Run and confirm it fails (no `AppUser` defined).

Run: `flutter test test/unit/auth_service_test.dart`
Expected: FAIL with "Error: Could not resolve AppUser".

- [ ] **Step 3:** Create the model.

`mobile/lib/models/user.dart`:
```dart
class AppUser {
  final String uid;
  final String email;
  final String displayName;
  final String phone;
  final String role; // user | worker | admin

  const AppUser({
    required this.uid,
    required this.email,
    required this.displayName,
    this.phone = '',
    this.role = 'user',
  });

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        uid: json['uid'] as String,
        email: json['email'] as String,
        displayName: json['displayName'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
        role: json['role'] as String? ?? 'user',
      );

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'email': email,
        'displayName': displayName,
        'phone': phone,
        'role': role,
      };

  AppUser copyWith({String? role, String? displayName, String? phone}) =>
      AppUser(
        uid: uid,
        email: email,
        displayName: displayName ?? this.displayName,
        phone: phone ?? this.phone,
        role: role ?? this.role,
      );
}
```

- [ ] **Step 4:** Run tests, expect PASS.

- [ ] **Step 5:** Create the auth service wrapping Firebase Auth + Firestore role doc.

`mobile/lib/services/auth_service.dart`:
```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user.dart';

class AuthService {
  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  AuthService({FirebaseAuth? auth, FirebaseFirestore? db})
      : _auth = auth ?? FirebaseAuth.instance,
        _db = db ?? FirebaseFirestore.instance;

  Stream<User?> get authState => _auth.authStateChanges();

  Future<AppUser> login(String email, String password) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    return _loadUser(cred.user!.uid);
  }

  Future<AppUser> signUp({
    required String email,
    required String password,
    required String displayName,
    required String role,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final uid = cred.user!.uid;
    final user = AppUser(
      uid: uid,
      email: email.trim(),
      displayName: displayName,
      role: role,
    );
    await _db.collection('users').doc(uid).set(user.toJson());
    return user;
  }

  Future<AppUser> _loadUser(String uid) async {
    final snap = await _db.collection('users').doc(uid).get();
    final data = snap.data();
    if (data == null) {
      throw StateError('No profile for user $uid');
    }
    return AppUser.fromJson({'uid': uid, ...data});
  }

  Future<void> logout() => _auth.signOut();
}
```

- [ ] **Step 6:** Commit.

```bash
git add mobile/lib mobile/test
git commit -m "feat: add AppUser model and AuthService"
```

### Task 1.2: Auth controller + login/signup screens (matches design)

**Files:**
- Create: `mobile/lib/state/auth_controller.dart`
- Create: `mobile/lib/ui/screens/login/login_screen.dart`
- Create: `mobile/lib/ui/screens/signup/signup_screen.dart`
- Create: `mobile/lib/ui/screens/onboarding/role_select_screen.dart`
- Create: `mobile/test/widget/login_screen_test.dart`

- [ ] **Step 1:** Write the widget smoke test for the login screen.

`mobile/test/widget/login_screen_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:quickfix/ui/screens/login/login_screen.dart';
import 'package:quickfix/ui/widgets/primary_button.dart';

void main() {
  testWidgets('login screen shows role cards, email/password, login button',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
    expect(find.text('QuickFix'), findsOneWidget);
    expect(find.text('Login as User'), findsOneWidget);
    expect(find.text('Login as Worker'), findsOneWidget);
    expect(find.text('Login'), findsWidgets);
    expect(find.byType(PrimaryButton), findsOneWidget);
  });
}
```

- [ ] **Step 2:** Run it; expect FAIL (screens don't exist).

- [ ] **Step 3:** Create the auth controller.

`mobile/lib/state/auth_controller.dart`:
```dart
import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../services/auth_service.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthController extends ChangeNotifier {
  final AuthService _auth;
  AuthController(this._auth) {
    _auth.authState.listen((firebaseUser) {
      if (firebaseUser == null) {
        _status = AuthStatus.unauthenticated;
      }
      notifyListeners();
    });
  }

  AuthStatus _status = AuthStatus.unknown;
  AppUser? _currentUser;
  String? _error;

  AuthStatus get status => _status;
  AppUser? get currentUser => _currentUser;
  String? get error => _error;

  Future<void> login(String email, String password) async {
    _error = null;
    try {
      _currentUser = await _auth.login(email, password);
      _status = AuthStatus.authenticated;
    } catch (e) {
      _error = e.toString();
    }
    notifyListeners();
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String displayName,
    required String role,
  }) async {
    _error = null;
    try {
      _currentUser = await _auth.signUp(
        email: email, password: password,
        displayName: displayName, role: role,
      );
      _status = AuthStatus.authenticated;
    } catch (e) {
      _error = e.toString();
    }
    notifyListeners();
  }

  Future<void> logout() async {
    await _auth.logout();
    _currentUser = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }
}
```

- [ ] **Step 4:** Create the role select + login screens matching the design.

`mobile/lib/ui/screens/onboarding/role_select_screen.dart` — grid of two selectable cards (`User` blue, `Worker` yellow). Selecting a role highlights it; the next button (orange `FilledButton`) navigates to SignUp with the role preselected.

`mobile/lib/ui/screens/login/login_screen.dart`:
```dart
import 'package:flutter/material.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/role_toggle_card.dart';
import '../signup/signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loginAsWorker = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: const Color(0xFF004F9F),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 32),
              const CircleAvatar(
                radius: 32,
                backgroundColor: Color(0xFFFFB800),
                child: Icon(Icons.build, size: 36, color: Color(0xFF004F9F)),
              ),
              const SizedBox(height: 12),
              const Text(
                'QuickFix',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const Text(
                'On-Demand Local Service Matching',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFFBFDBFE), fontSize: 12),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: RoleToggleCard(
                      label: 'Login as User',
                      subtitle: 'Find Services',
                      icon: Icons.person,
                      active: !_loginAsWorker,
                      onTap: () => setState(() => _loginAsWorker = false),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: RoleToggleCard(
                      label: 'Login as Worker',
                      subtitle: 'Get Jobs',
                      icon: Icons.handyman,
                      active: _loginAsWorker,
                      onTap: () => setState(() => _loginAsWorker = true),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(hintText: 'Email'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _password,
                obscureText: true,
                decoration: const InputDecoration(hintText: 'Password'),
              ),
              const SizedBox(height: 20),
              PrimaryButton(
                label: 'Login',
                onPressed: () {
                  // wired to AuthController in app.dart
                },
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SignUpScreen(role: 'user'),
                    ),
                  );
                },
                child: const Text(
                  "Don't have an account? Sign Up",
                  style: TextStyle(color: Color(0xFFFFB800)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 5:** Create shared widgets used above.

`mobile/lib/ui/widgets/role_toggle_card.dart`:
```dart
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class RoleToggleCard extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  const RoleToggleCard({
    super.key,
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = active ? AppColors.accentYellow : AppColors.brandBlue;
    final fg = active ? AppColors.brandBlue : Colors.white;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: active
              ? [BoxShadow(color: Colors.white.withOpacity(0.4), spreadRadius: 1)]
              : null,
        ),
        child: Column(
          children: [
            Icon(icon, color: fg, size: 28),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.bold, fontSize: 12)),
            Text(subtitle, style: TextStyle(color: fg.withOpacity(0.8), fontSize: 10)),
          ],
        ),
      ),
    );
  }
}
```

`mobile/lib/ui/widgets/primary_button.dart`:
```dart
import 'package:flutter/material.dart';

class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: loading ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFFF36C00),
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: loading
          ? const SizedBox(
              height: 20, width: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
          : Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
    );
  }
}
```

- [ ] **Step 6:** Create the sign-up screen that collects name, email, password, and reuses the selected role.

`mobile/lib/ui/screens/signup/signup_screen.dart`:
```dart
import 'package:flutter/material.dart';
import '../../widgets/primary_button.dart';

class SignUpScreen extends StatefulWidget {
  final String role;
  const SignUpScreen({super.key, this.role = 'user'});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF004F9F),
      appBar: AppBar(
        title: const Text('Create Account'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Sign up as ${widget.role == 'worker' ? 'Worker' : 'User'}',
                style: const TextStyle(
                  color: Color(0xFFFFB800),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _name,
                decoration: const InputDecoration(hintText: 'Full name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(hintText: 'Email'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _password,
                obscureText: true,
                decoration: const InputDecoration(hintText: 'Password'),
              ),
              const SizedBox(height: 20),
              PrimaryButton(
                label: 'Create Account',
                loading: false,
                onPressed: () {
                  // wired to AuthController.signUp(name, email, password, role)
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 7:** Run the smoke test; expect PASS.

- [ ] **Step 8:** Commit.

```bash
git add mobile/lib mobile/test
git commit -m "feat: login + role selection + signup UI matching design"
```

### Task 1.3: App shell with role-based routing

**Files:**
- Modify: `mobile/lib/app.dart`
- Modify: `mobile/lib/main.dart`

- [ ] **Step 1:** Write a widget test that the app shows LoginScreen when unauthenticated.

`mobile/test/widget/app_shell_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:quickfix/app.dart';
import 'package:quickfix/state/auth_controller.dart';
import 'package:quickfix/services/auth_service.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthService extends Mock implements AuthService {}

void main() {
  testWidgets('unauthenticated shows login screen', (tester) async {
    final auth = MockAuthService();
    final controller = AuthController(auth);
    await tester.pumpWidget(QuickFixApp(auth: controller));
    await tester.pumpAndSettle();
    expect(find.text('QuickFix'), findsOneWidget);
  });
}
```

- [ ] **Step 2:** Update `app.dart` to route by auth status.

```dart
import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'state/auth_controller.dart';
import 'ui/screens/login/login_screen.dart';
import 'ui/screens/home/home_screen.dart';

class QuickFixApp extends StatelessWidget {
  final AuthController? auth;
  const QuickFixApp({super.key, this.auth});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QuickFix',
      theme: AppTheme.light(),
      home: const LoginScreen(),
    );
  }
}
```

- [ ] **Step 3:** Update `main.dart` to initialize Firebase before `runApp`.

```dart
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const QuickFixApp());
}
```

- [ ] **Step 4:** Run the app, create an account via SignUp, log in, and verify role selection persists. Fix any routing issues surfaced by the test.

- [ ] **Step 5:** Commit.

```bash
git add mobile/lib mobile/test
git commit -m "feat: wire app shell, firebase init, auth gating"
```

---

## Phase 2 — User & Worker Profiles

> Goal: profile creation/editing, profile photo upload (Firebase Storage), worker fields (skills, hourly rate, availability).

### Task 2.1: Worker model + profile service

**Files:**
- Create: `mobile/lib/models/worker.dart`
- Create: `mobile/lib/services/profile_service.dart`
- Create: `mobile/test/unit/worker_model_test.dart`

- [ ] **Step 1:** Write failing model test (skills, rating, availability serialization).

`mobile/test/unit/worker_model_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:quickfix/models/worker.dart';

void main() {
  test('Worker fromJson/toJson round-trip', () {
    const worker = Worker(
      uid: 'w1',
      skills: ['plumbing', 'electrical'],
      categories: ['Plumbing'],
      experienceYears: 3,
      hourlyRate: 500,
      serviceArea: 'Lahore',
      rating: 4.5,
      ratingCount: 12,
      completedJobs: 10,
      earningsTotal: 50000,
    );
    final json = worker.toJson();
    expect(json['skills'], ['plumbing', 'electrical']);
    expect(Worker.fromJson(json).hourlyRate, 500);
    expect(Worker.fromJson(json).rating, 4.5);
  });

  test('addRating updates rating and count', () {
    final worker = Worker.fromJson(const {
      'uid': 'w1', 'skills': [], 'categories': [],
      'experienceYears': 0, 'hourlyRate': 0, 'serviceArea': '',
      'rating': 4.0, 'ratingCount': 4, 'completedJobs': 0, 'earningsTotal': 0,
    });
    final updated = worker.addRating(5);
    expect(updated.ratingCount, 5);
    expect(updated.rating, closeTo(4.2, 0.001));
  });
}
```

- [ ] **Step 2:** Run; expect FAIL (Worker undefined).

- [ ] **Step 3:** Create the model.

`mobile/lib/models/worker.dart`:
```dart
class Worker {
  final String uid;
  final List<String> skills;
  final List<String> categories;
  final int experienceYears;
  final double hourlyRate;
  final String serviceArea;
  final double rating;
  final int ratingCount;
  final int completedJobs;
  final double earningsTotal;

  const Worker({
    required this.uid,
    required this.skills,
    required this.categories,
    required this.experienceYears,
    required this.hourlyRate,
    required this.serviceArea,
    this.rating = 0,
    this.ratingCount = 0,
    this.completedJobs = 0,
    this.earningsTotal = 0,
  });

  factory Worker.fromJson(Map<String, dynamic> json) => Worker(
        uid: json['uid'] as String,
        skills: (json['skills'] as List?)?.cast<String>() ?? [],
        categories: (json['categories'] as List?)?.cast<String>() ?? [],
        experienceYears: json['experienceYears'] as int? ?? 0,
        hourlyRate: (json['hourlyRate'] as num?)?.toDouble() ?? 0,
        serviceArea: json['serviceArea'] as String? ?? '',
        rating: (json['rating'] as num?)?.toDouble() ?? 0,
        ratingCount: json['ratingCount'] as int? ?? 0,
        completedJobs: json['completedJobs'] as int? ?? 0,
        earningsTotal: (json['earningsTotal'] as num?)?.toDouble() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'skills': skills,
        'categories': categories,
        'experienceYears': experienceYears,
        'hourlyRate': hourlyRate,
        'serviceArea': serviceArea,
        'rating': rating,
        'ratingCount': ratingCount,
        'completedJobs': completedJobs,
        'earningsTotal': earningsTotal,
      };

  Worker addRating(double newRating) {
    final newCount = ratingCount + 1;
    final newAvg = (rating * ratingCount + newRating) / newCount;
    return Worker(
      uid: uid, skills: skills, categories: categories,
      experienceYears: experienceYears, hourlyRate: hourlyRate,
      serviceArea: serviceArea, rating: newAvg, ratingCount: newCount,
      completedJobs: completedJobs, earningsTotal: earningsTotal,
    );
  }
}
```

- [ ] **Step 4:** Run tests; expect PASS.

- [ ] **Step 5:** Create `profile_service.dart` with `saveWorker`, `getWorker`, `uploadProfilePhoto` (uploads to `gs://.../profiles/{uid}.jpg` via `firebase_storage`), `updateUser`.

- [ ] **Step 6:** Commit.

```bash
git add mobile/lib mobile/test
git commit -m "feat: Worker model + profile service"
```

### Task 2.2: Profile screens (User + Worker)

**Files:**
- Create: `mobile/lib/ui/screens/profile/profile_screen.dart`
- Create: `mobile/lib/ui/screens/profile/worker_profile_edit_screen.dart`
- Create: `mobile/lib/ui/widgets/rating_stars.dart`
- Create: `mobile/test/widget/profile_screen_test.dart`

- [ ] **Step 1:** Write smoke tests (profile shows name; worker edit shows skill fields).

- [ ] **Step 2:** Implement `rating_stars.dart` (renders ★★★★☆ from a double using `Icons.star`/`Icons.star_half`/`Icons.star_border`, color `#BA7517`/amber).

- [ ] **Step 3:** Implement `profile_screen.dart`: hero header (photo + name + location), stats row (Jobs done / Rating / Active jobs), skills section with `+ Add`, and an Edit button. Mirror `skillswap_04_my_profile.html` layout but with QuickFix colors.

- [ ] **Step 4:** Implement `worker_profile_edit_screen.dart`: form for skills (multi-select chips), experience, hourly rate, service area, availability toggles.

- [ ] **Step 5:** Run tests; expect PASS. Manually verify photo upload works on emulator.

- [ ] **Step 6:** Commit.

```bash
git add mobile/lib mobile/test
git commit -m "feat: profile screens with photo upload and worker edit"
```

---

## Phase 3 — Post a Job (Image + AI Category)

> Goal: user uploads a photo of the problem, ML Kit suggests a category, user confirms/overrides, job is saved. Matches `docs/design/post-a-job.html`.

### Task 3.1: Category model + seed data

**Files:**
- Create: `mobile/lib/models/category.dart`
- Create: `backend/seed/categories.json`
- Create: `mobile/test/unit/category_test.dart`

- [ ] **Step 1:** Write model test (keywords matching).

`mobile/test/unit/category_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:quickfix/models/category.dart';

void main() {
  test('category matches by keyword', () {
    const c = Category(id: 'plumbing', name: 'Plumbing', keywords: ['pipe', 'faucet', 'leak']);
    expect(c.matches('broken pipe'), isTrue);
    expect(c.matches('broken sofa'), isFalse);
  });
}
```

- [ ] **Step 2:** Run; expect FAIL.

- [ ] **Step 3:** Create the model.

`mobile/lib/models/category.dart`:
```dart
class Category {
  final String id;
  final String name;
  final List<String> keywords;

  const Category({required this.id, required this.name, this.keywords = const []});

  factory Category.fromJson(Map<String, dynamic> json) => Category(
        id: json['id'] as String,
        name: json['name'] as String,
        keywords: (json['keywords'] as List?)?.cast<String>() ?? [],
      );

  bool matches(String text) {
    final lower = text.toLowerCase();
    return keywords.any((k) => lower.contains(k.toLowerCase()));
  }
}
```

- [ ] **Step 4:** Run; expect PASS.

- [ ] **Step 5:** Create `backend/seed/categories.json` with 8 categories (Plumbing, Electrical, Furniture Repair, Cleaning, Painting, Appliance Repair, Carpentry, Other) and realistic keywords for each.

- [ ] **Step 6:** Commit.

```bash
git add mobile/lib backend/seed mobile/test
git commit -m "feat: Category model and seed data"
```

### Task 3.2: Image classifier service (ML Kit) + unit test

**Files:**
- Create: `mobile/lib/services/image_classifier.dart`
- Create: `mobile/test/unit/image_classifier_test.dart`

- [ ] **Step 1:** Write failing test for the fallback path (classifier wrapper returns suggestion).

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:quickfix/services/image_classifier.dart';

void main() {
  test('ImageClassifier suggestFromText uses keyword fallback', () {
    final classifier = ImageClassifier(categories: [
      Category(id: 'plumbing', name: 'Plumbing', keywords: ['pipe', 'faucet', 'leak']),
      Category(id: 'furniture', name: 'Furniture Repair', keywords: ['sofa', 'chair', 'leg']),
    ]);
    expect(classifier.suggestFromText('sofa leg broken'), 'Furniture Repair');
    expect(classifier.suggestFromText('nothing relevant here'), null);
  });
}
```

- [ ] **Step 2:** Run; expect FAIL.

- [ ] **Step 3:** Implement the classifier.

`mobile/lib/services/image_classifier.dart`:
```dart
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import '../models/category.dart';

/// Wraps Google ML Kit image labeling. When on-device labeling returns
/// nothing useful (or no image), falls back to keyword matching on the
/// user's description.
class ImageClassifier {
  final List<Category> categories;

  ImageClassifier({required this.categories});

  /// On-device path — returns the most confident label or null.
  /// Placeholder for the ML Kit call (see Step 5 below for the real call).
  Future<String?> classifyImage(Uint8List imageBytes) async {
    // Replaced in Step 5 with google_mlkit_image_labeling.
    return null;
  }

  /// Keyword fallback used when ML Kit yields nothing.
  String? suggestFromText(String text) {
    for (final c in categories) {
      if (c.matches(text)) return c.name;
    }
    return null;
  }
}
```

- [ ] **Step 4:** Run; expect PASS.

- [ ] **Step 5:** Implement the real ML Kit call in `classifyImage`:

```dart
import 'dart:io';
import 'dart:typed_data';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:path_provider/path_provider.dart';

Future<String?> classifyImage(Uint8List imageBytes) async {
  final tempDir = await getTemporaryDirectory();
  final file = File('${tempDir.path}/job_img.jpg')..writeAsBytesSync(imageBytes);
  final input = InputImage.fromFile(file);
  final options = ImageLabelerOptions(confidenceThreshold: 0.6);
  final labeler = ImageLabeler(options: options);
  final labels = await labeler.processImage(input);
  labeler.close();
  if (labels.isEmpty) return null;
  final best = labels.reduce((a, b) =>
      a.confidence >= b.confidence ? a : b);
  return _mapLabelToCategory(best.label);
}
```

- [ ] **Step 6:** Add the `_mapLabelToCategory` method to the `ImageClassifier` class so ML labels resolve to categories:

```dart
  /// Maps an ML Kit label (e.g., "Faucet", "Sink") to a category by
  /// checking the label against each category's keywords.
  /// Returns null when no keyword matches.
  String? _mapLabelToCategory(String label) {
    for (final c in categories) {
      if (c.matches(label)) return c.name;
    }
    return null;
  }
```

- [ ] **Step 7:** Commit.

```bash
git add mobile/lib mobile/test
git commit -m "feat: ML Kit image classification with keyword fallback"
```

### Task 3.3: Post-a-Job screen + Job model + JobService

**Files:**
- Create: `mobile/lib/models/job.dart`
- Create: `mobile/lib/services/job_service.dart`
- Create: `mobile/lib/ui/screens/post_job/post_job_screen.dart`
- Create: `mobile/test/unit/job_model_test.dart`
- Create: `mobile/test/widget/post_job_screen_test.dart`

- [ ] **Step 1:** Write failing Job model test (status defaults to open; round-trip).

- [ ] **Step 2:** Run; expect FAIL.

- [ ] **Step 3:** Create `job.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Job {
  final String? id;
  final String userId;
  final String? workerId;
  final String title;
  final String description;
  final String? imageUrl;
  final String? categoryId;
  final String? suggestedCategoryId;
  final double budgetMin;
  final double budgetMax;
  final Map<String, dynamic> location; // {lat, lng, label}
  final String status; // open | assigned | completed | cancelled
  final DateTime createdAt;

  const Job({
    this.id,
    required this.userId,
    this.workerId,
    required this.title,
    required this.description,
    this.imageUrl,
    this.categoryId,
    this.suggestedCategoryId,
    required this.budgetMin,
    required this.budgetMax,
    required this.location,
    this.status = 'open',
    required this.createdAt,
  });

  factory Job.fromJson(Map<String, dynamic> json) => Job(
        id: json['id'] as String?,
        userId: json['userId'] as String,
        workerId: json['workerId'] as String?,
        title: json['title'] as String,
        description: json['description'] as String? ?? '',
        imageUrl: json['imageUrl'] as String?,
        categoryId: json['categoryId'] as String?,
        suggestedCategoryId: json['suggestedCategoryId'] as String?,
        budgetMin: (json['budgetMin'] as num?)?.toDouble() ?? 0,
        budgetMax: (json['budgetMax'] as num?)?.toDouble() ?? 0,
        location: (json['location'] as Map?)?.cast<String, dynamic>() ?? const {},
        status: json['status'] as String? ?? 'open',
        createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'workerId': workerId,
        'title': title,
        'description': description,
        'imageUrl': imageUrl,
        'categoryId': categoryId,
        'suggestedCategoryId': suggestedCategoryId,
        'budgetMin': budgetMin,
        'budgetMax': budgetMax,
        'location': location,
        'status': status,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}
```

- [ ] **Step 4:** Run; expect PASS.

- [ ] **Step 5:** Create `job_service.dart` with `createJob` (uploads image to Storage, writes `jobs` doc), `updateJob`, `getOpenJobs`.

- [ ] **Step 6:** Build `post_job_screen.dart` per design: image picker (`image_picker`), image preview, "Suggested: <Category>" row (from classifier), editable description/location/budget, orange **Post Job** button.

- [ ] **Step 7:** Write and pass widget smoke test (image area, Suggested text, Post Job button present).

- [ ] **Step 8:** Commit.

```bash
git add mobile/lib mobile/test
git commit -m "feat: post-a-job flow with image upload and category suggestion"
```

---

## Phase 4 — Find Jobs & Matching

> Goal: worker sees matching jobs; user sees matched workers. Matches `docs/design/find-jobs.html`.

### Task 4.1: Matching service (skills, distance, availability) + unit tests

**Files:**
- Create: `mobile/lib/services/matching_service.dart`
- Create: `mobile/test/unit/matching_service_test.dart`

- [ ] **Step 1:** Write failing tests.

`mobile/test/unit/matching_service_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:quickfix/services/matching_service.dart';

void main() {
  const center = Loc(31.5204, 74.3587); // Lahore

  test('haversine distance is ~2km', () {
    const near = Loc(31.5300, 74.3700);
    final km = MatchingService.distanceKm(center, near);
    expect(km, closeTo(1.5, 0.5));
  });

  test('rankWorkers sorts by skill match then distance', () {
    const center = Loc(31.5204, 74.3587);
    final candidates = [
      WorkerRank(uid: 'far', skills: ['plumbing'], categories: ['Plumbing'], rating: 4.9, hourlyRate: 800, loc: Loc(31.6, 74.5)),
      WorkerRank(uid: 'near', skills: ['plumbing'], categories: ['Plumbing'], rating: 4.0, hourlyRate: 500, loc: Loc(31.522, 74.36)),
      WorkerRank(uid: 'noSkill', skills: ['cleaning'], categories: ['Cleaning'], rating: 5.0, hourlyRate: 400, loc: Loc(31.521, 74.359)),
    ];
    final ranked = MatchingService.rankWorkers(candidates, center, categories: ['Plumbing']);
    expect(ranked.first.uid, 'near');
    expect(ranked.last.uid, 'noSkill');
  });

  test('matchesJobToWorkers filters by category', () {
    final workers = [
      WorkerRank(uid: 'w1', skills: ['plumbing'], categories: ['Plumbing'], rating: 4.0, hourlyRate: 500, loc: center),
      WorkerRank(uid: 'w2', skills: ['cleaning'], categories: ['Cleaning'], rating: 4.0, hourlyRate: 400, loc: center),
    ];
    final matched = MatchingService.matchesJobToWorkers(
      workers, categories: ['Plumbing'], center: center);
    expect(matched.length, 1);
    expect(matched.single.uid, 'w1');
  });
}
```

- [ ] **Step 2:** Run; expect FAIL.

- [ ] **Step 3:** Implement.

`mobile/lib/services/matching_service.dart`:
```dart
import 'dart:math';

class Loc {
  final double lat, lng;
  const Loc(this.lat, this.lng);
}

class WorkerRank {
  final String uid;
  final List<String> skills;
  final List<String> categories;
  final double rating;
  final double hourlyRate;
  final Loc loc;
  final double distanceKm;

  const WorkerRank({
    required this.uid,
    required this.skills,
    required this.categories,
    required this.rating,
    required this.hourlyRate,
    required this.loc,
    this.distanceKm = 0,
  });

  WorkerRank withDistance(double km) => WorkerRank(
        uid: uid, skills: skills, categories: categories,
        rating: rating, hourlyRate: hourlyRate, loc: loc, distanceKm: km,
      );
}

class MatchingService {
  static const _earthRadiusKm = 6371.0;

  static double distanceKm(Loc a, Loc b) {
    final dLat = _rad(b.lat - a.lat);
    final dLng = _rad(b.lng - a.lng);
    final h = sin(dLat / 2) * sin(dLat / 2) +
        cos(_rad(a.lat)) * cos(_rad(b.lat)) *
            sin(dLng / 2) * sin(dLng / 2);
    return 2 * _earthRadiusKm * asin(sqrt(h));
  }

  static double _rad(double deg) => deg * pi / 180;

  static List<WorkerRank> rankWorkers(
      List<WorkerRank> workers, Loc center, {List<String>? categories}) {
    final scored = <(WorkerRank, double)>[];
    for (final w in workers) {
      final km = distanceKm(center, w.loc);
      final hasSkill = categories == null || categories.isEmpty ||
          w.categories.any(categories.contains);
      scored.add((
        w.withDistance(km),
        _score(w, km, hasSkill),
      ));
    }
    scored.sort((a, b) => b.$2.compareTo(a.$2));
    return scored.map((e) => e.$1).toList();
  }

  static double _score(WorkerRank w, double km, bool hasSkill) {
    double s = 0;
    if (hasSkill) s += 100;
    s += w.rating * 5;
    s -= km * 0.5;
    return s;
  }

  static List<WorkerRank> matchesJobToWorkers(
    List<WorkerRank> workers, {
    required List<String> categories,
    required Loc center,
  }) {
    return rankWorkers(workers, center, categories: categories)
        .where((w) => w.categories.any(categories.contains))
        .toList();
  }
}
```

- [ ] **Step 4:** Run; expect PASS.

- [ ] **Step 5:** Commit.

```bash
git add mobile/lib mobile/test
git commit -m "feat: matching service with distance + skill scoring"
```

### Task 4.2: Find Jobs screen + job feed

**Files:**
- Create: `mobile/lib/ui/widgets/job_card.dart`
- Create: `mobile/lib/ui/screens/find_jobs/find_jobs_screen.dart`
- Create: `mobile/lib/ui/widgets/bottom_nav_bar.dart`
- Create: `mobile/test/widget/find_jobs_screen_test.dart`

- [ ] **Step 1:** Write smoke test (job title, price, distance visible from fake data).

- [ ] **Step 2:** Implement `job_card.dart` per design: rounded image left (80×80), title bold, `📍 PKR 2000 · 15 km away` (price in `textRed`, distance muted).

- [ ] **Step 3:** Implement `bottom_nav_bar.dart` with 4 items: Home, My Jobs, Messages, Profile. Active item is orange `#F36C00`, others `#94A3B8` (slate-400). Uses `Icons.home`, `Icons.work_outline`, `Icons.chat_bubble_outline`, `Icons.person_outline`.

- [ ] **Step 4:** Implement `find_jobs_screen.dart`: blue header "Find Jobs" with back arrow, `StreamBuilder` on `JobService.getOpenJobs()`, list of `JobCard`, `BottomNavBar` with Home active.

- [ ] **Step 5:** Run tests; expect PASS. Run on emulator with seed data to confirm the feed renders.

- [ ] **Step 6:** Commit.

```bash
git add mobile/lib mobile/test
git commit -m "feat: find jobs feed with job cards and bottom nav"
```

### Task 4.3: Worker dashboard (job suggestions + availability)

**Files:**
- Create: `mobile/lib/ui/screens/worker/worker_dashboard_screen.dart`
- Create: `mobile/test/widget/worker_dashboard_test.dart`

- [ ] **Step 1:** Write smoke test (shows ranked job suggestions using `MatchingService.matchesJobToWorkers`).

- [ ] **Step 2:** Implement: on load, fetch the worker's `workers/{uid}` doc, fetch open jobs, run matching, show ranked list with distance + budget.

- [ ] **Step 3:** Run tests; expect PASS.

- [ ] **Step 4:** Commit.

```bash
git add mobile/lib mobile/test
git commit -m "feat: worker dashboard with matched job suggestions"
```

---

## Phase 5 — Job Requests & Job Lifecycle

> Goal: worker accepts/declines a job; user accepts/rejects worker offers; status transitions. Matches `docs/design/job-request.html`.

### Task 5.1: JobRequest model + request service

**Files:**
- Create: `mobile/lib/models/job_request.dart`
- Create: `mobile/lib/services/job_service.dart` (extend)
- Create: `mobile/test/unit/job_request_test.dart`

- [ ] **Step 1:** Write failing test (status transitions valid/invalid).

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:quickfix/models/job_request.dart';

void main() {
  test('valid transitions', () {
    const r = JobRequest(id: 'r1', jobId: 'j1', workerId: 'w1', userId: 'u1');
    expect(r.canTransitionTo(JobStatus.accepted), isTrue);
    expect(r.canTransitionTo(JobStatus.rejected), isTrue);
  });

  test('invalid transition', () {
    const r = JobRequest(id: 'r1', jobId: 'j1', workerId: 'w1', userId: 'u1',
        status: JobStatus.rejected);
    expect(r.canTransitionTo(JobStatus.accepted), isFalse);
  });
}
```

- [ ] **Step 2:** Run; expect FAIL.

- [ ] **Step 3:** Create model with an enum `JobStatus { pending, accepted, rejected, cancelled }` and a `canTransitionTo` guard.

- [ ] **Step 4:** Run; expect PASS.

- [ ] **Step 5:** Extend `job_service.dart`: `createJobRequest`, `respondToRequest` (accept/reject with `transaction` to prevent double-accept), `getJobRequestsForWorker`.

- [ ] **Step 6:** Commit.

```bash
git add mobile/lib mobile/test
git commit -m "feat: job request model with guarded status transitions"
```

### Task 5.2: Job Request screen + My Jobs (status tracking)

**Files:**
- Create: `mobile/lib/ui/screens/job_request/job_request_screen.dart`
- Create: `mobile/lib/ui/screens/my_jobs/my_jobs_screen.dart`
- Create: `mobile/test/widget/job_request_screen_test.dart`

- [ ] **Step 1:** Write smoke test (job title, client card, Accept/Decline buttons present).

- [ ] **Step 2:** Implement `job_request_screen.dart` per design:
  - Job detail card: yellow `#FFB800` avatar with wrench icon, title, description, `📍 Model Town, Lahore (2 km away)`, `💵 PKR 3,500`.
  - Two buttons: **Accept Job** (orange `#F36C00`), **Decline** (red `#E53935`).
  - Client info card: Client name, Rating `4.8 ★★★★★ (23 Reviews)`, Date.

- [ ] **Step 3:** Implement `my_jobs_screen.dart` with tabs/chips: Pending / In progress / Completed; each list item shows status chip and title.

- [ ] **Step 4:** Wire Accept → `respondToRequest(jobRequestId, JobStatus.accepted)` → update `jobs/{id}` status to `assigned`; Decline → `rejected`.

- [ ] **Step 5:** Run tests; expect PASS.

- [ ] **Step 6:** Commit.

```bash
git add mobile/lib mobile/test
git commit -m "feat: job request screen + my jobs status tracking"
```

---

## Phase 6 — Real-time Chat + Location Sharing

> Goal: user↔worker chat, with a share-location message type. Matches `docs/design/chat.html`.

### Task 6.1: Chat + Message models and chat service

**Files:**
- Create: `mobile/lib/models/chat.dart`
- Create: `mobile/lib/models/message.dart`
- Create: `mobile/lib/services/chat_service.dart`
- Create: `mobile/test/unit/message_model_test.dart`

- [ ] **Step 1:** Write failing model test (message fromJson for text and location types).

- [ ] **Step 2:** Run; expect FAIL.

- [ ] **Step 3:** Create `message.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessage {
  final String? id;
  final String chatId;
  final String senderId;
  final String text;
  final String type; // text | location
  final Map<String, dynamic>? location;
  final DateTime timestamp;

  const ChatMessage({
    this.id, required this.chatId, required this.senderId,
    this.text = '', this.type = 'text', this.location,
    required this.timestamp,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: json['id'] as String?,
        chatId: json['chatId'] as String,
        senderId: json['senderId'] as String,
        text: json['text'] as String? ?? '',
        type: json['type'] as String? ?? 'text',
        location: (json['location'] as Map?)?.cast<String, dynamic>(),
        timestamp: (json['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'chatId': chatId, 'senderId': senderId, 'text': text,
        'type': type, 'location': location,
        'timestamp': Timestamp.fromDate(timestamp),
      };
}
```

- [ ] **Step 4:** Run; expect PASS.

- [ ] **Step 5:** Implement `chat_service.dart`: `getOrCreateChat(userIds, jobId?)` (query by participant set), `streamMessages(chatId)`, `sendText`, `sendLocation` (uses `location_service`), `streamChatsForUser(uid)`, `markRead(chatId, uid)`.

- [ ] **Step 6:** Commit.

```bash
git add mobile/lib mobile/test
git commit -m "feat: chat + message models and chat service"
```

### Task 6.2: Chat list + Chat screen (per design)

**Files:**
- Create: `mobile/lib/ui/screens/chat/chat_list_screen.dart`
- Create: `mobile/lib/ui/screens/chat/chat_screen.dart`
- Create: `mobile/test/widget/chat_screen_test.dart`

- [ ] **Step 1:** Write smoke test (message bubbles and input bar present).

- [ ] **Step 2:** Implement `chat_screen.dart` per design:
  - Header: back arrow + contact name, `Icons.more_vert`.
  - Bubbles: outgoing `#0078D4` white text right-aligned; incoming white with border left-aligned; `rounded-2xl` with small corner radius on the tail side.
  - Location message renders a map-card (placeholder: gradient + centered red pin `Icons.location_pin`) with a timestamp; tapping opens the Maps app via `url_launcher` (`geo:` URI).
  - Input bar: rounded pill, "Type a message..." placeholder, 📎 button (attaches current location), circular send button `#004F9F`.

- [ ] **Step 3:** Implement `chat_list_screen.dart`: list of chats with last message preview + unread badge, tapping opens `ChatScreen`.

- [ ] **Step 4:** Add the location capture flow in `location_service.dart`: `getCurrentPosition` via `geolocator`, reverse-geocode label via `google_maps_flutter`/Geocoding, guarded by runtime permission + consent dialog.

- [ ] **Step 5:** Run tests; expect PASS. Test chat between two emulators/accounts.

- [ ] **Step 6:** Commit.

```bash
git add mobile/lib mobile/test
git commit -m "feat: real-time chat with location sharing messages"
```

---

## Phase 7 — Reviews & Multilingual Translation

> Goal: users rate workers and write Urdu/English reviews; reviews auto-translate to English via Cloud Translation API.

### Task 7.1: Review model + review service

**Files:**
- Create: `mobile/lib/models/review.dart`
- Create: `mobile/lib/services/review_service.dart`
- Create: `mobile/test/unit/review_model_test.dart`

- [ ] **Step 1:** Write failing test (review JSON round-trip, language tag default).

- [ ] **Step 2:** Run; expect FAIL.

- [ ] **Step 3:** Create `review.dart` with fields: `id, jobId, reviewerId, workerId, rating, originalText, originalLang, translatedText`.

- [ ] **Step 4:** Run; expect PASS.

- [ ] **Step 5:** Implement `review_service.dart`: `submitReview` (writes review + calls `Worker.addRating` on the worker doc in a `batch`), `getReviewsForWorker`.

- [ ] **Step 6:** Commit.

```bash
git add mobile/lib mobile/test
git commit -m "feat: review model + review submission service"
```

### Task 7.2: Translation service (Cloud Translation API)

**Files:**
- Create: `mobile/lib/services/translation_service.dart`
- Create: `mobile/test/unit/translation_service_test.dart`

- [ ] **Step 1:** Write failing test for the local fallback (detects Latin vs Urdu script).

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:quickfix/services/translation_service.dart';

void main() {
  test('isNonLatin detects Urdu script', () {
    expect(TranslationService.isNonLatin('بہت اچھا کام'), isTrue);
    expect(TranslationService.isNonLatin('great work'), isFalse);
  });

  test('local fallback passes through English text', () {
    final t = TranslationService();
    expect(t.translateLocally('great work'), 'great work');
  });
}
```

- [ ] **Step 2:** Run; expect FAIL.

- [ ] **Step 3:** Implement.

`mobile/lib/services/translation_service.dart`:
```dart
/// Translates review text to English.
/// Primary path calls the Cloud Translation API from the admin/backend proxy
/// (server-side key). Mobile falls back to a local script check so the
/// feature still works offline for demo purposes.
class TranslationService {
  Future<String> translate(String text, String targetLang) async {
    final isNonLatin = !RegExp(r'^[\x00-\x7F]+$').hasMatch(text);
    if (!isNonLatin) return text; // already ASCII/English

    // Real call: POST to your Cloud Functions/backend proxy endpoint
    // with { q: text, target: 'en' }. See Phase 8 backend note.
    // final resp = await http.post(...);
    return _localApprox(text);
  }

  static bool isNonLatin(String text) => !RegExp(r'^[\x00-\x7F]+$').hasMatch(text);

  String _localApprox(String text) => text; // offline demo placeholder
}
```

- [ ] **Step 4:** Run; expect PASS.

- [ ] **Step 5:** Implement the real call in `translate`:

```dart
Future<String> translate(String text, String targetLang) async {
  if (!isNonLatin(text)) return text;
  final resp = await http.post(
    Uri.parse(_proxyUrl), // admin backend proxy or Cloud Run endpoint
    body: jsonEncode({'q': text, 'target': targetLang}),
    headers: {'Content-Type': 'application/json'},
  );
  final data = jsonDecode(resp.body) as Map<String, dynamic>;
  return (data['translated'] as String?) ?? text;
}
```

`_proxyUrl` comes from `String.fromEnvironment('TRANSLATE_PROXY_URL')`.

- [ ] **Step 6:** Commit.

```bash
git add mobile/lib mobile/test
git commit -m "feat: review translation service with API + fallback"
```

### Task 7.3: Review screen + translated reviews UI

**Files:**
- Create: `mobile/lib/ui/screens/reviews/review_screen.dart`
- Create: `mobile/test/widget/review_screen_test.dart`

- [ ] **Step 1:** Write smoke test (rating stars selector, text field, submit).

- [ ] **Step 2:** Implement `review_screen.dart`: 5 tappable stars (yellow), review TextField (user writes in Urdu or English), submit button. On submit: call `translation_service.translate` then `review_service.submitReview`; show both original + translated text afterward.

- [ ] **Step 3:** Add a reviews list to `profile_screen.dart` showing `originalText` and `translatedText` ("Translated: …").

- [ ] **Step 4:** Run tests; expect PASS.

- [ ] **Step 5:** Commit.

```bash
git add mobile/lib mobile/test
git commit -m "feat: review screen with multilingual translation display"
```

---

## Phase 8 — Admin Web Dashboard

> Goal: React web app for moderation (users/workers/jobs) and analytics, with role-gated access.

### Task 8.1: Admin auth + routing

**Files:**
- Create: `admin/src/api/auth.ts`
- Create: `admin/src/pages/LoginPage.tsx`
- Create: `admin/src/App.tsx` (replace placeholder)
- Modify: `admin/src/config/firebase.ts`
- Create: `admin/.env.example`

- [ ] **Step 1:** Write `admin/src/config/firebase.ts` importing env vars (`VITE_FIREBASE_API_KEY`, etc.), `initializeApp`, `getAuth`, `getFirestore`.

- [ ] **Step 2:** Implement `auth.ts`: `signInWithEmailAndPassword`, `onAuthStateChanged`, and a guard that rejects non-admin users (checks `users/{uid}` role via a `getAdminRole` helper).

- [ ] **Step 3:** Create `LoginPage.tsx` styled with the QuickFix design system (blue bg, orange button) — mirror the mobile login layout.

- [ ] **Step 4:** Update `App.tsx` with `react-router-dom` routes: `/login`, `/` (redirect to dashboard), guarded by auth + admin role.

- [ ] **Step 5:** Verify: `npm run dev`, log in with an admin account, land on dashboard.

- [ ] **Step 6:** Commit.

```bash
cd admin
git add .
git commit -m "feat: admin login + role-gated routing"
```

### Task 8.2: Users, Workers, Jobs management tables

**Files:**
- Create: `admin/src/api/users.ts`
- Create: `admin/src/api/jobs.ts`
- Create: `admin/src/pages/UsersPage.tsx`
- Create: `admin/src/pages/WorkersPage.tsx`
- Create: `admin/src/pages/JobsPage.tsx`
- Create: `admin/src/components/DataTable.tsx`

- [ ] **Step 1:** Implement `users.ts`/`jobs.ts` with Firestore list/subscribe helpers and `blockUser(uid)`, `approveWorker(uid)`, `deleteJob(id)`.

- [ ] **Step 2:** Build `DataTable.tsx`: generic table with columns config, pagination (simple 50-row slice), and an actions slot.

- [ ] **Step 3:** Build the three pages using `DataTable`:
  - **Users:** columns name/email/phone/status; actions Block/Unblock.
  - **Workers:** columns name/skills/rating/completed jobs; actions Approve/Block.
  - **Jobs:** columns title/category/status/created; actions View, Cancel.

- [ ] **Step 4:** Verify manually in browser against Firestore seed data.

- [ ] **Step 5:** Commit.

```bash
git add .
git commit -m "feat: admin tables for users, workers, jobs with moderation actions"
```

### Task 8.3: Reports + analytics dashboard

**Files:**
- Create: `admin/src/api/reports.ts`
- Create: `admin/src/pages/ReportsPage.tsx`
- Create: `admin/src/pages/AnalyticsPage.tsx`
- Create: `admin/src/components/StatCard.tsx`

- [ ] **Step 1:** Implement `reports.ts` (list open reports, resolve/dismiss).

- [ ] **Step 2:** Build `ReportsPage.tsx`: table of reports (reportedBy, reported user, reason, status) with Resolve/Dismiss actions.

- [ ] **Step 3:** Build `AnalyticsPage.tsx`: `StatCard` grid (Total users, Active jobs, Worker count, Platform activity) from Firestore `count`-style queries or an aggregate `analytics` doc maintained by a Cloud Function.

- [ ] **Step 4:** Verify in browser.

- [ ] **Step 5:** Commit.

```bash
git add .
git commit -m "feat: reports page + analytics dashboard"
```

### Task 8.4: Translation proxy endpoint

**Files:**
- Create: `backend/functions/index.js` (or a simple Node/Express service)
- Modify: `admin/.env.example` (add `GOOGLE_TRANSLATE_API_KEY`)

- [ ] **Step 1:** Create a minimal Node HTTP service (`backend/functions/` using Firebase Functions or plain Express) exposing `POST /translate` with `{ q, target }`. Server-side calls Google Cloud Translation with the service API key (never shipped to mobile).

- [ ] **Step 2:** Deploy to Firebase Functions (or run locally). Document the deployed URL.

- [ ] **Step 3:** Update `mobile/lib/services/translation_service.dart` `_proxyUrl` to the deployed endpoint.

- [ ] **Step 4:** Verify a real Urdu→English translation round-trips in the app.

- [ ] **Step 5:** Commit.

```bash
git add backend admin
git commit -m "feat: server-side translation proxy using Cloud Translation API"
```

---

## Phase 9 — Mock Payments, Polish & Final QA

> Goal: mock payment simulation, seed data, edge-case hardening, and full acceptance testing.

### Task 9.1: Mock payment service + screen

**Files:**
- Create: `mobile/lib/services/payment_service.dart`
- Create: `mobile/lib/models/payment.dart`
- Create: `mobile/lib/ui/screens/payments/mock_payment_screen.dart`
- Create: `mobile/test/unit/payment_model_test.dart`

- [ ] **Step 1:** Write failing test (payment serialization + status 'paid').

- [ ] **Step 2:** Run; expect FAIL.

- [ ] **Step 3:** Create `payment.dart` model.

- [ ] **Step 4:** Run; expect PASS.

- [ ] **Step 5:** Implement `payment_service.dart`: `simulatePayment(jobId, amount)` writes a `payments/{id}` doc with status `paid` after a 1.5s fake processing delay.

- [ ] **Step 6:** Build `mock_payment_screen.dart`: shows job summary, amount, "Pay PKR X (Mock)" orange button, success sheet on completion.

- [ ] **Step 7:** Run tests; expect PASS.

- [ ] **Step 8:** Commit.

```bash
git add mobile/lib mobile/test
git commit -m "feat: mock payment flow"
```

### Task 9.2: Seed data + offline support

**Files:**
- Create: `backend/seed/seed.dart` or a Firestore import script
- Modify: `mobile/lib/core/utils/offline_cache.dart`

- [ ] **Step 1:** Write a seed script that creates: 8 categories, 12 users, 8 workers (across Lahore/Islamabad/Rawalpindi), 15 jobs, and a sample chat + reviews. Run it against Firestore.

- [ ] **Step 2:** Verify the mobile app renders seeded data in Find Jobs, My Jobs, Worker dashboard.

- [ ] **Step 3:** Add `offline_cache.dart` using `shared_preferences` to cache job feed + categories; Firestore offline persistence is enabled via `Firestore.instance.enablePersistence`.

- [ ] **Step 4:** Commit.

```bash
git add backend mobile/lib
git commit -m "feat: seed data script + offline caching"
```

### Task 9.3: Final acceptance pass

**Files:** none (QA + fixes only)

- [ ] **Step 1:** Run the full test suites and `flutter analyze`:

```bash
cd mobile
flutter test
flutter analyze
cd ../admin
npm run build
```

- [ ] **Step 2:** Execute the acceptance checklist (below) and fix every failure found.

### Acceptance Checklist

1. Register as User → choose role → profile created.
2. Post a job with a photo → ML Kit suggests a correct category (e.g., faucet → Plumbing).
3. Worker sees the job in their matched dashboard with distance.
4. Worker Accepts → User sees "In progress" in My Jobs.
5. Chat: both parties exchange text; location share renders a map card.
6. User writes a review in Urdu → translation appears under the original.
7. Admin logs in, blocks a user, resolves a report, views analytics.
8. Mock payment completes and marks job Paid.
9. App loads jobs < 3s on normal network (spot-check with a stopwatch).
10. No background location tracking (permission only granted during explicit share).

- [ ] **Step 3:** Final commit and tag:

```bash
git add .
git commit -m "chore: final QA fixes"
git tag v1.0.0
```

---

## Cross-Cutting: Testing Strategy

- **Unit tests** (`mobile/test/unit/`): models (serialization, transitions) and pure logic (matching, translation fallback). Use `mocktail` for Firebase service mocks.
- **Widget tests** (`mobile/test/widget/`): one smoke test per screen verifying key elements exist. Run with `flutter test`.
- **Admin tests** (`admin/test/`): minimal — use Vitest + React Testing Library for `DataTable` and auth guard.
- **Manual QA** per phase: run on an Android emulator, verify against the design HTML in `docs/design/`.
- **Continuous**: `flutter analyze` must pass with zero errors before each commit.
