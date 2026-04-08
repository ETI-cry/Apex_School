// lib/screens/login_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../theme/apex_colors.dart';
import '../services/google_auth_service.dart';
import 'home_screen.dart';
import 'register_screen.dart';

/// ═══════════════════════════════════════════════════════════
/// APEX — Premium Login Screen
/// ═══════════════════════════════════════════════════════════

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _pwdCtrl = TextEditingController();
  bool _obscurePwd = true;
  bool _isLoading = false;
  late AnimationController _animCtrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();

    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut),
    );
    _slide = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero).animate(
      CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut),
    );
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _pwdCtrl.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _ensureFirestore(User user) async {
    final ref = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final snap = await ref.get();
    if (!snap.exists) {
      await ref.set({
        'uid': user.uid,
        'email': user.email ?? '',
        'name': user.displayName ?? 'Utilisateur',
        'photoUrl': user.photoURL ?? '',
        'status': 'online',
        'createdAt': FieldValue.serverTimestamp(),
        'lastSeen': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _pwdCtrl.text.trim(),
      );
      await _ensureFirestore(cred.user!);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const HomeScreen(),
          transitionsBuilder: (_, a, __, c) =>
              FadeTransition(opacity: a, child: c),
          transitionDuration: const Duration(milliseconds: 500),
        ),
      );
    } on FirebaseAuthException catch (e) {
      _showMsg(e.message ?? 'Erreur de connexion');
    } catch (_) {
      _showMsg('Une erreur est survenue');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loginGoogle() async {
    setState(() => _isLoading = true);
    try {
      final uc = await GoogleAuthService.signInWithGoogle();
      final user = uc.user;
      if (user == null) throw Exception('Google sign-in failed');
      if ((user.displayName ?? '').isEmpty) await user.updateDisplayName("Utilisateur");
      await _ensureFirestore(user);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const HomeScreen(),
          transitionsBuilder: (_, a, __, c) =>
              FadeTransition(opacity: a, child: c),
          transitionDuration: const Duration(milliseconds: 500),
        ),
      );
    } catch (_) {
      _showMsg("Erreur connexion Google");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showMsg(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: ApexColors.surfaceHigh,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ApexColors.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background radial glow
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0.3, -0.6),
                  radius: 1.5,
                  colors: [ApexColors.surfaceElev, ApexColors.background],
                ),
              ),
            ),
          ),
          // Content
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SlideTransition(
                position: _slide,
                child: FadeTransition(
                  opacity: _fade,
                  child: Column(
                    children: [
                      const SizedBox(height: 30),
                      // ── Logo ─
                      _buildLogo(),
                      const SizedBox(height: 20),
                      // ── Title ──
                      ShaderMask(
                        shaderCallback: (bounds) => ApexColors.primaryGradient
                            .createShader(Rect.fromLTWH(0, 0, bounds.width, bounds.height)),
                        child: const Text(
                          "Bienvenue",
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "Connectez-vous pour continuer",
                        style: TextStyle(
                          fontSize: 14,
                          color: ApexColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 32),
                      // ── Form ──
                      Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            _field(_emailCtrl, "Email", Icons.email_outlined),
                            const SizedBox(height: 14),
                            _passwordField(),
                            const SizedBox(height: 24),
                            // ── Login Button ──
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _login,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: ApexColors.primary,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      ApexColors.radiusMd,
                                    ),
                                  ),
                                  elevation: 0,
                                ).copyWith(
                                  shadowColor:
                                      const MaterialStatePropertyAll<Color>(
                                    ApexColors.primary,
                                      ),
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text(
                                        "Se connecter",
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 16,
                                          color: Colors.white,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // ── Divider ──
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Row(
                          children: [
                            Expanded(
                              child: Divider(
                                color: ApexColors.border,
                                thickness: 1,
                              ),
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              child: Text(
                                "ou",
                                style: TextStyle(
                                  fontSize: 13,
                                  color: ApexColors.textMuted,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Divider(
                                color: ApexColors.border,
                                thickness: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // ── Google Button ──
                      GestureDetector(
                        onTap: _isLoading ? null : _loginGoogle,
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: ApexColors.border,
                              width: 1.5,
                            ),
                            color: ApexColors.surface,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.15),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Image.asset(
                            'assets/images/google.png',
                            width: 28,
                            height: 28,
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      // ── Register Link ──
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Pas de compte ? ",
                            style: TextStyle(
                              color: ApexColors.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                          GestureDetector(
                            onTap: () => Navigator.pushReplacement(
                              context,
                              PageRouteBuilder(
                                pageBuilder: (_, __, ___) =>
                                    const RegisterScreen(),
                                transitionsBuilder: (_, a, __, c) =>
                                    FadeTransition(opacity: a, child: c),
                                transitionDuration:
                                    const Duration(milliseconds: 400),
                              ),
                            ),
                            child: Text(
                              "S'inscrire",
                              style: TextStyle(
                                color: ApexColors.primary,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      width: 90,
      height: 90,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: ApexColors.primaryGradient,
        boxShadow: [
          BoxShadow(
            color: ApexColors.primary.withOpacity(0.30),
            blurRadius: 28,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Image.asset(
          'assets/images/preview.jpg',
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label,
    IconData icon,
  ) {
    return TextFormField(
      controller: ctrl,
      style: const TextStyle(color: ApexColors.textPrimary, fontSize: 15),
      keyboardType: TextInputType.emailAddress,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: ApexColors.primary, size: 20),
        filled: true,
        fillColor: ApexColors.surface,
      ),
      validator: (v) {
        if (v == null || v.trim().isEmpty) return "$label requis";
        final r = RegExp(r'^[\w\-\.]+@([\w\-]+\.)+[\w\-]{2,}$');
        if (!r.hasMatch(v.trim())) return "Email invalide";
        return null;
      },
    );
  }

  Widget _passwordField() {
    return TextFormField(
      controller: _pwdCtrl,
      obscureText: _obscurePwd,
      style: const TextStyle(color: ApexColors.textPrimary, fontSize: 15),
      decoration: InputDecoration(
        labelText: "Mot de passe",
        prefixIcon: Icon(Icons.lock_outline, color: ApexColors.primary, size: 20),
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePwd ? Icons.visibility_off : Icons.visibility,
            color: ApexColors.textMuted,
            size: 20,
          ),
          onPressed: () => setState(() => _obscurePwd = !_obscurePwd),
        ),
        filled: true,
        fillColor: ApexColors.surface,
      ),
      validator: (v) {
        if (v == null || v.isEmpty) return "Mot de passe requis";
        if (v.trim().length < 6) return "Minimum 6 caractères";
        return null;
      },
    );
  }
}
