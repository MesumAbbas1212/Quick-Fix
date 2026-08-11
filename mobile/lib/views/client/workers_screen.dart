import 'package:flutter/material.dart';
import 'package:quickfix/core/theme/app_theme.dart';
import 'package:quickfix/models/user_model.dart';

/// Browse workers near the client. Full implementation lands with the
/// Workers tab (professions, distance, worker detail).
class WorkersScreen extends StatefulWidget {
  final UserModel user;

  const WorkersScreen({super.key, required this.user});

  @override
  State<WorkersScreen> createState() => _WorkersScreenState();
}

class _WorkersScreenState extends State<WorkersScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              color: AppTheme.brandBlue,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Workers',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Find skilled professionals near you.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF93C5FD)),
                  ),
                ],
              ),
            ),
            const Expanded(
              child: Center(
                child: Text(
                  'Workers coming soon',
                  style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
