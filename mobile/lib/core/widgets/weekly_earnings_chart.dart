import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:quickfix/core/theme/app_theme.dart';
import 'package:quickfix/models/earnings_summary.dart';

/// Eight calendar weeks of paid receipts. Values are already calculated;
/// painting never performs I/O or fetches extra data.
class WeeklyEarningsChart extends StatelessWidget {
  final List<WeeklyEarnings> weeks;

  const WeeklyEarningsChart({super.key, required this.weeks});

  @override
  Widget build(BuildContext context) {
    final money = intl.NumberFormat('#,##0', 'en_PK');
    return LayoutBuilder(builder: (context, constraints) {
      final width = math.max(constraints.maxWidth, weeks.length * 44.0);
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: width,
          child: Column(
            children: [
              SizedBox(
                height: AppTheme.earningsChartHeight,
                width: width,
                child: CustomPaint(
                  key: const Key('weekly-earnings-paint'),
                  painter: EarningsBarPainter(weeks.map((w) => w.amount).toList()),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (final week in weeks)
                    Expanded(
                      child: Semantics(
                        label: 'Week of ${intl.DateFormat('d MMM yyyy', 'en').format(week.start)}: '
                            'PKR ${money.format(week.amount)}',
                        child: ExcludeSemantics(
                          child: Text(
                            intl.DateFormat('d/M', 'en').format(week.start),
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      );
    });
  }
}

class EarningsBarPainter extends CustomPainter {
  final List<double> values;

  EarningsBarPainter(this.values);

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty || size.isEmpty) return;
    final maxValue = values.fold<double>(1, (a, b) => math.max(a, b));
    final step = size.width / values.length;
    final height = size.height - 8;
    final grid = Paint()
      ..color = AppTheme.borderGray
      ..strokeWidth = 1;
    for (final fraction in [0.0, 0.5, 1.0]) {
      final y = height * fraction;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    for (var i = 0; i < values.length; i++) {
      final paint = Paint()
        ..color = i == values.length - 1 ? AppTheme.ctaOrange : AppTheme.brandBlue;
      final barHeight = height * (values[i] / maxValue).clamp(0.0, 1.0);
      if (barHeight <= 0) continue;
      final rect = Rect.fromLTWH(step * i + step / 4, height - barHeight, step / 2, barHeight);
      canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(4)), paint);
    }
  }

  @override
  bool shouldRepaint(covariant EarningsBarPainter oldDelegate) =>
      !listEquals(values, oldDelegate.values);
}
