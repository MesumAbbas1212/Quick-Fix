import 'package:flutter/material.dart';
import 'package:quickfix/core/theme/app_theme.dart';
import 'package:quickfix/models/job_model.dart';

/// One completed job row, shared between the worker profile's Work History
/// preview and the full Work History page so both look identical.
class CompletedJobTile extends StatelessWidget {
  final JobModel job;

  const CompletedJobTile({super.key, required this.job});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.bgLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderGray),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.check_circle,
                size: 14,
                color: AppTheme.successGreen,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  job.title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textDark,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (job.rating != null) ...[
                const Icon(Icons.star, size: 13, color: AppTheme.accentYellow),
                const SizedBox(width: 2),
                Text(
                  job.rating!.toStringAsFixed(1),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textDark,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  _categoryLabel(job.category) +
                      ' · ' +
                      _dateLabel(job.completedAt ?? job.updatedAt),
                  style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'PKR ${job.budgetMin.toStringAsFixed(0)}-${job.budgetMax.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _categoryLabel(JobCategory cat) {
    return cat.name[0].toUpperCase() +
        cat.name.substring(1).replaceAll(RegExp(r'(?<=[a-z])([A-Z])'), r' $1');
  }

  String _dateLabel(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}
