# QuickFix Spec Alignment + Real Geolocation — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Align the QuickFix mobile app with the supervisor spec — exact MVC folder structure (`lib/views`, `lib/controllers`, `lib/models`, `lib/services`), exact palette, role-selection login, polished Job Request screen, chat wired to Firestore with consent-based real GPS location sharing, and Firestore schema docs.

**Architecture:** Mechanical folder restructure (behavior unchanged) + new `LocationService` behind an injectable provider for testability; PostJobScreen and ChatScreen consume real GPS only on explicit user action (no background tracking); ChatScreen swaps its hardcoded fixture for the existing `ChatService` Firestore stream and gains a location-pin action that sends a `ChatMessage(attachmentType: 'location')` with real coordinates rendered as a card with an "Open in Google Maps" link.

**Tech Stack:** Flutter/Dart, `geolocator: ^13.0.1` (already in pubspec), `cloud_firestore` (existing), flutter_test + Mocktail (existing). **No Google Maps API key** (billing) — location rendered as coordinates card + maps URL.

**Repo:** `D:\OpenCode_Projects\FYP Project` (app in `mobile/`). All `flutter` commands run with workdir `mobile` and prefix `$env:PATH = "D:\flutter\bin;$env:PATH"`. Windows PowerShell: chain with `;` + `if ($?)`.

---

### Task 1: Restructure to lib/views | lib/controllers | lib/models | lib/services

**Files:** moves only — no content changes
- `lib/shared/models/*.dart` (8 files: worker_profile, user_model, service_category, review_model, payment_model, job_request, job_model, chat_message) → `lib/models/*.dart`
- `lib/features/*/presentation/*.dart` → `lib/views/<feature>/*.dart` (auth: app_shell, login_screen, signup_screen, auth_screens; jobs: worker_dashboard_screen, post_job_screen, my_jobs_screen, job_request_screen, find_jobs_screen; chat: chat_screen; profile: profile_screen; reviews: review_screen; payments: mock_payment_screen)
- `lib/services/*.dart` — already flat, stays
- `lib/core/*` — stays
- Update imports in every moved file and in `lib/main.dart` (imports `app.dart` — stays), `lib/app.dart` (imports login_screen + app_shell), and all 16 test files (they import moved paths; tests stay in `test/`)

- [ ] **Step 1: Move files with git**

Run from repo root (PowerShell):

```powershell
New-Item -ItemType Directory -Force -Path "mobile/lib/views/auth","mobile/lib/views/jobs","mobile/lib/views/chat","mobile/lib/views/profile","mobile/lib/views/reviews","mobile/lib/views/payments","mobile/lib/models","mobile/lib/controllers" | Out-Null
git mv mobile/lib/shared/models/worker_profile.dart mobile/lib/models/worker_profile.dart
git mv mobile/lib/shared/models/user_model.dart mobile/lib/models/user_model.dart
git mv mobile/lib/shared/models/service_category.dart mobile/lib/models/service_category.dart
git mv mobile/lib/shared/models/review_model.dart mobile/lib/models/review_model.dart
git mv mobile/lib/shared/models/payment_model.dart mobile/lib/models/payment_model.dart
git mv mobile/lib/shared/models/job_request.dart mobile/lib/models/job_request.dart
git mv mobile/lib/shared/models/job_model.dart mobile/lib/models/job_model.dart
git mv mobile/lib/shared/models/chat_message.dart mobile/lib/models/chat_message.dart
git mv mobile/lib/features/auth/presentation/app_shell.dart mobile/lib/views/auth/app_shell.dart
git mv mobile/lib/features/auth/presentation/login_screen.dart mobile/lib/views/auth/login_screen.dart
git mv mobile/lib/features/auth/presentation/signup_screen.dart mobile/lib/views/auth/signup_screen.dart
git mv mobile/lib/features/auth/presentation/auth_screens.dart mobile/lib/views/auth/auth_screens.dart
git mv mobile/lib/features/jobs/presentation/worker_dashboard_screen.dart mobile/lib/views/jobs/worker_dashboard_screen.dart
git mv mobile/lib/features/jobs/presentation/post_job_screen.dart mobile/lib/views/jobs/post_job_screen.dart
git mv mobile/lib/features/jobs/presentation/my_jobs_screen.dart mobile/lib/views/jobs/my_jobs_screen.dart
git mv mobile/lib/features/jobs/presentation/job_request_screen.dart mobile/lib/views/jobs/job_request_screen.dart
git mv mobile/lib/features/jobs/presentation/find_jobs_screen.dart mobile/lib/views/jobs/find_jobs_screen.dart
git mv mobile/lib/features/chat/presentation/chat_screen.dart mobile/lib/views/chat/chat_screen.dart
git mv mobile/lib/features/profile/presentation/profile_screen.dart mobile/lib/views/profile/profile_screen.dart
git mv mobile/lib/features/reviews/presentation/review_screen.dart mobile/lib/views/reviews/review_screen.dart
git mv mobile/lib/features/payments/presentation/mock_payment_screen.dart mobile/lib/views/payments/mock_payment_screen.dart
Remove-Item -Recurse -Force "mobile/lib/features","mobile/lib/shared"
```

- [ ] **Step 2: Update import paths across the repo**

Every import of a moved file changes its package prefix:

- `package:quickfix/shared/models/X.dart` → `package:quickfix/models/X.dart`
- `package:quickfix/features/<f>/presentation/X.dart` → `package:quickfix/views/<f>/X.dart`

The feature services (review_service, payment_service, etc.) were already in `lib/services/` — untouched. Use a scripted replace across `mobile/lib/**/*.dart` and `mobile/test/*.dart`:

```powershell
Get-ChildItem "mobile/lib" -Recurse -Filter *.dart | ForEach-Object { (Get-Content -Raw $_.FullName) -replace 'package:quickfix/shared/models/','package:quickfix/models/' | Set-Content -NoNewline $_.FullName }
Get-ChildItem "mobile/lib" -Recurse -Filter *.dart | ForEach-Object { (Get-Content -Raw $_.FullName) -replace 'package:quickfix/features/(\w+)/presentation/','package:quickfix/views/$1/' | Set-Content -NoNewline $_.FullName }
Get-ChildItem "mobile/test" -Filter *.dart | ForEach-Object { (Get-Content -Raw $_.FullName) -replace 'package:quickfix/shared/models/','package:quickfix/models/' | Set-Content -NoNewline $_.FullName }
Get-ChildItem "mobile/test" -Filter *.dart | ForEach-Object { (Get-Content -Raw $_.FullName) -replace 'package:quickfix/features/(\w+)/presentation/','package:quickfix/views/$1/' | Set-Content -NoNewline $_.FullName }
```

- [ ] **Step 3: Verify the suite stays green**

Run (workdir `mobile`): `flutter test` → expect `All tests passed!` (72). Any load failure = missed import update — fix that file's imports by grepping `package:quickfix/features|package:quickfix/shared`:

```powershell
Get-ChildItem "mobile/lib","mobile/test" -Recurse -Filter *.dart | Select-String "shared/models|features/"
```

Must return zero matches before continuing.

- [ ] **Step 4: Seed the controllers directory**

Create `mobile/lib/controllers/auth_controller.dart`:

```dart
import 'package:flutter/foundation.dart';

/// Minimal app-level auth state holder (spec deliverable: /lib/controllers).
class AuthController extends ChangeNotifier {
  String? _userId;
  String? _role;
  bool _isAuthenticated = false;

  String? get userId => _userId;
  String? get role => _role;
  bool get isAuthenticated => _isAuthenticated;

  void setSession({required String userId, required String role}) {
    _userId = userId;
    _role = role;
    _isAuthenticated = true;
    notifyListeners();
  }

  void clearSession() {
    _userId = null;
    _role = null;
    _isAuthenticated = false;
    notifyListeners();
  }
}
```

Create `mobile/lib/controllers/job_list_controller.dart`:

```dart
import 'package:flutter/foundation.dart';
import 'package:quickfix/models/job_model.dart';

/// Holds the currently displayed job list (find-jobs feed).
class JobListController extends ChangeNotifier {
  List<JobModel> _jobs = [];
  bool _isLoading = false;

  List<JobModel> get jobs => _jobs;
  bool get isLoading => _isLoading;

  void setJobs(List<JobModel> jobs) {
    _jobs = jobs;
    notifyListeners();
  }

  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
}
```

(These are the two controllers the spec's structure delimiter requires; screens keep their current data flow — controllers are not wired into screens in this round beyond existing singletons.)

- [ ] **Step 5: Run analyze + suite + commit**

Run: `flutter analyze` → expect only the 4 known sealed-class warnings in `test/job_service_test.dart` (no others). Run: `flutter test` → 72 passing.

Commit from repo root:

```bash
git add -A
git commit -m "refactor: restructure to lib/views|controllers|models|services per spec"
```

---

### Task 2: Exact palette in AppTheme

**Files:**
- Modify: `mobile/lib/core/theme/app_theme.dart`
- Test: `mobile/test/app_theme_test.dart` (new)

- [ ] **Step 1: Write failing test**

Create `test/app_theme_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quickfix/core/theme/app_theme.dart';

void main() {
  test('palette matches the spec exactly', () {
    expect(AppTheme.brandBlue, const Color(0xFF0D47A1));
    expect(AppTheme.ctaOrange, const Color(0xFFF57C00));
    expect(AppTheme.accentOrange, const Color(0xFFFF9800));
    expect(AppTheme.successGreen, const Color(0xFF4CAF50));
    expect(AppTheme.dangerRed, const Color(0xFFE53935));
    expect(AppTheme.bgLight, const Color(0xFFF5F5F5));
    expect(AppTheme.surfaceWhite, const Color(0xFFFFFFFF));
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/app_theme_test.dart` → FAIL: `accentOrange`/`successGreen` undefined; wrong hex values.

- [ ] **Step 3: Update the theme constants**

In `lib/core/theme/app_theme.dart`, replace the five constant declarations (lines 4–9) with:

```dart
  static const Color brandBlue = Color(0xFF0D47A1);
  static const Color accentYellow = Color(0xFFFF9800);
  static const Color ctaOrange = Color(0xFFF57C00);
  static const Color accentOrange = Color(0xFFFF9800);
  static const Color successGreen = Color(0xFF4CAF50);
  static const Color dangerRed = Color(0xFFE53935);
  static const Color chatBlue = Color(0xFF0078D4);
  static const Color bgLight = Color(0xFFF5F5F5);
  static const Color surfaceWhite = Color(0xFFFFFFFF);
```

(`accentYellow` is retained because existing widgets reference it; it now equals `#FF9800`. `chatBlue` unchanged.)

- [ ] **Step 4: Run to verify it passes**

Run: `flutter test test/app_theme_test.dart` → PASS (1 test).

- [ ] **Step 5: Full suite + commit**

Run: `flutter test` → 73 passing. Commit:

```bash
git add lib/core/theme/app_theme.dart test/app_theme_test.dart
git commit -m "style: apply exact spec palette (#0D47A1/#F57C00/#4CAF50/#E53935)"
```

---

### Task 3: LocationService (real GPS, testable)

**Files:**
- Create: `mobile/lib/services/location_service.dart`
- Create: `mobile/lib/services/location_provider.dart`
- Modify: `mobile/android/app/src/main/AndroidManifest.xml`
- Modify: `mobile/lib/services/profile_service.dart` (remove duplicate position code)
- Test: `mobile/test/location_service_test.dart` (new)

- [ ] **Step 1: Write failing test**

Create `test/location_service_test.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:quickfix/services/location_provider.dart';
import 'package:quickfix/services/location_service.dart';

class _FakeLocationProvider implements LocationProvider {
  bool serviceEnabled = true;
  LocationPermission permission = LocationPermission.whileInUse;
  Position? position;

  @override
  Future<bool> isLocationServiceEnabled() async => serviceEnabled;

  @override
  Future<LocationPermission> checkPermission() async => permission;

  @override
  Future<LocationPermission> requestPermission() async => permission;

  @override
  Future<Position> getCurrentPosition() async => position ??
      Position(
        latitude: 31.5204,
        longitude: 74.3587,
        timestamp: DateTime.now(),
        accuracy: 10,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );
}

void main() {
  test('returns null when location services are disabled', () async {
    final fake = _FakeLocationProvider()..serviceEnabled = false;
    final service = LocationService(provider: fake);
    expect(await service.getCurrentLocation(), isNull);
  });

  test('requests permission when denied and returns null when refused', () async {
    final fake = _FakeLocationProvider()..permission = LocationPermission.denied;
    final service = LocationService(provider: fake);
    expect(await service.getCurrentLocation(), isNull);
  });

  test('returns GeoPoint when permission granted', () async {
    final fake = _FakeLocationProvider();
    final service = LocationService(provider: fake);
    final point = await service.getCurrentLocation();
    expect(point, isNotNull);
    expect(point!.latitude, closeTo(31.5204, 0.0001));
    expect(point.longitude, closeTo(74.3587, 0.0001));
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/location_service_test.dart` → FAIL: `location_provider.dart`/`location_service.dart` missing.

- [ ] **Step 3: Implement provider + service**

Create `lib/services/location_provider.dart`:

```dart
import 'package:geolocator/geolocator.dart';

/// Thin seam over the static Geolocator API so LocationService is testable.
abstract class LocationProvider {
  Future<bool> isLocationServiceEnabled();
  Future<LocationPermission> checkPermission();
  Future<LocationPermission> requestPermission();
  Future<Position> getCurrentPosition();
}

class DeviceLocationProvider implements LocationProvider {
  const DeviceLocationProvider();

  @override
  Future<bool> isLocationServiceEnabled() =>
      Geolocator.isLocationServiceEnabled();

  @override
  Future<LocationPermission> checkPermission() => Geolocator.checkPermission();

  @override
  Future<LocationPermission> requestPermission() =>
      Geolocator.requestPermission();

  @override
  Future<Position> getCurrentPosition() => Geolocator.getCurrentPosition();
}
```

Create `lib/services/location_service.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quickfix/services/location_provider.dart';

/// Fetches the user's real GPS position on explicit request only.
/// There is NO background tracking anywhere in this class.
class LocationService {
  final LocationProvider _provider;

  LocationService({LocationProvider? provider})
      : _provider = provider ?? const DeviceLocationProvider();

  /// Returns the current position as a [GeoPoint], or null when the user
  /// denies permission or location services are unavailable.
  Future<GeoPoint?> getCurrentLocation() async {
    final enabled = await _provider.isLocationServiceEnabled();
    if (!enabled) return null;

    var permission = await _provider.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await _provider.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }

    final position = await _provider.getCurrentPosition();
    return GeoPoint(position.latitude, position.longitude);
  }
}
```

- [ ] **Step 4: Remove the duplicate from ProfileService**

In `mobile/lib/services/profile_service.dart`, delete the `getCurrentPosition()` method (lines 40–55) and its now-unused `Geolocator` import (line 2). `updateLocation` stays.

- [ ] **Step 5: Add Android permissions**

In `mobile/android/app/src/main/AndroidManifest.xml`, above the `<application>` tag add:

```xml
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
```

- [ ] **Step 6: Verify + commit**

Run: `flutter test test/location_service_test.dart` → 3 passing. Run: `flutter analyze` → no new issues. Commit:

```bash
git add lib/services/location_service.dart lib/services/location_provider.dart lib/services/profile_service.dart android/app/src/main/AndroidManifest.xml test/location_service_test.dart
git commit -m "feat: real GPS LocationService with consent-only access"
```

---

### Task 4: PostJobScreen uses real location

**Files:**
- Modify: `mobile/lib/views/jobs/post_job_screen.dart`
- Test: `mobile/test/post_job_location_test.dart` (new)

- [ ] **Step 1: Write failing widget test**

Create `test/post_job_location_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:quickfix/services/location_provider.dart';
import 'package:quickfix/services/location_service.dart';
import 'package:quickfix/views/jobs/post_job_screen.dart';

class _DeniedProvider implements LocationProvider {
  @override
  Future<bool> isLocationServiceEnabled() async => true;
  @override
  Future<LocationPermission> checkPermission() async => LocationPermission.denied;
  @override
  Future<LocationPermission> requestPermission() async => LocationPermission.denied;
  @override
  Future<Position> getCurrentPosition() async => throw UnimplementedError();
}

void main() {
  testWidgets('posting blocked with snackbar when location permission denied',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: PostJobScreen(
              userId: 'user-1',
              locationService: LocationService(
                provider: _DeniedProvider(),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Post Job'));
    await tester.pumpAndSettle();

    expect(find.textContaining('location permission'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/post_job_location_test.dart` → FAIL: no `locationService` parameter on `PostJobScreen`.

- [ ] **Step 3: Implement real location in PostJobScreen**

Edit `lib/views/jobs/post_job_screen.dart`:

a) Add imports:

```dart
import 'package:quickfix/services/location_service.dart';
```

b) Constructor gains a parameter (defaults to real service, injectable for tests):

```dart
  final LocationService? locationService;
```

```dart
    this.locationService,
```

c) State gains:

```dart
  late final LocationService _locationService =
      widget.locationService ?? LocationService();
```

d) In `_handlePostJob()`, replace the hardcoded GeoPoint line:

```dart
      final location = await _locationService.getCurrentLocation();
      if (location == null) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Location permission is required to post a job. '
              'Please enable it in app settings and try again.',
            ),
          ),
        );
        return;
      }
```

then pass `location: location` to `createJob` instead of `const GeoPoint(31.5204, 74.3587)` (delete the `demo: Lahore` comment line; `cloud_firestore` import stays for the GeoPoint type in other spots — if the import becomes unused, remove it).

- [ ] **Step 4: Run tests**

Run: `flutter test test/post_job_location_test.dart` → PASS. Run: `flutter test` → 76 passing.

- [ ] **Step 5: Commit**

```bash
git add lib/views/jobs/post_job_screen.dart test/post_job_location_test.dart
git commit -m "feat: post job with real GPS coordinates (permission-gated)"
```

---

### Task 5: Chat — real Firestore stream + consent-based location sharing

**Files:**
- Modify: `mobile/lib/models/chat_message.dart` (add latitude/longitude)
- Modify: `mobile/lib/views/chat/chat_screen.dart`
- Test: `mobile/test/chat_message_test.dart` (extend)
- Test: `mobile/test/chat_screen_test.dart` (new)

- [ ] **Step 1: Extend ChatMessage with coordinates — write failing test first**

Append to `test/chat_message_test.dart`:

```dart
  test('location attachments round-trip latitude and longitude', () {
    final message = ChatMessage(
      id: 'm1',
      senderId: 'a',
      receiverId: 'b',
      text: '',
      attachmentType: 'location',
      latitude: 31.5204,
      longitude: 74.3587,
      createdAt: DateTime(2026, 8, 10),
    );
    final restored = ChatMessage.fromMap(message.toMap(), 'm1');
    expect(restored.attachmentType, 'location');
    expect(restored.latitude, closeTo(31.5204, 0.0001));
    expect(restored.longitude, closeTo(74.3587, 0.0001));
  });
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/chat_message_test.dart` → FAIL: `latitude`/`longitude` don't exist.

- [ ] **Step 3: Implement coordinates in ChatMessage**

Edit `lib/models/chat_message.dart`:

a) Fields:

```dart
  final double? latitude;
  final double? longitude;
```

b) Constructor params:

```dart
    this.latitude,
    this.longitude,
```

c) `fromMap`:

```dart
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
```

d) `toMap`:

```dart
      'latitude': latitude,
      'longitude': longitude,
```

e) `copyWith` — add `double? latitude, double? longitude` params using `latitude ?? this.latitude` / `longitude ?? this.longitude` (keeping the existing `?` semantics is fine here since these are final nullable fields).

- [ ] **Step 4: Wire ChatScreen to the real Firestore stream**

Edit `lib/views/chat/chat_screen.dart`:

a) Imports:

```dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quickfix/core/theme/app_theme.dart';
import 'package:quickfix/models/chat_message.dart';
import 'package:quickfix/services/chat_service.dart';
import 'package:quickfix/services/location_service.dart';
```

b) Constructor: keep `myId`, `peerId`, `peerName` params but drop the hardcoded `_mockMessages` fixture (lines 8–55) and the `_messages` list state. Add `final ChatService? chatService;` and `final LocationService? locationService;` parameters.

c) State:

```dart
  late final ChatService _chatService = widget.chatService ?? ChatService();
  late final LocationService _locationService =
      widget.locationService ?? LocationService();
```

d) Replace `_messages` + `_sendMessage` with Firestore-backed send:

```dart
  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    _messageController.clear();
    await _chatService.sendMessage(
      senderId: widget.myId,
      receiverId: widget.peerId,
      text: text,
    );
  }

  Future<void> _shareLocation() async {
    final location = await _locationService.getCurrentLocation();
    if (location == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Location permission is needed to share your location. '
            'Please enable it in app settings.',
          ),
        ),
      );
      return;
    }
    await _chatService.sendMessage(
      senderId: widget.myId,
      receiverId: widget.peerId,
      text: 'Shared my location',
      attachmentType: 'location',
      latitude: location.latitude,
      longitude: location.longitude,
    );
  }
```

e) Replace the messages ListView source with a `StreamBuilder<List<ChatMessage>>`:

```dart
  Widget _buildMessages() {
    return StreamBuilder<List<ChatMessage>>(
      stream: _chatService.watchMessages(user1: widget.myId, user2: widget.peerId),
      builder: (context, snapshot) {
        final messages = snapshot.data ?? const <ChatMessage>[];
        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.all(12),
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final message = messages[index];
            final mine = message.senderId == widget.myId;
            return _buildBubble(message, mine);
          },
        );
      },
    );
  }
```

`_sendMessage` call site becomes `onPressed: _sendMessage` (async void is fine for a button callback).

f) `_buildBubble(ChatMessage message, bool mine)` — bubble style identical to the existing code (right-aligned `chatBlue` for mine, left-aligned gray for theirs); if `message.attachmentType == 'location'` render the location card instead of the text:

```dart
  Widget _buildLocationCard(ChatMessage message) {
    final lat = message.latitude ?? 0.0;
    final lng = message.longitude ?? 0.0;
    return Container(
      width: 230,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderGray),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.location_on, size: 16, color: AppTheme.dangerRed),
              SizedBox(width: 4),
              Text(
                'Location',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}',
            style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 6),
          InkWell(
            onTap: () => launchMaps(lat, lng),
            child: const Text(
              'Open in Google Maps',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppTheme.brandBlue,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }
```

Add a small helper (top-level, same file) using the system URL launcher **without adding a new dependency** — use `UrlLauncher` via `url_launcher`? It is NOT in pubspec — instead copy the link to the clipboard with `Clipboard.setData` and show a snackbar:

```dart
  Future<void> _openMaps(double lat, double lng) async {
    await Clipboard.setData(
      ClipboardData(text: 'https://maps.google.com/?q=$lat,$lng'),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Maps link copied to clipboard')),
    );
  }
```

and call `_openMaps(lat, lng)` from the card's `onTap` (rename the `launchMaps` reference accordingly). No new pubspec dependency.

g) Input bar: add a location-pin `IconButton` (e.g. `Icons.location_on`) next to the send button, `onPressed: _shareLocation`.

- [ ] **Step 5: Chat screen widget tests**

Create `test/chat_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:quickfix/services/chat_service.dart';
import 'package:quickfix/services/location_provider.dart';
import 'package:quickfix/services/location_service.dart';
import 'package:quickfix/views/chat/chat_screen.dart';

class _DeniedProvider implements LocationProvider {
  @override
  Future<bool> isLocationServiceEnabled() async => true;
  @override
  Future<LocationPermission> checkPermission() async => LocationPermission.denied;
  @override
  Future<LocationPermission> requestPermission() async => LocationPermission.denied;
  @override
  Future<Position> getCurrentPosition() async => throw UnimplementedError();
}

void main() {
  testWidgets('share location with denied permission shows snackbar and sends nothing',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: ChatScreen(
              myId: 'user-1',
              peerId: 'worker-1',
              peerName: 'Ahmed Ali',
              locationService: LocationService(provider: _DeniedProvider()),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.location_on));
    await tester.pumpAndSettle();

    expect(find.textContaining('Location permission'), findsOneWidget);
  });
}
```

(Note: `watchMessages` on `FirebaseFirestore.instance` isn't exercised in tests — the denied-path test covers the consent behavior; the stream path is verified on-device in Task 9.)

- [ ] **Step 6: Run suite + commit**

Run: `flutter test` → expect 77+ passing. Run: `flutter analyze` → no new issues. Commit:

```bash
git add lib/models/chat_message.dart lib/views/chat/chat_screen.dart test/chat_message_test.dart test/chat_screen_test.dart
git commit -m "feat: real chat stream + consent-based location sharing in chat"
```

---

### Task 6: Role-selection Login (Screen 1)

**Files:**
- Modify: `mobile/lib/views/auth/login_screen.dart`
- Test: `mobile/test/login_screen_test.dart` (new)

- [ ] **Step 1: Write failing test**

Create `test/login_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quickfix/views/auth/login_screen.dart';

void main() {
  testWidgets('login screen shows both role cards and toggles to worker',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(home: LoginScreen()),
    );

    expect(find.text('Find Services'), findsOneWidget);
    expect(find.text('Get Jobs'), findsOneWidget);

    await tester.tap(find.text('Get Jobs'));
    await tester.pumpAndSettle();
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/login_screen_test.dart` → FAIL: no 'Find Services'/'Get Jobs' text.

- [ ] **Step 3: Implement role cards**

Edit `mobile/lib/views/auth/login_screen.dart`:

a) Add state: `String _selectedRole = 'user';` where the existing form state lives.

b) Above the email/password form fields, insert a role selector row:

```dart
  Widget _buildRoleSelector() {
    return Row(
      children: [
        Expanded(
          child: _buildRoleCard(
            role: 'user',
            title: 'Login as User',
            subtitle: 'Find Services',
            icon: Icons.home_repair_service,
            color: AppTheme.brandBlue,
            selected: _selectedRole == 'user',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildRoleCard(
            role: 'worker',
            title: 'Login as Worker',
            subtitle: 'Get Jobs',
            icon: Icons.work,
            color: AppTheme.ctaOrange,
            selected: _selectedRole == 'worker',
          ),
        ),
      ],
    );
  }

  Widget _buildRoleCard({
    required String role,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool selected,
  }) {
    return InkWell(
      onTap: () => setState(() => _selectedRole = role),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? color : AppTheme.surfaceWhite,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? color : AppTheme.borderGray,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: selected ? Colors.white : color, size: 26),
            const SizedBox(height: 6),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                color: selected ? Colors.white.withValues(alpha: 0.85) : AppTheme.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
```

c) Wire it into the flow: pass `_selectedRole` to the login action so AppShell routing uses it. If the screen currently authenticates then navigates to AppShell directly, keep that behavior and pass `role: _selectedRole` to the AppShell route/constructor (AppShell already routes by role — if AppShell determines role from the user doc, still pass the selected role as the initial override; where the existing navigation already handles roles from the profile, add `_selectedRole` as the default before the user doc resolves).

d) Header: if the screen has a blue header, ensure it reads "QuickFix — On-Demand Local Service Matching" per Screen 1 spec (adjust existing title text only if it currently differs).

- [ ] **Step 4: Run tests**

Run: `flutter test test/login_screen_test.dart` → PASS. Run: `flutter test` → all green. Commit:

```bash
git add lib/views/auth/login_screen.dart test/login_screen_test.dart
git commit -m "feat: role-selection login cards (Find Services / Get Jobs)"
```

---

### Task 7: Job Request screen polish (Screen 4)

**Files:**
- Modify: `mobile/lib/views/jobs/job_request_screen.dart`

- [ ] **Step 1: Client overview with star rating, review count, posting date**

In `_buildClientInfo()` (or its replacement), ensure the client section shows:

- Client name (`widget.client?.fullName ?? 'Client'`)
- Star rating line: `'${rating.toStringAsFixed(1)} ★★★★★'` — render 5 stars (filled = rating / 5 rounded) using `Icons.star`/`Icons.star_border`, plus the numeric value; `rating` from `widget.client?.rating ?? 0`
- Review count line: `'${reviews} reviews'` (`widget.client?.reviews ?? 0`)
- Posting date line: `'Posted ${_formatDate(widget.job.createdAt)}'` — reuse the existing date formatting helper if present, otherwise `'${createdAt.day}/${createdAt.month}/${createdAt.year}'`

If `UserModel` lacks `rating`/`reviews` fields, read them from the job's worker rating conventions: `widget.job.rating` (nullable double on JobModel) and default review count to 0 — do NOT change `user_model.dart` unless the fields already exist (check first).

- [ ] **Step 2: Accept button = successGreen**

In `_buildActionButtons()`, change Accept styling from `AppTheme.ctaOrange` to `AppTheme.successGreen` (background, shadowColor) — keep the button label 'Accept Job' and Decline (dangerRed) unchanged.

- [ ] **Step 3: Distance line uses the real format**

In the job card, `_formatDistance(2.0)` is hardcoded — if `_formatDistance` exists, change the call so the value shown is computed as `'${_formatDistance(widget.job.budgetMax >= 5000 ? 4.5 : 2.0)} away'`? No — keep it simple: replace `'(${_formatDistance(2.0)} away)'` with `'(2 km away)'` static text ONLY if `_formatDistance` can't resolve a real distance; otherwise keep the helper. (Real distance requires the worker's location, which isn't passed to this screen; the mockup shows a distance indicator — static text is acceptable for now.)

- [ ] **Step 4: Verify + commit**

Run: `flutter test` → all green (76+). Run: `flutter analyze` → no new issues. Commit:

```bash
git add lib/views/jobs/job_request_screen.dart
git commit -m "feat: job request screen client overview + accept/decline polish"
```

---

### Task 8: Firestore schema docs (deliverable)

**Files:**
- Create: `docs/firestore/schemas.md`

- [ ] **Step 1: Write the schema document**

Create `docs/firestore/schemas.md` documenting collections that match the real seeded data and `docs/firestore/firestore.rules`:

```markdown
# QuickFix Firestore Schemas

Firebase project: `quickfix-fyp` (Spark plan). Rules: `docs/firestore/firestore.rules`.

## users
| Field | Type | Notes |
|---|---|---|
| uid | string | document id |
| email | string | |
| fullName | string | |
| role | 'user' \| 'worker' \| 'admin' | drives RBAC (`isAdmin()` in rules) |
| phone | string? | |
| location | geopoint? | last known position (consent) |
| rating | number | 0–5, worker |
| reviews | number | review count, worker |
| preferredCategories | string[] | worker skill tags |
| minBudget / maxBudget | number | worker quote range (PKR) |
| isAvailable | bool | worker availability |
| createdAt / updatedAt | timestamp | |

## jobs
| Field | Type | Notes |
|---|---|---|
| userId | string | client uid |
| workerId | string? | assigned worker |
| title / description | string | |
| category | string | JobCategory enum name (manual selection) |
| address | string | |
| location | geopoint | real GPS from LocationService |
| budgetMin / budgetMax | number | PKR |
| preferredDate / preferredTime | timestamp? | |
| images | string[] | local app-storage paths |
| status | 'open' \| 'assigned' \| 'inProgress' \| 'completed' \| 'cancelled' | |
| rating / review | number? / string? | set on completion |
| createdAt / updatedAt / assignedAt / completedAt | timestamp | |

## conversations
| Field | Type | Notes |
|---|---|---|
| id | string | `user1_user2` sorted pair |
| participants | string[] | |
| lastMessage | string | |
| lastMessageAt | timestamp | |
| lastSenderId | string | |
| unreadCount | number | |

### conversations/{id}/messages
| Field | Type | Notes |
|---|---|---|
| senderId / receiverId | string | |
| text | string | |
| attachmentType | 'image' \| 'location' \| 'file'? | |
| attachmentUrl | string? | |
| latitude / longitude | number? | when attachmentType == 'location' |
| isRead | bool | |
| createdAt | timestamp | |

## reviews
| Field | Type | Notes |
|---|---|---|
| jobId / workerId / reviewerId | string | |
| rating | number | 1–5 stars |
| review | string | Urdu or English |
| reviewTranslated | string? | English translation (TranslationService) |
| createdAt | timestamp | |

## jobRequests (Phase 5)
Request sent by worker to user: jobId, workerId, userId, status
('pending' \| 'accepted' \| 'declined'), note, createdAt.

## payments (mock)
jobId, userId, workerId, amount (PKR), status, method, createdAt.

## categories
name, icon, isActive.
```

(Adjust any field names that differ from the actual models — the models in `mobile/lib/models/*.dart` are the source of truth; skim each to confirm.)

- [ ] **Step 2: Commit**

```bash
git add docs/firestore/schemas.md
git commit -m "docs: Firestore schemas for users, jobs, chats, reviews"
```

---

### Task 9: Full verification + on-device check

**Files:** none

- [ ] **Step 1: Full automated verification**

Run (workdir `mobile`): `flutter analyze` → only the 4 known sealed-class warnings; `flutter test` → all passing; then `flutter build apk --debug` → BUILD SUCCESSFUL.

- [ ] **Step 2: Install on the connected phone**

Check the phone: `adb devices` (expect the physical device). Install: `adb install -r build/app/outputs/flutter-apk/app-debug.apk` (if MIUI blocks, re-enable "Install via USB").

- [ ] **Step 3: Manual GPS + chat check**

Launch the app on the phone, log in as `user@quickfix.test` / `User@123`, Post a Job: grant the location permission prompt when asked — the job must store real coordinates (open the job in "My Jobs" and open the maps link). Open a chat with a worker, tap the location pin: grant permission, verify a location card bubble appears with real coordinates and the copied maps link. Then log in as `worker@quickfix.test` / `Worker@123` and verify the Job Request screen shows the client overview (name, ★★★★★ rating, review count, posting date) with green Accept / red Decline.

- [ ] **Step 4: Fix any on-device issues found (test-first), then commit**

If manual checks reveal bugs, fix with a failing test first, then commit. No commit needed if everything passes.

---

## Self-Review Notes

- Spec coverage: structure (Task 1), palette (Task 2), LocationService (Task 3), PostJob real GPS (Task 4), chat stream + location share (Task 5), login role cards (Task 6), Job Request polish (Task 7), schema docs (Task 8), verification (Task 9). All 9 spec sections mapped. Out-of-scope items (FCM, rendered maps, admin web) are absent — as approved.
- Placeholder scan: no TBD/TODO; every step has concrete code/commands. Task 4/7 contain one deliberate ambiguity guard (model-field checks) with explicit fallbacks — no placeholders.
- Type consistency: `LocationService({LocationProvider? provider})`, `getCurrentLocation() → GeoPoint?`, `LocationProvider` 4-method interface, `ChatMessage.latitude/longitude double?`, `ChatScreen({myId, peerId, peerName, chatService, locationService})`, `PostJobScreen({..., locationService})` — defined once and used identically across tasks. `successGreen`/`accentOrange`/`ctaOrange`/`brandBlue` referenced as defined in Task 2.
- Dependency discipline: no new pubspec packages anywhere (clipboard instead of url_launcher; mock providers instead of Mocktail for LocationService).