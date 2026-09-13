import 'package:flutter/material.dart';
import 'package:quickfix/core/theme/app_theme.dart';
import 'package:quickfix/core/widgets/completed_job_tile.dart';
import 'package:quickfix/models/job_model.dart';
import 'package:quickfix/services/job_service.dart';

/// Full-screen work history for a worker: every completed job, newest
/// first, live from Firestore. Opened from the "See all N jobs" button on
/// the worker profile so the profile itself stays compact.
class WorkHistoryScreen extends StatelessWidget {
  final String workerUid;
  final String workerName;
  final JobService? jobService;

  const WorkHistoryScreen({
    super.key,
    required this.workerUid,
    required this.workerName,
    this.jobService,
  });

  JobService get _jobService => jobService ?? JobService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(
        backgroundColor: AppTheme.brandBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Work History',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: StreamBuilder<List<JobModel>>(
          stream: _jobService.watchCompletedJobsForWorker(workerUid),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'Could not load work history.',
                    style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
                  ),
                ),
              );
            }
            if (!snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.brandBlue,
                ),
              );
            }
            final jobs = snapshot.data!;
            if (jobs.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'No completed jobs yet',
                    style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
                  ),
                ),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Text(
                    '${workerName} · ${jobs.length} completed jobs',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(14),
                    itemCount: jobs.length,
                    itemBuilder: (context, index) =>
                        CompletedJobTile(job: jobs[index]),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
