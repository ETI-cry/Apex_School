import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../theme/apex_colors.dart';
import 'package:flutter/services.dart';

/// ------------------------------------------------------------------------------------------------
/// SettingsModal Premium
/// - Design ultra premium: champs avec labels, focus states, helpers, icônes, gradients subtils.
/// - Boutons compacts (pas en pleine largeur), animations de loader intégrés, hover/press.
/// - Hiérarchie visuelle nette par sections (pseudo, email, mot de passe, statut, déconnexion).
/// - Conserve totalement la logique existante FirebaseAuth/Firestore (aucun changement de workflow).
/// - Ajouts UX: Password strength bar, visibility toggles, tooltips, feedback inline.
/// ------------------------------------------------------------------------------------------------

class SettingsModal extends StatefulWidget {
  final bool isDarkMode;
  final String userName;
  final String userEmail;

  const SettingsModal({
    super.key,
    required this.isDarkMode,
    required this.userName,
    required this.userEmail,
  });

  @override
  State<SettingsModal> createState() => _SettingsModalState();
}

/// ------------------------------------------------------------------------------------------------
/// Design tokens & helpers (premium)
/// ------------------------------------------------------------------------------------------------

class _SettingsModalState extends State<SettingsModal>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnim;
  late Animation<Offset> _slideAnim;

  String userStatus = 'online';
  bool _loadingStatus = false;

  // Controllers pour identifiants
  final TextEditingController _displayNameCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _currentPasswordForEmailCtrl = TextEditingController();

  // Controllers pour mot de passe
  final TextEditingController _currentPasswordCtrl = TextEditingController();
  final TextEditingController _newPasswordCtrl = TextEditingController();
  final TextEditingController _confirmPasswordCtrl = TextEditingController();

  // FocusNodes pour états de focus premium
  final FocusNode _displayNameFocus = FocusNode();
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _currentEmailPassFocus = FocusNode();
  final FocusNode _currentPassFocus = FocusNode();
  final FocusNode _newPassFocus = FocusNode();
  final FocusNode _confirmPassFocus = FocusNode();

  bool _savingName = false;
  bool _savingEmail = false;
  bool _savingPassword = false;

  // Toggles visibilité
  bool _showCurrentEmailPassword = false;
  bool _showCurrentPassword = false;
  bool _showNewPassword = false;
  bool _showConfirmPassword = false;

  // Password strength
  double _pwdStrength = 0.0;
  String _pwdLabel = '';

  final statusOptions = [
    {'value': 'online', 'label': 'En ligne', 'color': const Color(0xFF22C55E)},
    {'value': 'dnd', 'label': 'Ne pas déranger', 'color': const Color(0xFFEF4444)},
    {'value': 'offline', 'label': 'Hors ligne', 'color': const Color(0xFF9CA3AF)},
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _opacityAnim = Tween<double>(begin: 0, end: 1).animate(_controller);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    // Pré-remplissage
    _displayNameCtrl.text = widget.userName;
    _emailCtrl.text = widget.userEmail;

    // Listeners pour focus styling
    _displayNameFocus.addListener(_refresh);
    _emailFocus.addListener(_refresh);
    _currentEmailPassFocus.addListener(_refresh);
    _currentPassFocus.addListener(_refresh);
    _newPassFocus.addListener(_refresh);
    _confirmPassFocus.addListener(_refresh);

    // Listener pour strength
    _newPasswordCtrl.addListener(_updateStrength);

    _controller.forward();
    _loadInitialStatus();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _updateStrength() {
    final text = _newPasswordCtrl.text;
    final strength = _calculateStrength(text);
    setState(() {
      _pwdStrength = strength;
      _pwdLabel = _strengthLabel(strength);
    });
  }

  double _calculateStrength(String pwd) {
    if (pwd.isEmpty) return 0.0;
    int score = 0;
    if (pwd.length >= 8) score++;
    if (RegExp(r'[A-Z]').hasMatch(pwd)) score++;
    if (RegExp(r'[a-z]').hasMatch(pwd)) score++;
    if (RegExp(r'[0-9]').hasMatch(pwd)) score++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(pwd)) score++;
    return (score / 5).clamp(0.0, 1.0);
  }

  String _strengthLabel(double s) {
    if (s == 0) return '';
    if (s < 0.3) return 'Faible';
    if (s < 0.6) return 'Moyen';
    if (s < 0.85) return 'Bon';
    return 'Excellent';
  }

  @override
  void dispose() {
    _controller.dispose();

    _displayNameCtrl.dispose();
    _emailCtrl.dispose();
    _currentPasswordForEmailCtrl.dispose();

    _currentPasswordCtrl.dispose();
    _newPasswordCtrl.dispose();
    _confirmPasswordCtrl.dispose();

    _displayNameFocus.dispose();
    _emailFocus.dispose();
    _currentEmailPassFocus.dispose();
    _currentPassFocus.dispose();
    _newPassFocus.dispose();
    _confirmPassFocus.dispose();
    super.dispose();
  }

  Future<void> _loadInitialStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final data = doc.data();
      if (data != null && data['status'] is String) {
        setState(() => userStatus = data['status'] as String);
      }
    } catch (_) {
      // ignore pour UX
    }
  }

  Future<void> _setUserStatus(String status) async {
    if (_loadingStatus) return;
    setState(() {
      userStatus = status;
      _loadingStatus = true;
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _loadingStatus = false);
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'status': status,
        'lastSeen': FieldValue.serverTimestamp(),
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Statut mis à jour : $status"),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erreur mise à jour statut : $e"),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _loadingStatus = false);
    }
  }

  Future<void> _handleLogout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pop(context);
    Navigator.pushReplacementNamed(context, "/login");
  }

  // Ré-auth pour email/password (EmailAuthProvider)
  Future<void> _reauthenticate(String email, String currentPassword) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("Utilisateur non connecté");
    final cred = EmailAuthProvider.credential(email: email, password: currentPassword);
    await user.reauthenticateWithCredential(cred);
  }

  Future<void> _saveDisplayName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final newName = _displayNameCtrl.text.trim();
    if (newName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Le pseudo ne peut pas être vide."),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _savingName = true);
    try {
      await user.updateDisplayName(newName);
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({'name': newName}, SetOptions(merge: true));

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Pseudo mis à jour ✅"),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erreur mise à jour du pseudo : $e"),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _savingName = false);
    }
  }

  Future<void> _saveEmail() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final newEmail = _emailCtrl.text.trim();
    final currentPassword = _currentPasswordForEmailCtrl.text.trim();

    if (newEmail.isEmpty || !newEmail.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Email invalide."),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (currentPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Entre ton mot de passe actuel pour valider."),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _savingEmail = true);
    try {
      // Ré-auth obligatoire avant updateEmail
      await _reauthenticate(user.email ?? newEmail, currentPassword);
      await user.updateEmail(newEmail);

      // Sync Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({'email': newEmail}, SetOptions(merge: true));

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Email mis à jour ✅"),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erreur Auth: ${e.message ?? e.code}"),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erreur : $e"),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _savingEmail = false);
    }
  }

  Future<void> _savePassword() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final current = _currentPasswordCtrl.text.trim();
    final newP = _newPasswordCtrl.text.trim();
    final confirmP = _confirmPasswordCtrl.text.trim();

    if (current.isEmpty || newP.isEmpty || confirmP.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Tous les champs mot de passe sont requis."),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (newP.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Le nouveau mot de passe doit contenir au moins 6 caractères."),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (newP != confirmP) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("La confirmation ne correspond pas."),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _savingPassword = true);
    try {
      // Ré-auth obligatoire avant updatePassword
      final email = FirebaseAuth.instance.currentUser?.email;
      if (email == null || email.isEmpty) {
        throw Exception("Email utilisateur introuvable pour ré-auth.");
      }
      await _reauthenticate(email, current);
      await user.updatePassword(newP);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Mot de passe mis à jour ✅"),
          behavior: SnackBarBehavior.floating,
        ),
      );

      // Nettoie les champs
      _currentPasswordCtrl.clear();
      _newPasswordCtrl.clear();
      _confirmPasswordCtrl.clear();
      setState(() {
        _pwdStrength = 0.0;
        _pwdLabel = '';
      });
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erreur Auth: ${e.message ?? e.code}"),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erreur : $e"),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _savingPassword = false);
    }
  }

  Color get _accent => Color(0xFF0EA5E9);

  Color get _bgColor => widget.isDarkMode ? const Color(0xFF121212) : const Color(0xFFFDFDFD);
  Color get _cardStart => widget.isDarkMode ? const Color(0xFF1A1A1A) : const Color(0xFFFFFFFF);
  Color get _cardEnd => widget.isDarkMode ? const Color(0xFF202020) : const Color(0xFFF9FBFF);
  Color get _textColor => widget.isDarkMode ? Colors.white : const Color(0xFF111827);
  Color get _mutedText => widget.isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600;
  Color get _inputFill => widget.isDarkMode ? const Color(0xFF222222) : const Color(0xFFF3F4F6);
  Color get _borderColor => widget.isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300;

  OutlineInputBorder _outline({required bool focused, required bool error}) {
    final base = _borderColor;
    final focusColor = _accent;
    final errColor = Colors.red;
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(
        color: error ? errColor : (focused ? focusColor : base),
        width: focused ? 1.6 : 1.0,
      ),
    );
  }

  InputDecoration premiumDec({
    required String label,
    String? hint,
    String? helper,
    Widget? prefixIcon,
    Widget? suffixIcon,
    required bool focused,
    bool error = false,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      helperText: helper,
      filled: true,
      fillColor: _inputFill,
      labelStyle: TextStyle(color: focused ? _accent : _mutedText, fontWeight: FontWeight.w600),
      hintStyle: TextStyle(color: _mutedText),
      helperStyle: TextStyle(color: _mutedText),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      enabledBorder: _outline(focused: false, error: error),
      focusedBorder: _outline(focused: true, error: error),
      errorBorder: _outline(focused: false, error: true),
      focusedErrorBorder: _outline(focused: true, error: true),
    );
  }

  Widget sectionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        // Subtil gradient + soft shadow premium
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_cardStart, _cardEnd],
        ),
        boxShadow: [
          BoxShadow(
            color: widget.isDarkMode ? Colors.black.withOpacity(0.25) : Colors.grey.withOpacity(0.15),
            blurRadius: 14,
            spreadRadius: 2,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: _borderColor, width: 0.8),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header section
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: _accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.all(8),
                child: Icon(icon, color: _accent, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                          color: _textColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        )),
                    const SizedBox(height: 2),
                    Text(subtitle, style: TextStyle(color: _mutedText, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget premiumButton({
    required String label,
    required VoidCallback? onTap,
    required bool loading,
    IconData? icon,
    Color? bg,
    Color? fg,
    EdgeInsets padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
  }) {
    final background = bg ?? _accent;
    final foreground = fg ?? Colors.white;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      child: InkWell(
        key: ValueKey('$label-$loading'),
        onTap: loading ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        splashColor: background.withOpacity(0.2),
        highlightColor: background.withOpacity(0.12),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: loading ? background.withOpacity(0.7) : background,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: background.withOpacity(0.35),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, color: foreground, size: 18),
                const SizedBox(width: 8),
              ],
              if (loading)
                const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              else
                Text(
                  label,
                  style: TextStyle(
                    color: foreground,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget ghostButton({
    required String label,
    required VoidCallback? onTap,
    IconData? icon,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _borderColor),
          color: widget.isDarkMode ? const Color(0xFF222222) : const Color(0xFFF9FAFB),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, color: _textColor, size: 18),
              const SizedBox(width: 8),
            ],
            Text(label, style: TextStyle(color: _textColor, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  /// ------------------------------------------------------------------------------------------------
  /// UI
  /// ------------------------------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: FadeTransition(
        opacity: _opacityAnim,
        child: Stack(
          children: [
            // Overlay
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                color: Colors.black.withOpacity(0.50),
              ),
            ),

            // Modal
            SlideTransition(
              position: _slideAnim,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _bgColor,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: _borderColor),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(widget.isDarkMode ? 0.45 : 0.12),
                        blurRadius: 28,
                        offset: const Offset(0, 18),
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        // Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: _accent.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(Icons.tune, color: _accent),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  "Paramètres",
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: _textColor,
                                  ),
                                ),
                              ],
                            ),
                            Tooltip(
                              message: "Fermer",
                              child: IconButton(
                                icon: Icon(Icons.close, color: _mutedText),
                                onPressed: () => Navigator.pop(context),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Profil
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: LinearGradient(
                              colors: [
                                _cardStart,
                                _cardEnd,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            border: Border.all(color: _borderColor),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 30,
                                backgroundColor: _accent,
                                child: Text(
                                  widget.userName.isNotEmpty ? widget.userName[0].toUpperCase() : "U",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.userName,
                                      style: TextStyle(
                                        color: _textColor,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 18,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(widget.userEmail, style: TextStyle(color: _mutedText, fontSize: 14)),
                                  ],
                                ),
                              ),
                              ghostButton(label: "Voir profil", onTap: () {}, icon: Icons.person_outline),
                            ],
                          ),
                        ),
                        const SizedBox(height: 22),

                        // Pseudo (displayName)
                        sectionCard(
                          title: "Changer le pseudo",
                          subtitle: "Modifie ton nom affiché",
                          icon: Icons.person,
                          child: Column(
                            children: [
                              TextField(
                                focusNode: _displayNameFocus,
                                controller: _displayNameCtrl,
                                style: TextStyle(color: _textColor, fontWeight: FontWeight.w600),
                                decoration: premiumDec(
                                  label: "Nouveau pseudo",
                                  hint: "Ex: Yann K.",
                                  helper: "Ton pseudo sera visible par tes camarades.",
                                  prefixIcon: Icon(Icons.person_outline, color: _mutedText),
                                  focused: _displayNameFocus.hasFocus,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  // Boutons compacts alignés à droite
                                  const Spacer(),
                                  ghostButton(
                                    label: "Annuler",
                                    onTap: () {
                                      _displayNameCtrl.text = widget.userName;
                                      FocusScope.of(context).unfocus();
                                    },
                                  ),
                                  const SizedBox(width: 8),
                                  premiumButton(
                                    label: "Enregistrer",
                                    icon: Icons.check_circle,
                                    onTap: _savingName ? null : _saveDisplayName,
                                    loading: _savingName,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Email
                        sectionCard(
                          title: "Changer l’email",
                          subtitle: "Met à jour ton adresse de connexion",
                          icon: Icons.email,
                          child: Column(
                            children: [
                              TextField(
                                focusNode: _emailFocus,
                                controller: _emailCtrl,
                                keyboardType: TextInputType.emailAddress,
                                style: TextStyle(color: _textColor, fontWeight: FontWeight.w600),
                                decoration: premiumDec(
                                  label: "Nouvel email",
                                  hint: "exemple@domaine.com",
                                  helper: "Nous t’enverrons peut-être une confirmation.",
                                  prefixIcon: Icon(Icons.alternate_email, color: _mutedText),
                                  focused: _emailFocus.hasFocus,
                                ),
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                focusNode: _currentEmailPassFocus,
                                controller: _currentPasswordForEmailCtrl,
                                obscureText: !_showCurrentEmailPassword,
                                style: TextStyle(color: _textColor, fontWeight: FontWeight.w600),
                                decoration: premiumDec(
                                  label: "Mot de passe actuel (ré-auth)",
                                  hint: "********",
                                  helper: "Sécurité: nécessaire pour confirmer le changement d’email.",
                                  prefixIcon: Icon(Icons.lock_outline, color: _mutedText),
                                  suffixIcon: IconButton(
                                    tooltip: _showCurrentEmailPassword ? "Masquer" : "Afficher",
                                    icon: Icon(
                                      _showCurrentEmailPassword ? Icons.visibility_off : Icons.visibility,
                                      color: _mutedText,
                                    ),
                                    onPressed: () => setState(() {
                                      _showCurrentEmailPassword = !_showCurrentEmailPassword;
                                    }),
                                  ),
                                  focused: _currentEmailPassFocus.hasFocus,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  const Spacer(),
                                  ghostButton(
                                    label: "Annuler",
                                    onTap: () {
                                      _emailCtrl.text = widget.userEmail;
                                      _currentPasswordForEmailCtrl.clear();
                                      FocusScope.of(context).unfocus();
                                    },
                                  ),
                                  const SizedBox(width: 8),
                                  premiumButton(
                                    label: "Enregistrer",
                                    icon: Icons.mail_lock,
                                    onTap: _savingEmail ? null : _saveEmail,
                                    loading: _savingEmail,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Mot de passe
                        sectionCard(
                          title: "Changer le mot de passe",
                          subtitle: "Sécurise ton compte",
                          icon: Icons.lock,
                          child: Column(
                            children: [
                              TextField(
                                focusNode: _currentPassFocus,
                                controller: _currentPasswordCtrl,
                                obscureText: !_showCurrentPassword,
                                style: TextStyle(color: _textColor, fontWeight: FontWeight.w600),
                                decoration: premiumDec(
                                  label: "Mot de passe actuel",
                                  hint: "********",
                                  helper: "Obligatoire pour autoriser la mise à jour.",
                                  prefixIcon: Icon(Icons.lock_outline, color: _mutedText),
                                  suffixIcon: IconButton(
                                    tooltip: _showCurrentPassword ? "Masquer" : "Afficher",
                                    icon: Icon(
                                      _showCurrentPassword ? Icons.visibility_off : Icons.visibility,
                                      color: _mutedText,
                                    ),
                                    onPressed: () => setState(() {
                                      _showCurrentPassword = !_showCurrentPassword;
                                    }),
                                  ),
                                  focused: _currentPassFocus.hasFocus,
                                ),
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                focusNode: _newPassFocus,
                                controller: _newPasswordCtrl,
                                obscureText: !_showNewPassword,
                                style: TextStyle(color: _textColor, fontWeight: FontWeight.w600),
                                decoration: premiumDec(
                                  label: "Nouveau mot de passe (min 6)",
                                  hint: "********",
                                  helper: "Astuce: mélange majuscules, chiffres et symboles.",
                                  prefixIcon: Icon(Icons.key, color: _mutedText),
                                  suffixIcon: IconButton(
                                    tooltip: _showNewPassword ? "Masquer" : "Afficher",
                                    icon: Icon(
                                      _showNewPassword ? Icons.visibility_off : Icons.visibility,
                                      color: _mutedText,
                                    ),
                                    onPressed: () => setState(() {
                                      _showNewPassword = !_showNewPassword;
                                    }),
                                  ),
                                  focused: _newPassFocus.hasFocus,
                                ),
                              ),
                              const SizedBox(height: 8),

                              // Strength bar premium
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                height: 10,
                                decoration: BoxDecoration(
                                  color: widget.isDarkMode ? const Color(0xFF2A2A2A) : const Color(0xFFE5E7EB),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: LayoutBuilder(
                                  builder: (context, constraints) {
                                    final w = constraints.maxWidth * _pwdStrength;
                                    final c = _pwdStrength < 0.3
                                        ? Colors.red
                                        : (_pwdStrength < 0.6 ? Colors.orange : (_pwdStrength < 0.85 ? Colors.green : Colors.teal));
                                    return Align(
                                      alignment: Alignment.centerLeft,
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 220),
                                        width: w,
                                        decoration: BoxDecoration(
                                          color: c,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 6),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  _pwdLabel.isEmpty ? "" : "Force du mot de passe: $_pwdLabel",
                                  style: TextStyle(color: _mutedText, fontSize: 12),
                                ),
                              ),
                              const SizedBox(height: 10),

                              TextField(
                                focusNode: _confirmPassFocus,
                                controller: _confirmPasswordCtrl,
                                obscureText: !_showConfirmPassword,
                                style: TextStyle(color: _textColor, fontWeight: FontWeight.w600),
                                decoration: premiumDec(
                                  label: "Confirmer le nouveau mot de passe",
                                  hint: "********",
                                  helper: "Doit correspondre au nouveau mot de passe.",
                                  prefixIcon: Icon(Icons.check_circle_outline, color: _mutedText),
                                  suffixIcon: IconButton(
                                    tooltip: _showConfirmPassword ? "Masquer" : "Afficher",
                                    icon: Icon(
                                      _showConfirmPassword ? Icons.visibility_off : Icons.visibility,
                                      color: _mutedText,
                                    ),
                                    onPressed: () => setState(() {
                                      _showConfirmPassword = !_showConfirmPassword;
                                    }),
                                  ),
                                  focused: _confirmPassFocus.hasFocus,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  // Tips compact
                                  Tooltip(
                                    message: "Conseils de sécurité",
                                    child: Icon(Icons.info_outline, color: _mutedText, size: 18),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      "Utilise une phrase secrète avec des symboles. Ne partage jamais ton mot de passe.",
                                      style: TextStyle(color: _mutedText, fontSize: 12),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  ghostButton(
                                    label: "Annuler",
                                    onTap: () {
                                      _currentPasswordCtrl.clear();
                                      _newPasswordCtrl.clear();
                                      _confirmPasswordCtrl.clear();
                                      setState(() {
                                        _pwdStrength = 0.0;
                                        _pwdLabel = '';
                                      });
                                      FocusScope.of(context).unfocus();
                                    },
                                  ),
                                  const SizedBox(width: 8),
                                  premiumButton(
                                    label: "Enregistrer",
                                    icon: Icons.lock_clock,
                                    onTap: _savingPassword ? null : _savePassword,
                                    loading: _savingPassword,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Changer statut
                        sectionCard(
                          title: "Changer le statut",
                          subtitle: "Montre à tes amis si tu es dispo",
                          icon: Icons.circle,
                          child: Column(
                            children: statusOptions.map((option) {
                              final selected = userStatus == option['value'];
                              final Color dotColor = option['color'] as Color;
                              return InkWell(
                                onTap: _loadingStatus ? null : () => _setUserStatus(option['value'] as String),
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  margin: const EdgeInsets.symmetric(vertical: 4),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: selected ? _accent.withOpacity(0.10) : (widget.isDarkMode ? const Color(0xFF232323) : const Color(0xFFF6F7F9)),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: selected ? _accent.withOpacity(0.35) : _borderColor,
                                      width: selected ? 1.5 : 1.0,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 10,
                                        height: 10,
                                        decoration: BoxDecoration(
                                          color: dotColor,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Text(option['label'] as String, style: TextStyle(color: _textColor, fontWeight: FontWeight.w600)),
                                      const Spacer(),
                                      if (selected) Icon(Icons.check, color: _accent),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Déconnexion
                        sectionCard(
                          title: "Se déconnecter",
                          subtitle: "Quitte ta session en sécurité",
                          icon: Icons.logout,
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  "Tu peux te reconnecter à tout moment.",
                                  style: TextStyle(color: _mutedText, fontSize: 12),
                                ),
                              ),
                              const SizedBox(width: 10),
                              premiumButton(
                                label: "Déconnexion",
                                icon: Icons.exit_to_app,
                                onTap: _handleLogout,
                                loading: false,
                                bg: Colors.redAccent,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 28),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
