import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/worker_rank.dart';

/// Rank badge shown on worker profiles.
///
/// Renders a proper vector emblem (shield / hexagon / star / diamond /
/// crown — one per rank, drawn with [CustomPainter], not an icon glyph)
/// next to the rank name. When [completedInYear] is provided, the badge
/// also shows how many more jobs the worker needs to reach the next rank
/// (hidden at Grandmaster).
class RankBadge extends StatelessWidget {
  final WorkerRank rank;
  final int? completedInYear;
  final double fontSize;
  final double emblemSize;

  const RankBadge({
    super.key,
    required this.rank,
    this.completedInYear,
    this.fontSize = 12,
    this.emblemSize = 26,
  });

  @override
  Widget build(BuildContext context) {
    final count = completedInYear;
    final progress = count != null ? rank.jobsUntilNext(count) : null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: rank.color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: rank.color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          RankEmblem(rank: rank, size: emblemSize),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              rank.name,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w700,
                color: rank.color,
              ),
            ),
          ),
          if (progress != null) ...[
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                '+$progress to ${rank.nextRank!.name}',
                style: TextStyle(
                  fontSize: fontSize - 1,
                  fontWeight: FontWeight.w600,
                  color: rank.color.withValues(alpha: 0.8),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The vector emblem for a rank:
///   Apprentice  — shield with chevron
///   Journeyman  — hexagon with lightning bolt
///   Expert      — five-point star
///   Master      — nested diamonds
///   Grandmaster — crown
class RankEmblem extends StatelessWidget {
  final WorkerRank rank;
  final double size;

  const RankEmblem({super.key, required this.rank, required this.size});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _RankEmblemPainter(rank),
    );
  }
}

class _RankEmblemPainter extends CustomPainter {
  final WorkerRank rank;

  _RankEmblemPainter(this.rank);

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    final c = size.center(Offset.zero);
    final color = rank.color;
    Offset p(double x, double y) => c + Offset(x * r, y * r);

    final fill = Paint()
      ..shader = LinearGradient(
        colors: [
          color.withValues(alpha: 0.30),
          color.withValues(alpha: 0.08),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromCircle(center: c, radius: r));
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.1, r * 0.1)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final solid = Paint()..color = color;

    switch (rank.name) {
      case 'Apprentice':
        final shield = Path()
          ..moveTo(p(0, -0.92).dx, p(0, -0.92).dy)
          ..cubicTo(p(0.55, -0.78).dx, p(0.55, -0.78).dy,
              p(0.8, -0.62).dx, p(0.8, -0.62).dy, p(0.8, 0).dx, p(0.8, 0).dy)
          ..cubicTo(p(0.8, 0.5).dx, p(0.8, 0.5).dy,
              p(0.45, 0.74).dx, p(0.45, 0.74).dy, p(0, 0.95).dx, p(0, 0.95).dy)
          ..cubicTo(p(-0.45, 0.74).dx, p(-0.45, 0.74).dy,
              p(-0.8, 0.5).dx, p(-0.8, 0.5).dy, p(-0.8, 0).dx, p(-0.8, 0).dy)
          ..cubicTo(p(-0.8, -0.62).dx, p(-0.8, -0.62).dy,
              p(-0.55, -0.78).dx, p(-0.55, -0.78).dy, p(0, -0.92).dx, p(0, -0.92).dy)
          ..close();
        canvas.drawPath(shield, fill);
        canvas.drawPath(shield, stroke);
        final chevron = Path()
          ..moveTo(p(-0.32, -0.16).dx, p(-0.32, -0.16).dy)
          ..lineTo(p(0, 0.16).dx, p(0, 0.16).dy)
          ..lineTo(p(0.32, -0.16).dx, p(0.32, -0.16).dy);
        canvas.drawPath(chevron, stroke);
        break;

      case 'Journeyman':
        canvas.drawPath(_polygon(c, r * 0.92, 6, -math.pi / 2), fill);
        canvas.drawPath(_polygon(c, r * 0.92, 6, -math.pi / 2), stroke);
        final bolt = Path()
          ..moveTo(p(0.12, -0.46).dx, p(0.12, -0.46).dy)
          ..lineTo(p(-0.24, 0.12).dx, p(-0.24, 0.12).dy)
          ..lineTo(p(-0.02, 0.12).dx, p(-0.02, 0.12).dy)
          ..lineTo(p(-0.12, 0.46).dx, p(-0.12, 0.46).dy)
          ..lineTo(p(0.24, -0.12).dx, p(0.24, -0.12).dy)
          ..lineTo(p(0.02, -0.12).dx, p(0.02, -0.12).dy)
          ..close();
        canvas.drawPath(bolt, solid);
        break;

      case 'Expert':
        canvas.drawPath(_star(c, r), fill);
        canvas.drawPath(_star(c, r), stroke);
        canvas.drawCircle(c, r * 0.17, solid);
        break;

      case 'Master':
        final diamond = (double s) => Path()
          ..moveTo(p(0, -0.92 * s).dx, p(0, -0.92 * s).dy)
          ..lineTo(p(0.85 * s, 0).dx, p(0.85 * s, 0).dy)
          ..lineTo(p(0, 0.92 * s).dx, p(0, 0.92 * s).dy)
          ..lineTo(p(-0.85 * s, 0).dx, p(-0.85 * s, 0).dy)
          ..close();
        canvas.drawPath(diamond(1), fill);
        canvas.drawPath(diamond(1), stroke);
        canvas.drawPath(diamond(0.55), stroke);
        canvas.drawCircle(c, r * 0.13, solid);
        break;

      case 'Grandmaster':
        final crown = Path()
          ..moveTo(p(-0.72, 0.34).dx, p(-0.72, 0.34).dy)
          ..lineTo(p(-0.72, -0.28).dx, p(-0.72, -0.28).dy)
          ..lineTo(p(-0.34, 0.02).dx, p(-0.34, 0.02).dy)
          ..lineTo(p(0, -0.46).dx, p(0, -0.46).dy)
          ..lineTo(p(0.34, 0.02).dx, p(0.34, 0.02).dy)
          ..lineTo(p(0.72, -0.28).dx, p(0.72, -0.28).dy)
          ..lineTo(p(0.72, 0.34).dx, p(0.72, 0.34).dy)
          ..close();
        canvas.drawPath(crown, fill);
        canvas.drawPath(crown, stroke);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromPoints(p(-0.72, 0.46), p(0.72, 0.66)),
            const Radius.circular(2),
          ),
          solid,
        );
        for (final (dx, dy) in const [(-0.72, -0.46), (0.0, -0.66), (0.72, -0.46)]) {
          canvas.drawCircle(p(dx, dy), r * 0.1, solid);
        }
        break;
    }
  }

  /// Regular [sides]-gon of radius [radius] centered at [c], first vertex
  /// at [startAngle] radians.
  Path _polygon(Offset c, double radius, int sides, double startAngle) {
    final path = Path();
    for (var i = 0; i < sides; i++) {
      final ang = startAngle + i * 2 * math.pi / sides;
      final pt = Offset(c.dx + radius * math.cos(ang), c.dy + radius * math.sin(ang));
      if (i == 0) {
        path.moveTo(pt.dx, pt.dy);
      } else {
        path.lineTo(pt.dx, pt.dy);
      }
    }
    return path.close();
  }

  /// Five-point star with outer radius [r].
  Path _star(Offset c, double r) {
    final path = Path();
    const outer = 0.92;
    const inner = 0.42;
    for (var i = 0; i < 10; i++) {
      final rad = (i.isEven ? outer : inner) * r;
      final ang = -math.pi / 2 + i * math.pi / 5;
      final pt = Offset(c.dx + rad * math.cos(ang), c.dy + rad * math.sin(ang));
      if (i == 0) {
        path.moveTo(pt.dx, pt.dy);
      } else {
        path.lineTo(pt.dx, pt.dy);
      }
    }
    return path.close();
  }

  @override
  bool shouldRepaint(covariant _RankEmblemPainter oldDelegate) =>
      oldDelegate.rank.name != rank.name;
}
