import 'package:quickfix/views/worker/client_profile_screen.dart';
import 'package:quickfix/services/job_request_service.dart';
import 'package:flutter/material.dart';
import 'package:quickfix/core/theme/app_theme.dart';
import 'package:quickfix/core/widgets/job_category_icons.dart';
import 'package:quickfix/models/job_model.dart';
import 'package:quickfix/models/user_model.dart';
import 'package:quickfix/services/auth_service.dart';
import 'package:quickfix/services/job_service.dart';

class JobRequestScreen extends StatefulWidget {
  final JobModel job;
  final UserModel? client;
  final String? workerId;
  final JobService? jobService;
  final JobRequestService? requestService;
  final AuthService? authService;
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;

  const JobRequestScreen({
    super.key,
    required this.job,
    this.client,
    this.workerId,
    this.jobService,
    this.requestService,
    this.authService,
    this.onAccept,
    this.onDecline,
  });

  @override
  State<JobRequestScreen> createState() => _JobRequestScreenState();
}

class _JobRequestScreenState extends State<JobRequestScreen> {
  bool _isSubmitting = false;
  UserModel? _resolvedClient;

  @override
  void initState() {
    super.initState();
    _resolvedClient = widget.client;
    if (_resolvedClient == null) {
      _loadClient();
    }
  }

  Future<void> _loadClient() async {
    final auth = widget.authService;
    if (auth == null) return;
    try {
      final client = await auth.getUserProfile(widget.job.userId);
      if (!mounted) return;
      setState(() => _resolvedClient = client);
    } catch (_) {
      // Client info stays hidden if the profile cannot be loaded.
    }
  }

  Future<void> _handleAccept() async {
    if (_isSubmitting) return;
    final workerId = widget.workerId;
    if (workerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not send the application. Please try again.'),
        ),
      );
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      final service = widget.requestService ?? JobRequestService();
      final previous = await service.getExistingRequest(jobId: widget.job.id, workerId: workerId).timeout(const Duration(seconds: 5));
      if (previous == null) await service.sendJobRequest(jobId: widget.job.id, workerId: workerId, userId: widget.job.userId)
        .timeout(const Duration(seconds: 10));
      // Only the owning client selects/assigns applicants (B1); workers cannot
      // self-assign public open jobs or bypass the deletion pause.

      if (!mounted) return;
      // Single pop only: the caller decides via onAccept; popping twice
      // removed the app shell and caused a black screen.
      if (widget.onAccept != null) {
        widget.onAccept!();
      } else {
        Navigator.of(context).pop();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not send the application. Try again.')),
        );
      }
    }
  }

  void _handleDecline() {
    if (widget.onDecline != null) {
      widget.onDecline!();
    } else {
      Navigator.of(context).pop();
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      body: _buildPhoneScreen(),
    );
  }

  Widget _buildPhoneScreen() {
    return SafeArea(
      child: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildJobCard(),
                  const SizedBox(height: 16),
                  _buildActionButtons(),
                  const SizedBox(height: 16),
                  _buildClientInfo(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: AppTheme.brandBlue,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Back', icon: const Icon(Icons.arrow_back, color: AppTheme.surfaceWhite, size: 20),
            onPressed: () => Navigator.pop(context),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          ),
          const SizedBox(width: 8),
          const Text(
            'Job Request',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJobCard() {
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppTheme.accentYellow,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.accentYellow.withValues(alpha: 0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                  border: Border.all(color: AppTheme.accentYellow, width: 1),
                ),
                child: Icon(
                  jobCategoryIcon(widget.job.category),
                  color: AppTheme.brandBlue,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.job.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textDark,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            widget.job.description,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppTheme.textMuted,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(
                Icons.location_on,
                size: 14,
                color: AppTheme.dangerRed,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  widget.job.address,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textDark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                const Icon(
                  Icons.attach_money,
                  size: 16,
                  color: Color(0xFF059669),
                ),
                const SizedBox(width: 4),
                Text(
                  'PKR ${_formatBudget(widget.job.budgetMax)}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF059669),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: _isSubmitting ? null : _handleAccept,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.successGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 4,
              shadowColor: AppTheme.successGreen.withValues(alpha: 0.4),
            ),
            child: const Text(
              'Apply for job',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: _handleDecline,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.dangerRed,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                elevation: 4,
                shadowColor: AppTheme.dangerRed.withValues(alpha: 0.4),
              ),
              child: const Text(
                'Decline',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildClientInfo() {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Client Info',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 10),
          _buildClientRow('Client:', _resolvedClient?.fullName),
          const SizedBox(height: 8),
          if (_resolvedClient != null)
            _buildRatingRow(
              _resolvedClient!.rating,
              _resolvedClient!.completedJobs,
            )
          else ...[
            const SizedBox(height: 8),
            Container(height: 1, color: AppTheme.borderGray),
          ],
          const SizedBox(height: 8),
          Container(height: 1, color: AppTheme.borderGray),
          const SizedBox(height: 8),
          if (widget.workerId != null) TextButton(key: const Key('request-client-profile'), onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ClientProfileScreen(clientId: widget.job.userId, viewerId: widget.workerId!, authService: widget.authService, jobService: widget.jobService))), child: const Text('View client profile')),
          _buildInfoRow('Posted:', _formatDate(widget.job.createdAt)),
          const SizedBox(height: 8),
          _buildInfoRow(
            'Preferred Date:',
            _formatDate(widget.job.preferredDate),
          ),
        ],
      ),
    );
  }

  Widget _buildClientRow(String label, String? value) {
    if (value == null || value.isEmpty) {
      return const SizedBox.shrink();
    }
    return _buildInfoRow(label, value);
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppTheme.textMuted,
          ),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppTheme.textDark,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRatingRow(double rating, int reviewCount) {
    final filledStars = rating.round().clamp(0, 5);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Rating:',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppTheme.textMuted,
          ),
        ),
        Flexible(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                rating.toStringAsFixed(1),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textDark,
                ),
              ),
              const SizedBox(width: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(5, (index) {
                  return Icon(
                    index < filledStars ? Icons.star : Icons.star_border,
                    color: AppTheme.accentYellow,
                    size: 12,
                  );
                }),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  '($reviewCount Reviews)',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textMuted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatBudget(double budget) {
    if (budget >= 1000) {
      return '${(budget / 1000).toStringAsFixed(budget % 1000 == 0 ? 0 : 1)}k';
    }
    return budget.toStringAsFixed(0);
  }

  String _formatDate(DateTime date) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}
