import 'package:flutter/material.dart';
import 'package:quickfix/core/theme/app_theme.dart';
import 'package:quickfix/views/auth/app_shell.dart';
import 'package:quickfix/views/auth/login_screen.dart';
import 'package:quickfix/services/auth_service.dart';
import 'package:quickfix/services/chat_service.dart';
import 'package:quickfix/services/job_service.dart';
import 'package:quickfix/services/language_service.dart';
import 'package:quickfix/services/profile_service.dart';
import 'package:quickfix/services/review_service.dart';
import 'package:quickfix/services/translation_service.dart';
import 'package:quickfix/models/app_language.dart';
import 'package:quickfix/models/user_model.dart';

class SignUpScreen extends StatefulWidget {
  final UserRole initialRole;
  final LanguageService? languageService;
  final AuthService? authService;

  const SignUpScreen({
    super.key,
    this.initialRole = UserRole.user,
    this.languageService,
    this.authService,
  });

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  late UserRole _selectedRole;
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _errorMessage;

  // App language selection — the options come from LanguageService
  // (Firestore `languages` collection / translation proxy), never from
  // a hard-coded list in the UI.
  List<AppLanguage> _languages = LanguageService.fallbackLanguages;
  AppLanguage? _selectedLanguage;
  bool _languagesLoaded = false;

  @override
  void initState() {
    super.initState();
    _selectedRole = widget.initialRole;
    _loadLanguages();
  }

  Future<void> _loadLanguages() async {
    final service = widget.languageService ?? _tryCreateLanguageService();
    List<AppLanguage> languages;
    if (service == null) {
      languages = LanguageService.fallbackLanguages;
    } else {
      try {
        languages = await service.getAvailableLanguages();
      } catch (_) {
        languages = LanguageService.fallbackLanguages;
      }
    }
    // Guarantee the setState below runs outside the current build phase
    // even when the list resolves without hitting a network await.
    await Future<void>.value();
    if (!mounted) return;
    setState(() {
      _languages = languages;
      _languagesLoaded = true;
      _selectedLanguage ??= languages.firstWhere(
        (lang) => lang.code == 'en',
        orElse: () => languages.first,
      );
    });
  }

  /// Builds the real service only when Firebase is initialized; returns
  /// null otherwise so the screen (and widget tests) never crash without
  /// a backend — the last-resort language list is used instead.
  LanguageService? _tryCreateLanguageService() {
    try {
      return LanguageService();
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignUp() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final auth = widget.authService ?? AuthService();
      final credential = await auth.registerWithEmailAndPassword(
        email: _emailController.text,
        password: _passwordController.text,
        fullName: _nameController.text,
        phone: _phoneController.text,
        role: _selectedRole,
        language: _selectedLanguage?.code ?? 'en',
      );
      final user = await auth.getUserProfile(credential.user!.uid);
      if (!mounted) return;
      setState(() => _isLoading = false);
      if (user == null) {
        _errorMessage = 'Account created but profile loading failed.';
        return;
      }
      final jobService = JobService();
      final chatService = ChatService();
      final profileService = ProfileService();
      final reviewService = ReviewService();
      final translationService = TranslationService();
      final authService = AuthService();
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => AppShell(
            user: user,
            jobService: jobService,
            chatService: chatService,
            profileService: profileService,
            reviewService: reviewService,
            translationService: translationService,
            authService: authService,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.brandBlue,
      body: _buildPhoneScreen(),
    );
  }

  Widget _buildPhoneScreen() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          children: [
            _buildHeader(),
            const SizedBox(height: 20),
            _buildRoleSelection(),
            const SizedBox(height: 20),
            _buildLanguageSelection(),
            const SizedBox(height: 20),
            _buildForm(),
            const SizedBox(height: 16),
            _buildBottomLinks(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppTheme.accentYellow,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.build,
                color: AppTheme.brandBlue,
                size: 24,
              ),
            ),
            const SizedBox(width: 8),
            RichText(
              text: const TextSpan(
                children: [
                  TextSpan(
                    text: 'Quick',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                  TextSpan(
                    text: 'Fix',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.accentYellow,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'On-Demand Local Service Matching',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Color(0xFF93C5FD),
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildRoleSelection() {
    return Row(
      children: [
        Expanded(
          child: _RoleButton(
            label: 'Sign Up as User',
            subtitle: 'Find Services',
            icon: Icons.person,
            backgroundColor: const Color(0xFF009AE2),
            iconBackgroundColor: Colors.white.withValues(alpha: 0.2),
            iconColor: Colors.white,
            textColor: Colors.white,
            subtitleColor: const Color(0xFF93C5FD),
            isSelected: _selectedRole == UserRole.user,
            onTap: () => setState(() => _selectedRole = UserRole.user),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _RoleButton(
            label: 'Sign Up as Worker',
            subtitle: 'Get Jobs',
            icon: Icons.handyman,
            backgroundColor: AppTheme.accentYellow,
            iconBackgroundColor: Colors.black.withValues(alpha: 0.1),
            iconColor: AppTheme.brandBlue,
            textColor: AppTheme.brandBlue,
            subtitleColor: Colors.white.withValues(alpha: 0.9),
            isSelected: _selectedRole == UserRole.worker,
            onTap: () => setState(() => _selectedRole = UserRole.worker),
          ),
        ),
      ],
    );
  }

  /// Language picker shown at sign-up. The options are loaded dynamically
  /// (Firestore `languages` collection, extended by the translation
  /// proxy's supported languages) so adding a language never requires an
  /// app update.
  Widget _buildLanguageSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'Choose the language you want the app to show',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
        Container(
          key: const Key('app-language-field'),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: _languagesLoaded
              ? DropdownButton<AppLanguage>(
                  key: const Key('app-language-dropdown'),
                  value: _selectedLanguage ?? _languages.first,
                  isDense: true,
                  isExpanded: true,
                  underline: const SizedBox.shrink(),
                  items: _languages
                      .map((lang) => DropdownMenuItem<AppLanguage>(
                            value: lang,
                            child: Text(
                              _languageLabel(lang),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF1E293B),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ))
                      .toList(),
                  onChanged: (lang) {
                    if (lang != null) {
                      setState(() => _selectedLanguage = lang);
                    }
                  },
                )
              : const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.brandBlue,
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  String _languageLabel(AppLanguage lang) {
    final display = lang.displayName;
    if (lang.englishName.isNotEmpty && lang.englishName != display) {
      return '$display (${lang.englishName})';
    }
    return display;
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          _AuthTextField(
            controller: _nameController,
            hint: 'Full Name',
            keyboardType: TextInputType.name,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Full name is required';
              }
              if (value.trim().length < 2) return 'Enter a valid name';
              return null;
            },
          ),
          const SizedBox(height: 12),
          _AuthTextField(
            controller: _emailController,
            hint: 'Email',
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value == null || value.isEmpty) return 'Email is required';
              if (!value.contains('@')) return 'Enter a valid email';
              return null;
            },
          ),
          const SizedBox(height: 12),
          _AuthTextField(
            controller: _phoneController,
            hint: 'Phone Number',
            keyboardType: TextInputType.phone,
            validator: (value) {
              if (value == null || value.isEmpty) return 'Phone is required';
              if (value.length < 10) return 'Enter a valid phone number';
              return null;
            },
          ),
          const SizedBox(height: 12),
          _AuthTextField(
            controller: _passwordController,
            hint: 'Password',
            obscureText: true,
            validator: (value) {
              if (value == null || value.isEmpty) return 'Password is required';
              if (value.length < 6) {
                return 'Password must be at least 6 characters';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          _AuthTextField(
            controller: _confirmPasswordController,
            hint: 'Confirm Password',
            obscureText: true,
            validator: (value) {
              if (value == null || value.isEmpty) return 'Confirm password';
              if (value != _passwordController.text) {
                return 'Passwords do not match';
              }
              return null;
            },
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleSignUp,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.ctaOrange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                elevation: 4,
                shadowColor: AppTheme.ctaOrange.withValues(alpha: 0.4),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : const Text(
                      'Create Account',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomLinks() {
    return RichText(
      text: TextSpan(
        children: [
          const TextSpan(
            text: 'Already have an account? ',
            style: TextStyle(fontSize: 12, color: Color(0xFF93C5FD)),
          ),
          WidgetSpan(
            child: GestureDetector(
              onTap: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              },
              child: const Text(
                'Login',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.accentYellow,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Reuse _RoleButton, _AuthTextField from login_screen.dart
// In a real app, these would be extracted to a shared widgets file.
// For now, they are included inline to keep files self-contained.

class _RoleButton extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final Color backgroundColor;
  final Color iconBackgroundColor;
  final Color iconColor;
  final Color textColor;
  final Color subtitleColor;
  final bool isSelected;
  final VoidCallback onTap;

  const _RoleButton({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.backgroundColor,
    required this.iconBackgroundColor,
    required this.iconColor,
    required this.textColor,
    required this.subtitleColor,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
            if (isSelected)
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.4),
                blurRadius: 0,
                spreadRadius: 2,
              ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconBackgroundColor,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: textColor,
                height: 1.1,
              ),
              textAlign: TextAlign.center,
            ),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: subtitleColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool obscureText;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;

  const _AuthTextField({
    required this.controller,
    required this.hint,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: Color(0xFF1E293B),
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppTheme.textMuted,
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: AppTheme.brandBlue, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: AppTheme.dangerRed),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: AppTheme.dangerRed, width: 2),
        ),
      ),
    );
  }
}
