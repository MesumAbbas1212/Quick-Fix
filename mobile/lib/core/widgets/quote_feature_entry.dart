import 'package:flutter/material.dart';
import 'package:quickfix/core/theme/app_theme.dart';
import 'package:quickfix/models/user_model.dart';
import 'package:quickfix/services/job_service.dart';
import 'package:quickfix/services/profile_service.dart';
import 'package:quickfix/services/quote_service.dart';
import 'package:quickfix/views/jobs/quote_request_screen.dart';
/// No dead "coming soon" CTA: the protected, default-off operator flag must
/// be enabled only after prerequisite A1–A4 validation before this is exposed.
class QuoteFeatureEntry extends StatefulWidget {
  final UserModel user;
  final QuoteService? quoteService;
  final ProfileService? profileService;
  final JobService? jobService;
  final Color foregroundColor;
  const QuoteFeatureEntry({super.key, required this.user, this.quoteService, this.profileService, this.jobService, this.foregroundColor = AppTheme.brandBlue});
  @override
  State<QuoteFeatureEntry> createState() => _QuoteFeatureEntryState();
}
class _QuoteFeatureEntryState extends State<QuoteFeatureEntry> {
  late final QuoteService _service = widget.quoteService ?? QuoteService(profileService: widget.profileService, jobService: widget.jobService);
  late final Future<bool> _enabled = _service.isEnabled();
  @override
  Widget build(BuildContext context) => FutureBuilder<bool>(future: _enabled, builder: (context, snapshot) => snapshot.data != true ? const SizedBox.shrink() : TextButton.icon(
    key: const Key('quotes-feature-entry'), style: TextButton.styleFrom(foregroundColor: widget.foregroundColor), icon: const Icon(Icons.request_quote_outlined),
    onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => QuoteRequestScreen(user: widget.user, quoteService: _service, profileService: widget.profileService, jobService: widget.jobService))),
    label: Text(widget.user.role == UserRole.worker ? 'Quote invitations' : 'Get quotes first')));
}
