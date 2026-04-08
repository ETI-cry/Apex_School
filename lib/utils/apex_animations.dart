import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/apex_colors.dart';

/// ═══════════════════════════════════════════════════════════
/// APEX — Animation utility classes
/// ═══════════════════════════════════════════════════════════

class ApexAnimations {
  static const Duration fast   = Duration(milliseconds: 200);
  static const Duration medium = Duration(milliseconds: 300);
  static const Duration slow   = Duration(milliseconds: 500);
  static const Duration hero   = Duration(milliseconds: 800);

  static const Curve standardEase = Curves.easeOutCubic;
  static const Curve spring       = Curves.easeOutBack;
  static const Curve decelerate   = Curves.decelerate;
}

// ── Fade + Scale widget ──
class AnimatedFade extends StatelessWidget {
  final Widget child;
  final bool visible;
  final Duration delay;

  const AnimatedFade({
    super.key,
    required this.child,
    required this.visible,
    this.delay = Duration.zero,
  });

  @override
  Widget build(BuildContext context) =>
      AnimatedOpacity(
        opacity: visible ? 1.0 : 0.0,
        duration: ApexAnimations.medium,
        curve: ApexAnimations.standardEase,
        child: visible ? child : null,
      );
}

// ── Glow container around any child ──
class GlowContainer extends StatelessWidget {
  final Widget child;
  final Color color;
  final double blurRadius;
  final double radius;

  const GlowContainer({
    super.key,
    required this.child,
    this.color = const Color(0xFF0EA5E9),
    this.blurRadius = 20,
    this.radius = 16,
  });

  @override
  Widget build(BuildContext context) =>
      Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.35),
              blurRadius: blurRadius,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: child,
      );
}

// ── Glass panel — semi-transparent + border ──
class GlassPanel extends StatelessWidget {
  final Widget child;
  final double blur;
  final EdgeInsets padding;
  final double radius;

  const GlassPanel({
    super.key,
    required this.child,
    this.blur = 12,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    this.radius = 16,
  });

  @override
  Widget build(BuildContext context) =>
      BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: ApexColors.surface.withOpacity(0.7),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: ApexColors.border.withOpacity(0.5),
              width: 1,
            ),
          ),
          child: child,
        ),
      );
}

// ── Page route builder — shared animation ──
PageRouteBuilder<T> apexPageRoute<T>(
  Widget page, {
  Duration duration = const Duration(milliseconds: 350),
}) =>
    PageRouteBuilder(
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, a, __, child) =>
          SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.06),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: a, curve: ApexAnimations.standardEase)),
            child: FadeTransition(opacity: a, child: child),
          ),
      transitionDuration: duration,
    );
