// lib/screens/register_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/apex_colors.dart';
import '../services/google_auth_service.dart';
import 'home_screen.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _pseudoCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  int _pwdStrength = 0;
  bool _isLoading = false;
  late AnimationController _animCtrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _passwordCtrl.addListener(_checkStrength);

    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut),
    );
    _slide = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));

    _animCtrl.forward();
  }

  @override
  void dispose() {
    _pseudoCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  void _checkStrength() {
    final p = _passwordCtrl.text;
    if (p.isEmpty) {
      _pwdStrength = 0;
    } else if (p.length < 6) {
      _pwdStrength = 1;
    } else if (p.length < 10) {
      _pwdStrength = 2;
    } else {
      _pwdStrength = 3;
    }
    setState(() {});
  }

  Color _segColor(int i) {
    if (_pwdStrength >= i) {
      return _pwdStrength == 1
          ? ApexColors.error
          : _pwdStrength == 2 ? ApexColors.warning : ApexColors.success;
    }
    return ApexColors.border;
  }

  Future<void> _createUser(User user, {required String name}) async {
    final ref = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final snap = await ref.get();
    if (!snap.exists) {
      await ref.set({
        'uid': user.uid,
        'email': user.email ?? '',
        'name': name,
        'photoUrl': user.photoURL ?? '',
        'status': 'online',
        'createdAt': FieldValue.serverTimestamp(),
        'lastSeen': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    if (_passwordCtrl.text.trim() != _confirmCtrl.text.trim()) {
      _showMsg("Les mots de passe ne correspondent pas");
      return;
    }
    setState(() => _isLoading = true);
    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text.trim(),
      );
      final user = cred.user!;
      await user.updateDisplayName(_pseudoCtrl.text.trim());
      await _createUser(user, name: _pseudoCtrl.text.trim());
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
      _showMsg(e.message ?? 'Erreur inscription');
    } catch (_) {
      _showMsg('Une erreur est survenue');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _registerGoogle() async {
    setState(() => _isLoading = true);
    try {
      final uc = await GoogleAuthService.signInWithGoogle();
      final user = uc.user;
      if (user == null) throw Exception('Google sign-in failed');
      if ((user.displayName ?? '').isEmpty) {
        await user.updateDisplayName("Utilisateur");
      }
      await _createUser(user, name: user.displayName ?? "Utilisateur");
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
          // Background decorative gradient
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(-0.3, -0.5),
                  radius: 1.5,
                  colors: [
                    ApexColors.surfaceElev,
                    ApexColors.background,
                  ],
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
                      const SizedBox(height: 20),
                      // Logo
                      _buildLogo(),
                      const SizedBox(height: 16),
                      // Title
                      const Text(
                        "Créer un compte",
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: ApexColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "Rejoignez la communauté Apex",
                        style: TextStyle(
                          fontSize: 14,
                          color: ApexColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 28),
                      // Form
                      Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            _field(_pseudoCtrl, "Pseudo", Icons.person),
                            const SizedBox(height: 14),
                            _field(_emailCtrl, "Email", Icons.email_outlined),
                            const SizedBox(height: 14),
                            _passwordField(
                              _passwordCtrl,
                              "Mot de passe",
                              _obscurePassword,
                              () => setState(() => _obscurePassword = !_obscurePassword),
                            ),
                            // Password strength
                            if (_pwdStrength > 0)
                              Padding(
                                padding: const EdgeInsets.only(top: 10, bottom: 4),
                                child: Row(
                                  children: [
                                    for (int i = 1; i <= 3; i++)
                                      Expanded(
                                        child: AnimatedContainer(
                                          duration: const Duration(milliseconds: 300),
                                          margin: const EdgeInsets.symmetric(horizontal: 2),
                                          height: 4,
                                          decoration: BoxDecoration(
                                            color: _segColor(i),
                                            borderRadius: BorderRadius.circular(4),
                                            boxShadow: _pwdStrength >= i
                                                ? [
                                                    BoxShadow(
                                                      color: _segColor(i)
                                                          .withOpacity(0.4),
                                                      blurRadius: 6,
                                                    ),
                                                  ]
                                                : [],
                                          ),
                                        ),
                                      ),
                                    const SizedBox(width: 10),
                                    Text(
                                      _pwdStrength == 1
                                          ? 'Faible'
                                          : _pwdStrength == 2
                                              ? 'Moyen'
                                              : 'Fort',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: _segColor(_pwdStrength),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 10),
                            _passwordField(
                              _confirmCtrl,
                              "Confirmer",
                              _obscureConfirm,
                              () => setState(() => _obscureConfirm = !_obscureConfirm),
                              confirm: true,
                            ),
                            const SizedBox(height: 24),
                            // Register button
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _register,
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
                                      const WidgetStatePropertyAll<Color>(
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
                                        "S'inscrire",
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
                      // Divider
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
                      // Google button
                      GestureDetector(
                        onTap: _isLoading ? null : _registerGoogle,
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
                      const SizedBox(height: 28),
                      // Login link
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Déjà un compte ? ",
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
                                    const LoginScreen(),
                                transitionsBuilder: (_, a, __, c) =>
                                    FadeTransition(opacity: a, child: c),
                                transitionDuration:
                                    const Duration(milliseconds: 400),
                              ),
                            ),
                            child: Text(
                              "Se connecter",
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
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: ApexColors.primaryGradient,
        boxShadow: [
          BoxShadow(
            color: ApexColors.primary.withOpacity(0.30),
            blurRadius: 24,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Image.asset(
          'assets/images/preview.jpg',
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, IconData icon) {
    return TextFormField(
      controller: ctrl,
      style: const TextStyle(
        color: ApexColors.textPrimary,
        fontSize: 15,
      ),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: ApexColors.primary, size: 20),
        filled: true,
        fillColor: ApexColors.surface,
      ),
      validator: (v) {
        if (v == null || v.trim().isEmpty) return "$label requis";
        if (label == 'Email') {
          final r = RegExp(r'^[\w\-\.]+@([\w\-]+\.)+[\w\-]{2,}$');
          if (!r.hasMatch(v.trim())) return "Email invalide";
        }
        if (label == 'Pseudo' && v.trim().length < 2) {
          return "Minimum 2 caractères";
        }
        return null;
      },
    );
  }

  Widget _passwordField(
    TextEditingController ctrl,
    String label,
    bool obscure,
    VoidCallback toggle, {
    bool confirm = false,
  }) {
    return TextFormField(
      controller: ctrl,
      obscureText: obscure,
      style: const TextStyle(color: ApexColors.textPrimary, fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(Icons.lock_outline, color: ApexColors.primary, size: 20),
        suffixIcon: IconButton(
          icon: Icon(
            obscure ? Icons.visibility_off : Icons.visibility,
            color: ApexColors.textMuted,
            size: 20,
          ),
          onPressed: toggle,
        ),
        filled: true,
        fillColor: ApexColors.surface,
      ),
      validator: (v) {
        if (v == null || v.isEmpty) return "$label requis";
        if (!confirm && v.trim().length < 6) return "Minimum 6 caractères";
        return null;
      },
    );
  }
}
