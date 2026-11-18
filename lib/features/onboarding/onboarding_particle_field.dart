import 'dart:math' as math;
import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';

import '../../core/design_system/app_colors.dart';

/// A deterministic particle field shared by the count, recall, and impact pages.
/// The same particle index keeps its place as the field fills, scatters, and
/// reshapes into a human profile.
class OnboardingParticleField extends StatelessWidget {
  const OnboardingParticleField({
    super.key,
    required this.size,
    required this.formation,
    this.flow = 0,
    this.turbulence = 0,
    this.scatter = 0,
    this.headMorph = 0,
    this.child,
  });

  final Size size;
  final double formation;
  final double flow;
  final double turbulence;
  final double scatter;
  final double headMorph;
  final Widget? child;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size.width,
    height: size.height,
    child: CustomPaint(
      painter: _OnboardingParticlePainter(
        formation: formation,
        flow: flow,
        turbulence: turbulence,
        scatter: scatter,
        headMorph: headMorph,
      ),
      child: child,
    ),
  );
}

class _OnboardingParticlePainter extends CustomPainter {
  const _OnboardingParticlePainter({
    required this.formation,
    required this.flow,
    required this.turbulence,
    required this.scatter,
    required this.headMorph,
  });

  static const _maxDots = 3600;
  static const _goldenAngle = 2.399963229728653;

  final double formation;
  final double flow;
  final double turbulence;
  final double scatter;
  final double headMorph;

  @override
  void paint(Canvas canvas, Size size) {
    final formed = formation.clamp(0.0, 1.0);
    final scattered = scatter.clamp(0.0, 1.0);
    final morphed = Curves.easeInOutCubic.transform(headMorph.clamp(0.0, 1.0));
    final count = (100 + formed * (_maxDots - 100)).round();
    final center = size.center(Offset.zero);
    final sphereRadius = size.shortestSide * (0.12 + 0.36 * formed);
    final profileMetric = morphed > 0
        ? _headProfile(size).computeMetrics().first
        : null;
    final paint = Paint()..style = PaintingStyle.fill;

    for (var index = 0; index < count; index++) {
      final fraction = (index + 0.5) / _maxDots;
      final stagger = (index * 37 % 151) / 151 * 0.16;
      final arrival = Curves.easeOutCubic.transform(
        ((formed - stagger) / (1 - stagger)).clamp(0.0, 1.0),
      );
      if (arrival <= 0) continue;

      final angle = index * _goldenAngle + flow * math.pi * 0.34;
      final radius = math.sqrt(fraction) * sphereRadius;
      final sphere = center + Offset(math.cos(angle), math.sin(angle)) * radius;
      final startAngle = index * 0.73;
      final start =
          center +
          Offset(math.cos(startAngle), math.sin(startAngle)) *
              size.shortestSide *
              (0.55 + (index * 19 % 97) / 97 * 0.65);
      var point = Offset.lerp(start, sphere, arrival)!;

      if (morphed > 0 && profileMetric != null) {
        final head = _headPoint(index, size, profileMetric);
        final individualMorph = Curves.easeInOut.transform(
          ((morphed - (index * 17 % 113) / 113 * 0.18) / 0.82).clamp(0.0, 1.0),
        );
        point = Offset.lerp(point, head, individualMorph)!;
      }

      final outward = point - center;
      final wave = math.sin(index * 0.41 + flow * math.pi * 5);
      point += Offset(-outward.dy, outward.dx) * (turbulence * wave * 0.055);
      point += outward * scattered * (0.25 + (index % 7) * 0.045);

      final headInterior = morphed > 0 && index >= 780;
      final brightness = headInterior
          ? 0.10 + (index % 6) * 0.025
          : 0.25 + (index % 7) * 0.075;
      paint.color = AppColors.textOnDark.withValues(
        alpha: (brightness * arrival * (1 - scattered)).clamp(0.0, 1.0),
      );
      canvas.drawCircle(point, 0.55 + (index % 5) * 0.25, paint);
    }
  }

  Offset _headPoint(int index, Size size, PathMetric metric) {
    if (index < 780) {
      final distance = metric.length * (index / 779);
      return metric.getTangentForOffset(distance)!.position;
    }
    final fraction = (index - 780 + 0.5) / (_maxDots - 780);
    final angle = index * _goldenAngle;
    final radius = math.sqrt(fraction);
    return Offset(
      size.width * 0.48 + math.cos(angle) * radius * size.width * 0.26,
      size.height * 0.40 + math.sin(angle) * radius * size.height * 0.22,
    );
  }

  Path _headProfile(Size size) => Path()
    ..moveTo(size.width * 0.18, size.height * 0.88)
    ..cubicTo(
      size.width * 0.12,
      size.height * 0.68,
      size.width * 0.10,
      size.height * 0.38,
      size.width * 0.24,
      size.height * 0.20,
    )
    ..cubicTo(
      size.width * 0.39,
      size.height * 0.02,
      size.width * 0.68,
      size.height * 0.04,
      size.width * 0.77,
      size.height * 0.25,
    )
    ..lineTo(size.width * 0.79, size.height * 0.38)
    ..lineTo(size.width * 0.91, size.height * 0.52)
    ..lineTo(size.width * 0.78, size.height * 0.57)
    ..cubicTo(
      size.width * 0.81,
      size.height * 0.67,
      size.width * 0.73,
      size.height * 0.75,
      size.width * 0.60,
      size.height * 0.78,
    )
    ..lineTo(size.width * 0.60, size.height * 0.94);

  @override
  bool shouldRepaint(covariant _OnboardingParticlePainter oldDelegate) =>
      oldDelegate.formation != formation ||
      oldDelegate.flow != flow ||
      oldDelegate.turbulence != turbulence ||
      oldDelegate.scatter != scatter ||
      oldDelegate.headMorph != headMorph;
}
