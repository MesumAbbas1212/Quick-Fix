import 'package:quickfix/core/widgets/job_image_thumb.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:quickfix/core/theme/app_theme.dart';
import 'package:quickfix/core/widgets/job_category_icons.dart';
import 'package:quickfix/models/app_language.dart';
import 'package:quickfix/models/job_model.dart';
import 'package:quickfix/models/user_model.dart';
import 'package:quickfix/models/worker_profile.dart';
import 'package:quickfix/services/auth_service.dart';
import 'package:quickfix/services/chat_service.dart';
import 'package:quickfix/services/job_service.dart';
import 'package:quickfix/services/language_service.dart';
import 'package:quickfix/services/location_service.dart';
import 'package:quickfix/services/local_image_store.dart';
import 'package:quickfix/services/profile_service.dart';
import 'package:quickfix/services/review_service.dart';
import 'package:quickfix/services/translation_service.dart';
import 'package:quickfix/views/auth/app_shell.dart';
import 'package:quickfix/views/settings/permission_explainer_screen.dart';

/// Worker sign-up wizard: creates the `workers/{uid}` document that makes a
/// worker discoverable in Browse Workers. A freshly signed-up worker has no
/// such document until this screen completes, so without it the worker is
/// invisible to clients.
///
/// Three steps (professions, service area & pricing, about you) with
/// per-step validation, a review summary on the final step, and an
/// idempotent save: if a profile doc already exists it is loaded and
/// prefilled, and existing rating/completion counts are preserved.
class WorkerOnboardingScreen extends StatefulWidget {
  final UserModel user;

  final ProfileService? profileService;
  final LocationService? locationService;
  final LanguageService? languageService;
  final LocalImageStore? imageStore;

  /// Services needed to build the AppShell after a sign-up flow.
  final JobService? jobService;
  final ReviewService? reviewService;
  final TranslationService? translationService;
  final AuthService? authService;
  final ChatService? chatService;

  /// `true` (sign-up flow): after saving, replace the stack with the
  /// AppShell. `false` (dashboard banner flow): pop back — the profile
  /// stream refreshes the dashboard.
  final bool returnToShell;

  const WorkerOnboardingScreen({
    super.key,
    required this.user,
    this.profileService,
    this.locationService,
    this.languageService,
    this.imageStore,
    this.jobService,
    this.reviewService,
    this.translationService,
    this.authService,
    this.chatService,
    this.returnToShell = false,
  });

  @override
  State<WorkerOnboardingScreen> createState() =>
      _WorkerOnboardingScreenState();
}

class _WorkerOnboardingScreenState extends State<WorkerOnboardingScreen> {
  static const int _minProfessions = 1;
  static const int _maxProfessions = 4;
  static const int _aboutMax = 300;

  late final ProfileService _profileService =
      widget.profileService ?? ProfileService();
  late final LocationService _locationService =
      widget.locationService ?? LocationService();
  late final LanguageService _languageService =
      widget.languageService ?? LanguageService();
  late final LocalImageStore _imageStore =
      widget.imageStore ?? const LocalImageStore();

  int _step = 0;
  bool _loadingExisting = true;
  WorkerProfile? _existing;

  final Set<JobCategory> _professions = {};
  GeoPoint? _location;
  final _minBudgetController = TextEditingController();
  final _maxBudgetController = TextEditingController();
  int _serviceRadiusKm = 5;

  final _aboutController = TextEditingController();
  final Set<String> _languages = {};
  List<AppLanguage> _availableLanguages =
      LanguageService.fallbackLanguages;
  String? _avatarUrl;
  bool _saving = false;
  String? _stepError;

  List<AppLanguage> get _languageOptions => _availableLanguages;

  @override
  void initState() {
    super.initState();
    _loadExisting();
    _loadLanguages();
  }

  @override
  void dispose() {
    _minBudgetController.dispose();
    _maxBudgetController.dispose();
    _aboutController.dispose();
    super.dispose();
  }

  Future<void> _loadExisting() async {
    try {
      final existing =
          await _profileService.getWorkerProfile(widget.user.uid);
      if (!mounted) return;
      if (existing != null) _prefill(existing);
      setState(() => _loadingExisting = false);
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingExisting = false);
    }
  }

  void _prefill(WorkerProfile p) {
    _professions.addAll(p.professions);
    _location = p.location;
    if (p.minBudget > 0) _minBudgetController.text = p.minBudget.toStringAsFixed(0);
    if (p.maxBudget > 0) _maxBudgetController.text = p.maxBudget.toStringAsFixed(0);
    _serviceRadiusKm = p.serviceRadiusKm;
    _aboutController.text = p.about ?? '';
    _avatarUrl = p.avatarUrl;
    for (final lang in _languageOptions) {
      if (p.languages.contains(lang.displayName)) _languages.add(lang.code);
    }
  }

  Future<void> _loadLanguages() async {
    try {
      final langs = await _languageService.getAvailableLanguages();
      if (!mounted) return;
      setState(() => _availableLanguages = langs);
    } catch (_) {
      // fallbackLanguages is already in place
    }
  }

  bool get _budgetsValid {
    final min = double.tryParse(_minBudgetController.text.trim());
    final max = double.tryParse(_maxBudgetController.text.trim());
    if (min == null || max == null) return false;
    if (min <= 0 || max <= 0) return false;
    if (min > max) return false;
    if (max > 1000000) return false;
    return true;
  }

  void _validateStep() {
    switch (_step) {
      case 0:
        if (_professions.length < _minProfessions) {
          setState(() => _stepError = 'Choose at least one profession.');
          return;
        }
        if (_professions.length > _maxProfessions) {
          setState(() => _stepError = 'Choose up to four professions.');
          return;
        }
        break;
      case 1:
        if (!_budgetsValid) {
          setState(() =>
              _stepError = 'Enter valid amounts (min ≤ max, both above 0).');
          return;
        }
        break;
      default:
        break;
    }
    setState(() => _stepError = null);
  }

  void _next() {
    _validateStep();
    if (_stepError != null || !mounted) return;
    setState(() => _step = _step + 1);
  }

  Future<void> _captureLocation() async {
    final allowed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PermissionExplainerScreen(
          purpose: 'to show clients how far you are willing to travel',
          locationService: widget.locationService,
        ),
      ),
    ) ??
        false;
    if (!allowed || !mounted) return;
    final position = await _locationService.getCurrentLocation();
    if (position != null && mounted) setState(() => _location = position);
  }

  Future<void> _pickAvatar() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      if (picked == null) return;
      final path = await _imageStore.saveAvatar(picked);
      if (mounted) setState(() => _avatarUrl = path);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not load the photo. Try another one.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _save() async {
    _validateStep();
    if (_stepError != null || !mounted) return;
    setState(() => _saving = true);
    try {
      final now = DateTime.now();
      final profile = WorkerProfile(
        uid: widget.user.uid,
        fullName: widget.user.fullName,
        email: widget.user.email,
        phone: widget.user.phone,
        about: _aboutController.text.trim().isEmpty
            ? null
            : _aboutController.text.trim(),
        professions: _professions.toList(),
        languages: [
          for (final code in _languages)
            _languageOptions
                .firstWhere((l) => l.code == code, orElse: () => _languageOptions.first)
                .displayName,
        ],
        location: _location,
        minBudget: double.parse(_minBudgetController.text.trim()),
        maxBudget: double.parse(_maxBudgetController.text.trim()),
        rating: _existing?.rating ?? 0,
        completedJobs: _existing?.completedJobs ?? 0,
        reviews: _existing?.reviews ?? 0,
        isAvailable: _existing?.isAvailable ?? true,
        serviceRadiusKm: _serviceRadiusKm,
        avatarUrl: _avatarUrl,
        createdAt: _existing?.createdAt ?? now,
        updatedAt: now,
      );
      await _profileService.saveWorkerProfile(profile);
      if (!mounted) return;
      if (widget.returnToShell) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => AppShell(
              user: widget.user,
              jobService: widget.jobService,
              chatService: widget.chatService,
              profileService: widget.profileService,
              reviewService: widget.reviewService,
              translationService: widget.translationService,
              authService: widget.authService,
            ),
          ),
        );
      } else {
        Navigator.of(context).pop(true);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _stepError = 'Could not save your profile. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(
        backgroundColor: AppTheme.brandBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Set up your profile',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        leading: _step > 0
            ? IconButton(
                key: const Key('onboarding-back'),
                icon: const Icon(Icons.arrow_back, size: 20),
                onPressed: () =>
                    setState(() {
                      _step -= 1;
                      _stepError = null;
                    }),
              )
            : null,
      ),
      body: SafeArea(
        child: _loadingExisting
            ? const Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.brandBlue,
                ),
              )
            : Column(
                children: [
                  _buildProgressDots(),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          switch (_step) {
                            0 => _buildProfessionsCard(),
                            1 => _buildAreaPricingCard(),
                            _ => _buildAboutCard(),
                          },
                          if (_step == 2) ...[
                            const SizedBox(height: 14),
                            _buildReviewCard(),
                          ],
                          if (_stepError != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Text(
                                _stepError!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textRed,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
                    child: SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        key: const Key('onboarding-next-button'),
                        onPressed: _saving
                            ? null
                            : (_step == 2 ? _save : _next),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.ctaOrange,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                _step == 2 ? 'Save profile' : 'Continue',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildProgressDots() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(3, (i) {
          final active = i <= _step;
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: i == _step ? 24 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: active ? AppTheme.ctaOrange : AppTheme.borderGray,
              borderRadius: BorderRadius.circular(4),
            ),
          );
        }),
      ),
    );
  }

  Widget _card(Widget child) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: AppTheme.borderGray),
      ),
      child: child,
    );
  }

  Widget _buildProfessionsCard() {
    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'What do you do?',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Choose 1–4 services you offer. Clients filter by these.',
            style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: JobCategory.values
                .map(
                  (cat) => _chip(
                    key: Key('profession-$cat'),
                    label: _categoryLabel(cat),
                    selected: _professions.contains(cat),
                    onTap: () {
                      if (_professions.contains(cat)) {
                        _professions.remove(cat);
                      } else {
                        if (_professions.length >= _maxProfessions) return;
                        _professions.add(cat);
                      }
                      setState(() => _stepError = null);
                    },
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildAreaPricingCard() {
    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Service area & pricing',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            key: const Key('onboarding-location-capture'),
            onPressed: _captureLocation,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.brandBlue,
              side: const BorderSide(color: AppTheme.brandBlue, width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.location_on_outlined, size: 18),
            label: _location != null
                ? const Text(
                    'Location captured — tap to re-capture',
                    style: TextStyle(fontSize: 13),
                  )
                : const Text(
                    'Use my current location (optional)',
                    style: TextStyle(fontSize: 13),
                  ),
          ),
          if (_location != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '${_location!.latitude.toStringAsFixed(5)}, '
                '${_location!.longitude.toStringAsFixed(5)}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.successGreen,
                ),
              ),
            ),
          const SizedBox(height: 16),
          const Text(
            'Your usual job price in PKR',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const Key('min-budget-field'),
                  controller: _minBudgetController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Minimum',
                    hintText: '500',
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                      borderSide: BorderSide(color: AppTheme.borderGray),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                      borderSide: BorderSide(color: AppTheme.borderGray),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                      borderSide: BorderSide(color: AppTheme.brandBlue, width: 2),
                    ),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Text('—',
                    style: TextStyle(color: AppTheme.textMuted)),
              ),
              Expanded(
                child: TextField(
                  key: const Key('max-budget-field'),
                  controller: _maxBudgetController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Maximum',
                    hintText: '5000',
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                      borderSide: BorderSide(color: AppTheme.borderGray),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                      borderSide: BorderSide(color: AppTheme.borderGray),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                      borderSide: BorderSide(color: AppTheme.brandBlue, width: 2),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text(
                'Travel radius',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textDark,
                ),
              ),
              const Spacer(),
              Text(
                '${_serviceRadiusKm} km',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.ctaOrange,
                ),
              ),
            ],
          ),
          Slider(
            key: const Key('service-radius-slider'),
            min: 1,
            max: 50,
            divisions: 49,
            label: '${_serviceRadiusKm} km',
            value: _serviceRadiusKm.toDouble(),
            onChanged: (v) => setState(() => _serviceRadiusKm = v.round()),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutCard() {
    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'About you',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              UserAvatarCircle(url: _avatarUrl, imageStore: _imageStore),
              const SizedBox(width: 12),
              TextButton(
                key: const Key('add-avatar-button'),
                onPressed: _pickAvatar,
                child: const Text(
                  'Add photo',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.brandBlue,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            key: const Key('about-field'),
            controller: _aboutController,
            maxLines: 3,
            maxLength: _aboutMax,
            decoration: const InputDecoration(
              hintText: 'Experience, special skills, years of work…',
              hintStyle: TextStyle(fontSize: 12, color: AppTheme.textMuted),
              isDense: true,
              counterStyle: TextStyle(fontSize: 11, color: AppTheme.textMuted),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),
                borderSide: BorderSide(color: AppTheme.borderGray),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),
                borderSide: BorderSide(color: AppTheme.borderGray),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),
                borderSide: BorderSide(color: AppTheme.brandBlue, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Languages you speak',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _languageOptions
                .map(
                  (lang) => _chip(
                    key: Key('language-${lang.code}'),
                    label: lang.displayName,
                    selected: _languages.contains(lang.code),
                    onTap: () {
                      if (_languages.contains(lang.code)) {
                        _languages.remove(lang.code);
                      } else {
                        _languages.add(lang.code);
                      }
                      setState(() {});
                    },
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewCard() {
    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Review your profile',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 10),
          _reviewRow('Services',
              _professions.map(_categoryLabel).join(', ')),
          _reviewRow('Price range',
              'PKR ${_minBudgetController.text} – ${_maxBudgetController.text}'),
          _reviewRow('Travel radius', '${_serviceRadiusKm} km'),
          _reviewRow('Location',
              _location == null
                  ? 'Not shared'
                  : '${_location!.latitude.toStringAsFixed(5)}, ${_location!.longitude.toStringAsFixed(5)}'),
          if (_languages.isNotEmpty)
            _reviewRow('Languages',
                _languages.map((c) => _displayName(c)).join(', ')),
          const SizedBox(height: 8),
          const Text(
            'Clients will see this profile when they browse workers near '
            'you. You can edit it later from your profile.',
            style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _reviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.textMuted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, color: AppTheme.textDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip({
    required Key key,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      key: key,
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.ctaOrange.withValues(alpha: 0.1)
              : AppTheme.surfaceWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppTheme.ctaOrange : AppTheme.borderGray,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? AppTheme.ctaOrange : AppTheme.textDark,
          ),
        ),
      ),
    );
  }

  String _categoryLabel(JobCategory cat) => jobCategoryLabel(cat);

  String _displayName(String code) {
    try {
      return _languageOptions
          .firstWhere((l) => l.code == code)
          .displayName;
    } catch (_) {
      return code;
    }
  }
}

/// Simple avatar circle: network/local image or an initials-free grey
/// placeholder. Kept local to this wizard so onboarding has no dependency on
/// the shared UserAvatar (which needs a name).
class UserAvatarCircle extends StatelessWidget {
  final String? url;

  final LocalImageStore? imageStore;
  const UserAvatarCircle({super.key, this.url, this.imageStore});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: AppTheme.borderGray,
      ),
      child: url == null
          ? const Icon(Icons.person_outline,
              size: 28, color: AppTheme.textMuted)
          : ClipOval(
              child: JobImageThumb(image: url, size: 56, imageStore: imageStore, fallbackIcon: Icons.person_outline),
            ),
    );
  }
}
