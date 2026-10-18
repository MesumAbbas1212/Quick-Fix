import 'package:flutter/material.dart';
import 'package:quickfix/core/theme/app_theme.dart';
import 'package:quickfix/services/report_service.dart';

/// Report a user, worker or job. Reachable from the overflow menus of
/// worker profiles, job details and conversations. Writes a `reports` doc
/// with `status: 'open'`; admins resolve it in the admin dashboard.
///
/// Duplicate open reports from the same reporter against the same target
/// are blocked, and a user can never report themselves.
class ReportScreen extends StatefulWidget {
  final String myId;

  /// uid of the account being reported.
  final String reportedId;

  /// Display name of the reported account (for the header line).
  final String reportedName;

  /// Optional job context shown in the report.
  final String? jobId;
  final String? jobTitle;

  final ReportService? reportService;

  const ReportScreen({
    super.key,
    required this.myId,
    required this.reportedId,
    required this.reportedName,
    this.jobId,
    this.jobTitle,
    this.reportService,
  });

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

const _reasons = [
  "Didn't show up",
  'Rude or unprofessional',
  'Wrong or unsafe work',
  'Fake profile',
  'Asked for payment outside the app',
  'Other',
];

class _ReportScreenState extends State<ReportScreen> {
  static const int _detailsMax = 500;

  late final ReportService _reportService =
      widget.reportService ?? ReportService();

  final _detailsController = TextEditingController();
  String? _selectedReason;
  String? _validationError;
  bool _checkingDuplicate = true;
  bool _duplicateOpen = false;
  bool _submitting = false;

  bool get _selfReport => widget.reportedId == widget.myId;

  @override
  void initState() {
    super.initState();
    _checkDuplicate();
  }

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _checkDuplicate() async {
    if (_selfReport) {
      _setDuplicateChecked(false);
      return;
    }
    try {
      final dup =
          await _reportService.hasOpenReport(widget.myId, widget.reportedId);
      _setDuplicateChecked(dup);
    } catch (_) {
      // If the check fails (offline), allow the attempt — the admin
      // dashboard can merge duplicates.
      _setDuplicateChecked(false);
    }
  }

  void _setDuplicateChecked(bool duplicate) {
    if (!mounted) return;
    setState(() {
      _checkingDuplicate = false;
      _duplicateOpen = duplicate;
    });
  }

  void _validate() {
    if (_selectedReason == null) {
      setState(() => _validationError = 'Choose a reason to continue.');
      return;
    }
    setState(() => _validationError = null);
  }

  Future<void> _confirmAndSubmit() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Submit report?',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        content: Text(
          'This sends your report to the QuickFix team. They will review it '
          'and may contact you for more information.',
          style: const TextStyle(fontSize: 13, color: AppTheme.textDark),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text(
              'Cancel',
              style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(
              'Submit report',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppTheme.dangerRed,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _submit();
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      await _reportService.submitReport(
        reporterId: widget.myId,
        reportedId: widget.reportedId,
        reason: _selectedReason!,
        jobId: widget.jobId,
        details: _detailsController.text,
      );
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger
        ..hideCurrentSnackBar()
        .showSnackBar(
          const SnackBar(
            content: Text('Report submitted. Our team will review it.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
    } catch (_) {
      if (!mounted) return;
      setState(() => _validationError = 'Could not submit the report. Please try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
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
          'Report',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: _selfReport
            ? _card(Column(
                children: [
                  const Text(
                    'Self-report not allowed',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'You cannot report your own account. If you need help '
                    'with your account, use Help & Support from your profile.',
                    style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                  ),
                ],
              ))
            : ListView(
                padding: const EdgeInsets.all(14),
                children: [
                  _buildAboutCard(),
                  const SizedBox(height: 14),
                  _buildReasonCard(),
                  const SizedBox(height: 14),
                  _buildDetailsCard(),
                  const SizedBox(height: 14),
                  _buildEvidenceNote(),
                  const SizedBox(height: 18),
                  _buildSubmitButton(),
                ],
              ),
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

  Widget _buildAboutCard() {
    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Report ${widget.reportedName}',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.textDark,
            ),
          ),
          if (widget.jobTitle != null) ...[
            const SizedBox(height: 4),
            Text(
              'About: ${widget.jobTitle}',
              style:
                  const TextStyle(fontSize: 12, color: AppTheme.textMuted),
            ),
          ],
          const SizedBox(height: 10),
          const Text(
            'Your report is sent privately to the QuickFix team. We review '
            'every report, may contact you for details, and may take action '
            'on the reported account. Reporting does not affect your own '
            'account or any job you have with this person.',
            style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildReasonCard() {
    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'What happened?',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 10),
          for (final reason in _reasons)
            RadioListTile<String>(
              key: Key('report-reason-$reason'),
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(
                reason,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.textDark,
                ),
              ),
              secondary: const SizedBox.shrink(),
              value: reason,
              groupValue: _selectedReason,
              onChanged: (value) => setState(() {
                _selectedReason = value;
                _validate();
              }),
            ),
          if (_validationError != null && _selectedReason == null)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                'Choose a reason to continue.',
                style: TextStyle(fontSize: 12, color: AppTheme.textRed),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailsCard() {
    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Details (optional)',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            key: const Key('report-details-field'),
            controller: _detailsController,
            maxLines: 4,
            maxLength: _detailsMax,
            onChanged: (_) =>
                _validationError != null ? _validate() : null,
            decoration: const InputDecoration(
              hintText: 'What happened, when, and any other context…',
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
        ],
      ),
    );
  }

  Widget _buildEvidenceNote() {
    return _card(
      const Row(
        children: [
          Icon(Icons.photo_library_outlined,
              size: 18, color: AppTheme.textMuted),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Photo evidence can be added later if our team asks for it. '
              'Keep screenshots or photos of anything relevant.',
              style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Column(
      children: [
        if (_duplicateOpen)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _card(
              const Row(
                children: [
                  Icon(Icons.info_outline,
                      size: 18, color: AppTheme.ctaOrange),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'You already have an open report for this person. '
                      'Our team is reviewing it — no need to submit again.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textDark,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (_validationError != null && _selectedReason != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              _validationError!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: AppTheme.textRed),
            ),
          ),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            key: const Key('submit-report-button'),
            onPressed:
                (_checkingDuplicate || _duplicateOpen || _submitting)
                    ? null
                    : () {
                        _validate();
                        if (_validationError == null) _confirmAndSubmit();
                      },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.dangerRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _submitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Submit report',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
          ),
        ),
      ],
    );
  }
}
