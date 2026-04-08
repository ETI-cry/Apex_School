import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/apex_colors.dart';
import 'login_screen.dart';

/// ═══════════════════════════════════════════════════════════
/// APEX — Premium Splash Screen
/// ═══════════════════════════════════════════════════════════

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _logoScale;
  late Animation<double> _logoFade;
  late Animation<double> _titleOpacity;
  late Animation<Offset> _titleSlide;
  late Animation<double> _taglineOpacity;
  late Animation<Offset> _taglineSlide;

  bool _lettersVisible = false;
  final String _brand = 'APEX';

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    // Logo animation
    _logoScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOutBack),
      ),
    );

    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

    // Title animation
    _titleOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.4, 0.7, curve: Curves.easeOut),
      ),
    );

    _titleSlide = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.4, 0.7, curve: Curves.easeOut),
      ),
    );

    // Tagline animation
    _taglineOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.6, 0.85, curve: Curves.easeOut),
      ),
    );

    _taglineSlide = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.6, 0.85, curve: Curves.easeOut),
      ),
    );

    _controller.forward();

    // After logo appears, reveal letters one by one
    Timer(const Duration(milliseconds: 600), () {
      setState(() => _lettersVisible = true);
    });

    // Navigate after animation
    Timer(const Duration(milliseconds: 3200), () {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const LoginScreen(),
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 700),
        ),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ApexColors.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background radial gradient
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, -0.3),
                  radius: 1.2,
                  colors: [
                    ApexColors.surfaceElev,
                    ApexColors.background,
                    ApexColors.background,
                  ],
                ),
              ),
            ),
          ),

          // Geometric accent — faint rotated triangle
          Positioned.fill(
            child: AnimatedOpacity(
              opacity: _logoFade.value * 0.04,
              duration: const Duration(milliseconds: 800),
              child: CustomPaint(
                painter: _TrianglePainter(),
              ),
            ),
          ),

          // Center content
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ── Logo ─
                ScaleTransition(
                  scale: _logoScale,
                  child: FadeTransition(
                    opacity: _logoFade,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(30),
                        gradient: LinearGradient(
                          colors: [
                            ApexColors.primary,
                            ApexColors.accent,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: ApexColors.primary.withOpacity(0.30),
                            blurRadius: 30,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(30),
                        child: Image.asset(
                          'assets/images/preview.jpg',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                // ── Title "APEX" ──
                SlideTransition(
                  position: _titleSlide,
                  child: FadeTransition(
                    opacity: _titleOpacity,
                    child: ShaderMask(
                      shaderCallback: (bounds) {
                        return ApexColors.primaryGradient.createShader(
                          Rect.fromLTWH(0, 0, bounds.width, bounds.height),
                        );
                      },
                      child: const Text(
                        'APEX',
                        style: TextStyle(
                          fontSize: 38,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 6,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // ── Tagline ──
                SlideTransition(
                  position: _taglineSlide,
                  child: FadeTransition(
                    opacity: _taglineOpacity,
                    child: Text(
                      'Excellence au quotidien',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: ApexColors.textSecondary,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Bottom loader ──
          Positioned(
            bottom: 48,
            left: 0,
            right: 0,
            child: FadeTransition(
              opacity: _titleOpacity,
              child: Column(
                children: [
                  LoadingDots(),
                  const SizedBox(height: 16),
                  Text(
                    'Powered by APEX',
                    style: TextStyle(
                      fontSize: 11,
                      color: ApexColors.textMuted,
                      letterSpacing: 2,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Geometric triangle painter (background accent) ──
class _TrianglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = ApexColors.accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final center = Offset(size.width / 2, size.height * 0.35);
    final s = size.width * 0.6;

    canvas.save();
    canvas.translate(center.dx, center.dy);

    final path = Path()
      ..moveTo(0, -s * 0.4)
      ..lineTo(s * 0.35, s * 0.15)
      ..lineTo(-s * 0.35, s * 0.15)
      ..close();

    // Draw two overlapping triangles (like the logo A)
    canvas.drawPath(path, paint);
    canvas.scale(-1, 1);
    canvas.drawPath(path, paint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Animated loading dots ──
class LoadingDots extends StatefulWidget {
  const LoadingDots({super.key});
  @override
  State<LoadingDots> createState() => _LoadingDotsState();
}

class _LoadingDotsState extends State<LoadingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _dotController;
  late Animation<double> _progress;

  @override
  void initState() {
    super.initState();
    _dotController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    _progress = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _dotController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _dotController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _progress,
      builder: (_, __) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(3, (i) {
          final scale = _dotController.status == AnimationStatus.completed
              ? (i == 0 ? 0.6 : 1.0)
              : (i == 0 ? 1.0 : 0.6);
          final t = (_dotController.value + i / 3) % 1.0;
          final size = 6.0 + 4.0 * (1 - (t.abs() * 2 - 1).abs());
          return AnimatedContainer(
            duration: Duration.zero,
            margin: const EdgeInsets.symmetric(horizontal: 5),
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: ApexColors.primaryGradient,
            ),
          );
        }),
      ),
    );
  }
}
