import 'package:flutter/material.dart';

/// ═══════════════════════════════════════════════════════════
/// APEX DESIGN SYSTEM — Colors
/// ═══════════════════════════════════════════════════════════
/// Palette extraite du logo Apex (A géométrique Navy/Teal)
/// Chaque couleur est calibrée pour un rendu premium et cohérent.
/// ═══════════════════════════════════════════════════════════

class ApexColors {
  // ── Background ──
  static const Color background = Color(0xFF080C10);
  static const Color backgroundLight = Color(0xFFF8FAFC);

  // ── Surfaces ──
  static const Color surface     = Color(0xFF0F1623);
  static const Color surfaceElev = Color(0xFF151E2D);
  static const Color surfaceHigh = Color(0xFF1A2636);

  // ── Primary (gradient stop A) ──
  static const Color primary     = Color(0xFF0EA5E9); // sky blue
  static const Color primaryDark = Color(0xFF0284C7);

  // ── Accent (gradient stop B) ──
  static const Color accent     = Color(0xFF0891B2); // teal
  static const Color accentLight = Color(0xFF06B6D4);

  // ── Gradient principal ──
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, accent],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient primaryGradientReverse = LinearGradient(
    colors: [accentLight, primary],
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
  );

  // ── Text ─
  static const Color textPrimary   = Color(0xFFF1F5F9);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted     = Color(0xFF64748B);

  // ── Feedback ──
  static const Color error      = Color(0xFFEF4444);
  static const Color success    = Color(0xFF10B981);
  static const Color warning    = Color(0xFFF59E0B);

  // ── Borders ──
  static const Color border       = Color(0xFF1E293B);
  static const Color borderLight  = Color(0xFFE2E8F0);
  static const Color borderAccent = Color(0xFF38BDF8);

  // ── Opacities ──
  static Color primary10 = primary.withOpacity(0.10);
  static Color primary20 = primary.withOpacity(0.20);
  static Color accent10  = accent.withOpacity(0.10);

  // ── Shapes ──
  static const double radiusSm   = 8;
  static const double radiusMd   = 12;
  static const double radiusLg   = 16;
  static const double radiusXl   = 20;
  static const double radiusFull = 9999;

  // ── Shadows ──
  static List<BoxShadow> shadowSm = [
    BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 4, offset: const Offset(0, 2)),
  ];
  static List<BoxShadow> shadowMd = [
    BoxShadow(color: Colors.black.withOpacity(0.20), blurRadius: 12, offset: const Offset(0, 4)),
  ];
  static List<BoxShadow> shadowGlow = [
    BoxShadow(color: primary.withOpacity(0.35), blurRadius: 20, offset: const Offset(0, 4)),
  ];
}
