import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../providers/theme_provider.dart';
import '../screens/biblio_page.dart';
import '../screens/chat_screen.dart';
import '../screens/entraide_page.dart';
import '../screens/settings_screen.dart';
import '../screens/upload_screen.dart';
import '../services/global_data_cache.dart';
import '../theme/apex_colors.dart';
import '../widgets/lucide_bottom_bar.dart';

// ═══════════════════════════════════════════════════════════
// APEX — HOME SCREEN
// App éducative mondiale — design de classe mondiale
// ═══════════════════════════════════════════════════════════

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin {

  // ── Auth ──
  final User? user = FirebaseAuth.instance.currentUser;

  // ── Navigation ──
  int _selectedIndex = 2;

  // ── Avatar ──
  Uint8List? _avatarBytes;
  bool _isPickingAvatar = false;
  bool _isSyncingAvatar = false;
  bool _welcomeShown = false;

  // ── Search ──
  final TextEditingController _searchController = TextEditingController();
  bool _isSearchActive = false;
  final FocusNode _searchFocus = FocusNode();

  // ── Animations ──
  late AnimationController _heroController;
  late AnimationController _pulseController;
  late AnimationController _staggerController;
  late Animation<double> _heroFade;
  late Animation<Offset> _heroSlide;
  late Animation<double> _pulseAnim;

  // ── Matières ──
  final List<Map<String, dynamic>> _subjects = [
    {'name': 'Maths',        'icon': LucideIcons.calculator,   'color': const Color(0xFF3B82F6)},
    {'name': 'Physique',     'icon': LucideIcons.zap,           'color': const Color(0xFFF59E0B)},
    {'name': 'Informatique', 'icon': LucideIcons.monitor,       'color': const Color(0xFF10B981)},
    {'name': 'Français',     'icon': LucideIcons.bookOpen,      'color': const Color(0xFF8B5CF6)},
    {'name': 'Anglais',      'icon': LucideIcons.languages,     'color': const Color(0xFF06B6D4)},
    {'name': 'Chimie',       'icon': LucideIcons.beaker,        'color': const Color(0xFFEF4444)},
    {'name': 'Histoire',     'icon': LucideIcons.scroll,        'color': const Color(0xFFD97706)},
    {'name': 'Philosophie',  'icon': LucideIcons.brain,         'color': const Color(0xFFEC4899)},
  ];

  // ── Quick Actions ──
  final List<Map<String, dynamic>> _quickActions = [
    {
      'label': 'Poser',
      'sublabel': 'une question',
      'icon': LucideIcons.messageCircle,
      'gradient': [const Color(0xFF0EA5E9), const Color(0xFF0891B2)],
    },
    {
      'label': 'Partager',
      'sublabel': 'un document',
      'icon': LucideIcons.upload,
      'gradient': [const Color(0xFF10B981), const Color(0xFF059669)],
    },
    {
      'label': 'Rejoindre',
      'sublabel': 'le chat',
      'icon': LucideIcons.messagesSquare,
      'gradient': [const Color(0xFF8B5CF6), const Color(0xFF7C3AED)],
    },
    {
      'label': 'Quiz',
      'sublabel': 'mondial',
      'icon': LucideIcons.trophy,
      'gradient': [const Color(0xFFF59E0B), const Color(0xFFD97706)],
    },
  ];

  // ═══════════════════════════════════════════
  // INIT
  // ═══════════════════════════════════════════

  @override
  void initState() {
    super.initState();

    _heroController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _heroFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _heroController, curve: Curves.easeOut),
    );
    _heroSlide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _heroController, curve: Curves.easeOutCubic));

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _heroController.forward();
    Future.delayed(const Duration(milliseconds: 300), () {
      _staggerController.forward();
    });

    _loadAvatar();
    _searchController.addListener(() => setState(() {}));

    // 🚀 Pré-charger les données en arrière-plan (après l'avatar)
    _preloadData();
  }

  /// Pré-charge toutes les données en arrière-plan pour une navigation instantanée
  Future<void> _preloadData() async {
    debugPrint('[HOME_SCREEN] 🚀 Début pré-chargement global des données...');
    try {
      await GlobalDataCache.preloadAll();
      debugPrint('[HOME_SCREEN] ✅ Pré-chargement terminé');
    } catch (e, stack) {
      debugPrint('[HOME_SCREEN] ❌ Erreur pré-chargement: $e');
      debugPrint('[HOME_SCREEN] Stack: $stack');
    }
  }

  @override
  void dispose() {
    _heroController.dispose();
    _pulseController.dispose();
    _staggerController.dispose();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_welcomeShown && user != null) {
      _welcomeShown = true;
      final name = user!.displayName?.trim();
      final userName = (name != null && name.isNotEmpty) ? name : 'Explorer';
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Text('👋 ', style: TextStyle(fontSize: 18)),
                Text(
                  'Welcome back, $userName',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            backgroundColor: ApexColors.surface,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(ApexColors.radiusMd),
              side: const BorderSide(color: ApexColors.borderAccent, width: 1),
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      });
    }
  }

  // ═══════════════════════════════════════════
  // AVATAR
  // ═══════════════════════════════════════════

  Future<void> _loadAvatar() async {
    if (user == null) return;
    try {
      setState(() => _isSyncingAvatar = true);
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .get();
      final base64 = doc.data()?['avatarBase64'] as String?;
      if (base64 != null && base64.isNotEmpty && mounted) {
        setState(() => _avatarBytes = base64Decode(base64));
      }
    } catch (_) {}
    finally {
      if (mounted) setState(() => _isSyncingAvatar = false);
    }
  }

  Future<void> _saveAvatar(String base64) async {
    if (user == null) return;
    await FirebaseFirestore.instance.collection('users').doc(user!.uid).set(
      {'avatarBase64': base64},
      SetOptions(merge: true),
    );
  }

  Future<void> _pickAvatar() async {
    try {
      setState(() => _isPickingAvatar = true);
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      if (file != null) {
        final bytes = await file.readAsBytes();
        final b64 = base64Encode(bytes);
        setState(() => _avatarBytes = bytes);
        await _saveAvatar(b64);
      }
    } catch (_) {}
    finally {
      if (mounted) setState(() => _isPickingAvatar = false);
    }
  }

  // ═══════════════════════════════════════════
  // NAVIGATION
  // ═══════════════════════════════════════════

  void _onBottomBarTap(int index) {
    setState(() => _selectedIndex = index);
    switch (index) {
      case 0:
        Navigator.pushReplacement(context, _route(const UploadScreen()));
        break;
      case 1:
        Navigator.pushReplacement(context, _route(const EntraidePage()));
        break;
      case 2:
        break;
      case 3:
        Navigator.pushReplacement(context, _route(const ChatScreen()));
        break;
      case 4:
        Navigator.pushReplacement(context, _route(const BiblioPage()));
        break;
    }
  }

  PageRoute _route(Widget page) => PageRouteBuilder(
        pageBuilder: (_, __, ___) => page,
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 250),
      );

  void _openSettings() {
    final tp = context.read<ThemeProvider>();
    final name = user?.displayName?.trim() ?? 'User';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SettingsModal(
        isDarkMode: tp.isDarkMode,
        userName: name,
        userEmail: user?.email ?? '',
      ),
    );
  }

  // ═══════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final tp = context.watch<ThemeProvider>();
    final isDark = tp.isDarkMode;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: isDark ? ApexColors.background : ApexColors.backgroundLight,
        body: SafeArea(
          child: Column(
            children: [
              _buildAppBar(isDark),
              Expanded(
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    // ── Search Bar ──
                    SliverToBoxAdapter(child: _buildSearchBar(isDark)),

                    // ── Hero Banner ──
                    SliverToBoxAdapter(child: _buildHero(isDark)),

                    // ── Quick Actions ──
                    SliverToBoxAdapter(child: _buildQuickActions(isDark)),

                    // ── Stats mondiales ──
                    SliverToBoxAdapter(child: _buildWorldStats(isDark)),

                    // ── Matières ──
                    SliverToBoxAdapter(child: _buildSubjectsSection(isDark)),

                    // ── Trending Documents ──
                    SliverToBoxAdapter(child: _buildTrendingDocs(isDark)),

                    // ── Feed activité récente ──
                    SliverToBoxAdapter(child: _buildRecentActivity(isDark)),

                    // ── Top Contributors ──
                    SliverToBoxAdapter(child: _buildTopContributors(isDark)),

                    // Padding bas
                    const SliverToBoxAdapter(child: SizedBox(height: 32)),
                  ],
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: LucideBottomBar(
          selectedIndex: _selectedIndex,
          onTap: _onBottomBarTap,
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // APP BAR
  // ═══════════════════════════════════════════

  Widget _buildAppBar(bool isDark) {
    final name = user?.displayName?.trim() ?? 'Explorer';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'A';

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      decoration: BoxDecoration(
        color: isDark ? ApexColors.background : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? ApexColors.border : ApexColors.borderLight,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          // Logo Apex
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: ApexColors.primaryGradient,
              borderRadius: BorderRadius.circular(10),
              boxShadow: ApexColors.shadowGlow,
            ),
            child: const Center(
              child: Text(
                'A',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                  letterSpacing: -0.5,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'APEX',
                style: TextStyle(
                  color: ApexColors.primary,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  letterSpacing: 2,
                ),
              ),
              Text(
                'Learn. Share. Dominate.',
                style: TextStyle(
                  color: isDark ? ApexColors.textMuted : ApexColors.textMuted,
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const Spacer(),
          // Notif
          _iconBtn(
            icon: LucideIcons.bell,
            isDark: isDark,
            onTap: () {},
            badge: true,
          ),
          const SizedBox(width: 8),
          // Theme toggle
          _iconBtn(
            icon: isDark ? LucideIcons.sun : LucideIcons.moon,
            isDark: isDark,
            onTap: () => context.read<ThemeProvider>().toggleTheme(),
          ),
          const SizedBox(width: 8),
          // Avatar
          GestureDetector(
            onTap: (_isPickingAvatar || _isSyncingAvatar) ? null : _pickAvatar,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: _avatarBytes == null ? ApexColors.primaryGradient : null,
                    image: _avatarBytes != null
                        ? DecorationImage(
                            image: MemoryImage(_avatarBytes!),
                            fit: BoxFit.cover,
                          )
                        : null,
                    border: Border.all(
                      color: ApexColors.primary.withOpacity(0.5),
                      width: 2,
                    ),
                  ),
                  child: _avatarBytes == null
                      ? Center(
                          child: Text(
                            initial,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        )
                      : null,
                ),
                if (_isPickingAvatar || _isSyncingAvatar)
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: ApexColors.primary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Settings
          _iconBtn(
            icon: LucideIcons.settings,
            isDark: isDark,
            onTap: _openSettings,
          ),
        ],
      ),
    );
  }

  Widget _iconBtn({
    required IconData icon,
    required bool isDark,
    required VoidCallback onTap,
    bool badge = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isDark ? ApexColors.surface : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? ApexColors.border : ApexColors.borderLight,
                width: 0.5,
              ),
            ),
            child: Icon(icon, size: 18,
              color: isDark ? ApexColors.textSecondary : const Color(0xFF64748B)),
          ),
          if (badge)
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: ApexColors.error,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════
  // SEARCH BAR
  // ═══════════════════════════════════════════

  Widget _buildSearchBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: GestureDetector(
        onTap: () {
          setState(() => _isSearchActive = true);
          _searchFocus.requestFocus();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 48,
          decoration: BoxDecoration(
            color: isDark ? ApexColors.surface : Colors.white,
            borderRadius: BorderRadius.circular(ApexColors.radiusMd),
            border: Border.all(
              color: _isSearchActive
                  ? ApexColors.primary
                  : (isDark ? ApexColors.border : ApexColors.borderLight),
              width: _isSearchActive ? 1.5 : 1,
            ),
            boxShadow: _isSearchActive ? ApexColors.shadowGlow : [],
          ),
          child: Row(
            children: [
              const SizedBox(width: 14),
              Icon(
                LucideIcons.search,
                size: 18,
                color: _isSearchActive
                    ? ApexColors.primary
                    : ApexColors.textMuted,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocus,
                  onTap: () => setState(() => _isSearchActive = true),
                  onEditingComplete: () => setState(() => _isSearchActive = false),
                  style: TextStyle(
                    color: isDark ? ApexColors.textPrimary : const Color(0xFF0F172A),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search docs, questions, subjects...',
                    hintStyle: const TextStyle(
                      color: ApexColors.textMuted,
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    isDense: true,
                  ),
                ),
              ),
              if (_searchController.text.isNotEmpty) ...[
                GestureDetector(
                  onTap: () {
                    _searchController.clear();
                    setState(() => _isSearchActive = false);
                    _searchFocus.unfocus();
                  },
                  child: const Icon(LucideIcons.x,
                      size: 16, color: ApexColors.textMuted),
                ),
                const SizedBox(width: 12),
              ] else ...[
                Container(
                  margin: const EdgeInsets.only(right: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: ApexColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    '⌘K',
                    style: TextStyle(
                      color: ApexColors.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // HERO BANNER
  // ═══════════════════════════════════════════

  Widget _buildHero(bool isDark) {
    final name = user?.displayName?.trim() ?? 'Explorer';

    return FadeTransition(
      opacity: _heroFade,
      child: SlideTransition(
        position: _heroSlide,
        child: Container(
          margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          height: 180,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(ApexColors.radiusXl),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF0D1B2A),
                Color(0xFF0EA5E9),
                Color(0xFF0891B2),
              ],
              stops: [0.0, 0.6, 1.0],
            ),
            boxShadow: [
              BoxShadow(
                color: ApexColors.primary.withOpacity(0.4),
                blurRadius: 30,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Motif géométrique background
              Positioned(
                right: -20,
                top: -20,
                child: _buildGeometricDecor(120, 0.06),
              ),
              Positioned(
                right: 60,
                bottom: -30,
                child: _buildGeometricDecor(80, 0.04),
              ),
              Positioned(
                left: -10,
                bottom: -10,
                child: _buildGeometricDecor(60, 0.03),
              ),

              // Contenu
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        ScaleTransition(
                          scale: _pulseAnim,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: Colors.white.withOpacity(0.3),
                                  width: 1),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF10B981),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Text(
                                  'LIVE — Worldwide',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Hello, $name 👋',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'The world\'s knowledge is waiting for you.',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.75),
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        _heroBadge('📚', 'Library'),
                        const SizedBox(width: 8),
                        _heroBadge('🤝', 'Help'),
                        const SizedBox(width: 8),
                        _heroBadge('💬', 'Chat'),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGeometricDecor(double size, double opacity) {
    return Transform.rotate(
      angle: pi / 4,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          border: Border.all(
            color: Colors.white.withOpacity(opacity),
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(size * 0.2),
        ),
      ),
    );
  }

  Widget _heroBadge(String emoji, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════
  // QUICK ACTIONS
  // ═══════════════════════════════════════════

  Widget _buildQuickActions(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Quick Actions', isDark),
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            physics: const BouncingScrollPhysics(),
            itemCount: _quickActions.length,
            itemBuilder: (context, i) {
              final action = _quickActions[i];
              final colors = action['gradient'] as List<Color>;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  switch (i) {
                    case 0:
                      Navigator.push(context, _route(const EntraidePage()));
                      break;
                    case 1:
                      Navigator.push(context, _route(const UploadScreen()));
                      break;
                    case 2:
                      Navigator.push(context, _route(const ChatScreen()));
                      break;
                  }
                },
                child: Container(
                  width: 100,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: colors,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(ApexColors.radiusLg),
                    boxShadow: [
                      BoxShadow(
                        color: colors[0].withOpacity(0.35),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Icon(action['icon'] as IconData,
                            color: Colors.white, size: 22),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              action['label'] as String,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              action['sublabel'] as String,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.75),
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════
  // WORLD STATS
  // ═══════════════════════════════════════════

  Widget _buildWorldStats(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Global Community', isDark),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .where('status', isEqualTo: 'online')
                .snapshots(),
            builder: (context, usersSnap) {
              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('documents')
                    .snapshots(),
                builder: (context, docsSnap) {
                  return StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('entraide_questions')
                        .where('isResolved', isEqualTo: true)
                        .snapshots(),
                    builder: (context, qaSnap) {
                      final online = usersSnap.data?.docs.length ?? 0;
                      final docs = docsSnap.data?.docs.length ?? 0;
                      final resolved = qaSnap.data?.docs.length ?? 0;

                      return Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: isDark ? ApexColors.surface : Colors.white,
                          borderRadius:
                              BorderRadius.circular(ApexColors.radiusXl),
                          border: Border.all(
                            color: isDark
                                ? ApexColors.border
                                : ApexColors.borderLight,
                          ),
                          boxShadow: ApexColors.shadowMd,
                        ),
                        child: Row(
                          children: [
                            _statItem(
                              value: '$online',
                              label: 'Online now',
                              icon: LucideIcons.users,
                              color: const Color(0xFF10B981),
                              isDark: isDark,
                            ),
                            _statDivider(isDark),
                            _statItem(
                              value: '$docs',
                              label: 'Documents',
                              icon: LucideIcons.fileText,
                              color: ApexColors.primary,
                              isDark: isDark,
                            ),
                            _statDivider(isDark),
                            _statItem(
                              value: '$resolved',
                              label: 'Resolved',
                              icon: LucideIcons.checkCircle,
                              color: const Color(0xFF8B5CF6),
                              isDark: isDark,
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _statItem({
    required String value,
    required String label,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: isDark ? ApexColors.textPrimary : const Color(0xFF0F172A),
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: ApexColors.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statDivider(bool isDark) {
    return Container(
      width: 1,
      height: 50,
      color: isDark ? ApexColors.border : ApexColors.borderLight,
    );
  }

  // ═══════════════════════════════════════════
  // MATIÈRES
  // ═══════════════════════════════════════════

  Widget _buildSubjectsSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Subjects', isDark, action: 'See all'),
        SizedBox(
          height: 88,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            physics: const BouncingScrollPhysics(),
            itemCount: _subjects.length,
            itemBuilder: (context, i) {
              final s = _subjects[i];
              final color = s['color'] as Color;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  Navigator.push(context, _route(const ChatScreen()));
                },
                child: Container(
                  width: 72,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: isDark ? ApexColors.surface : Colors.white,
                    borderRadius: BorderRadius.circular(ApexColors.radiusLg),
                    border: Border.all(
                      color: isDark ? ApexColors.border : ApexColors.borderLight,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(s['icon'] as IconData,
                            color: color, size: 20),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        s['name'] as String,
                        style: TextStyle(
                          color: isDark
                              ? ApexColors.textSecondary
                              : const Color(0xFF475569),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════
  // TRENDING DOCUMENTS
  // ═══════════════════════════════════════════

  Widget _buildTrendingDocs(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('🔥 Trending Documents', isDark, action: 'See all'),
        SizedBox(
          height: 160,
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('documents')
                .where('isPublic', isEqualTo: true)
                .orderBy('downloads', descending: true)
                .limit(8)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return _emptyState(
                  'No documents yet',
                  'Be the first to share!',
                  isDark,
                );
              }
              final docs = snapshot.data!.docs;
              return ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                physics: const BouncingScrollPhysics(),
                itemCount: docs.length,
                itemBuilder: (context, i) {
                  final data = docs[i].data() as Map<String, dynamic>;
                  final title = data['title'] ?? 'Document';
                  final author = data['author'] ?? data['username'] ?? 'Anonymous';
                  final category = data['category'] ?? 'General';
                  final downloads = data['downloads'] ?? 0;
                  final fileType = data['fileType'] ?? 'file';

                  Color catColor = _subjectColor(category);

                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.push(context, _route(const BiblioPage()));
                    },
                    child: Container(
                      width: 180,
                      margin: const EdgeInsets.only(right: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? ApexColors.surface : Colors.white,
                        borderRadius:
                            BorderRadius.circular(ApexColors.radiusLg),
                        border: Border.all(
                          color: isDark
                              ? ApexColors.border
                              : ApexColors.borderLight,
                        ),
                        boxShadow: ApexColors.shadowSm,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: catColor.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  fileType == 'image'
                                      ? LucideIcons.image
                                      : LucideIcons.fileText,
                                  color: catColor,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: catColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    category,
                                    style: TextStyle(
                                      color: catColor,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            title,
                            style: TextStyle(
                              color: isDark
                                  ? ApexColors.textPrimary
                                  : const Color(0xFF0F172A),
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const Spacer(),
                          Row(
                            children: [
                              const Icon(LucideIcons.user,
                                  size: 10, color: ApexColors.textMuted),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  author,
                                  style: const TextStyle(
                                    color: ApexColors.textMuted,
                                    fontSize: 10,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const Icon(LucideIcons.download,
                                  size: 10, color: ApexColors.textMuted),
                              const SizedBox(width: 3),
                              Text(
                                '$downloads',
                                style: const TextStyle(
                                  color: ApexColors.textMuted,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════
  // RECENT ACTIVITY FEED
  // ═══════════════════════════════════════════

  Widget _buildRecentActivity(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('⚡ Recent Activity', isDark),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('entraide_questions')
                .orderBy('createdAt', descending: true)
                .limit(4)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return _emptyStateFull(
                  'No activity yet',
                  'Start by asking a question!',
                  isDark,
                );
              }
              final docs = snapshot.data!.docs;
              return Column(
                children: docs.asMap().entries.map((entry) {
                  final i = entry.key;
                  final data = entry.value.data() as Map<String, dynamic>;
                  final title = data['title'] ?? 'Question';
                  final author = data['authorName'] ?? 'Anonymous';
                  final cats = List<String>.from(data['categories'] ?? []);
                  final answers = data['answersCount'] ?? 0;
                  final isResolved = data['isResolved'] ?? false;

                  return _buildActivityItem(
                    title: title,
                    author: author,
                    category: cats.isNotEmpty ? cats.first : 'General',
                    answers: answers,
                    isResolved: isResolved,
                    isDark: isDark,
                    index: i,
                  );
                }).toList(),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildActivityItem({
    required String title,
    required String author,
    required String category,
    required int answers,
    required bool isResolved,
    required bool isDark,
    required int index,
  }) {
    final color = _subjectColor(category);
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.push(context, _route(const EntraidePage()));
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? ApexColors.surface : Colors.white,
          borderRadius: BorderRadius.circular(ApexColors.radiusMd),
          border: Border.all(
            color: isDark ? ApexColors.border : ApexColors.borderLight,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  category.isNotEmpty ? category[0] : 'G',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isDark
                          ? ApexColors.textPrimary
                          : const Color(0xFF0F172A),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        author,
                        style: const TextStyle(
                          color: ApexColors.textMuted,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 3,
                        height: 3,
                        decoration: const BoxDecoration(
                          color: ApexColors.textMuted,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(LucideIcons.messageCircle,
                          size: 11, color: ApexColors.textMuted),
                      const SizedBox(width: 3),
                      Text(
                        '$answers',
                        style: const TextStyle(
                          color: ApexColors.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (isResolved)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  '✓ Solved',
                  style: TextStyle(
                    color: Color(0xFF10B981),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: ApexColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Open',
                  style: TextStyle(
                    color: ApexColors.primary,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // TOP CONTRIBUTORS
  // ═══════════════════════════════════════════

  Widget _buildTopContributors(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('🏆 Top Contributors', isDark),
        SizedBox(
          height: 110,
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .limit(8)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return _emptyState('No contributors yet', '', isDark);
              }
              final users = snapshot.data!.docs;
              return ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                physics: const BouncingScrollPhysics(),
                itemCount: users.length,
                itemBuilder: (context, i) {
                  final data = users[i].data() as Map<String, dynamic>;
                  final name = data['name'] ??
                      data['username'] ??
                      data['displayName'] ??
                      'User';
                  final status = data['status'] ?? 'offline';
                  final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';

                  final rankColors = [
                    const Color(0xFFFFD700),
                    const Color(0xFFC0C0C0),
                    const Color(0xFFCD7F32),
                  ];

                  return Container(
                    width: 76,
                    margin: const EdgeInsets.only(right: 12),
                    child: Column(
                      children: [
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 54,
                              height: 54,
                              decoration: BoxDecoration(
                                gradient: ApexColors.primaryGradient,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: i < 3
                                      ? rankColors[i]
                                      : Colors.transparent,
                                  width: 2.5,
                                ),
                                boxShadow: i < 3
                                    ? [
                                        BoxShadow(
                                          color:
                                              rankColors[i].withOpacity(0.4),
                                          blurRadius: 10,
                                        ),
                                      ]
                                    : [],
                              ),
                              child: Center(
                                child: Text(
                                  initial,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 20,
                                  ),
                                ),
                              ),
                            ),
                            // Badge rank
                            if (i < 3)
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  width: 18,
                                  height: 18,
                                  decoration: BoxDecoration(
                                    color: rankColors[i],
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isDark
                                          ? ApexColors.background
                                          : Colors.white,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${i + 1}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            // Online dot
                            Positioned(
                              top: 2,
                              right: 2,
                              child: Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: status == 'online'
                                      ? const Color(0xFF10B981)
                                      : ApexColors.textMuted,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isDark
                                        ? ApexColors.background
                                        : Colors.white,
                                    width: 1.5,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          name.length > 8
                              ? '${name.substring(0, 7)}…'
                              : name,
                          style: TextStyle(
                            color: isDark
                                ? ApexColors.textSecondary
                                : const Color(0xFF475569),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════

  Widget _sectionHeader(String title, bool isDark, {String? action}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              color: isDark ? ApexColors.textPrimary : const Color(0xFF0F172A),
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
          if (action != null)
            Text(
              action,
              style: const TextStyle(
                color: ApexColors.primary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }

  Color _subjectColor(String subject) {
    for (final s in _subjects) {
      if ((s['name'] as String).toLowerCase() ==
          subject.toLowerCase()) {
        return s['color'] as Color;
      }
    }
    return ApexColors.primary;
  }

  Widget _emptyState(String title, String sub, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.inbox,
                size: 36,
                color: isDark ? ApexColors.textMuted : const Color(0xFF94A3B8)),
            const SizedBox(height: 8),
            Text(title,
                style: const TextStyle(
                    color: ApexColors.textMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
            if (sub.isNotEmpty)
              Text(sub,
                  style: const TextStyle(
                      color: ApexColors.textMuted, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _emptyStateFull(String title, String sub, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? ApexColors.surface : Colors.white,
        borderRadius: BorderRadius.circular(ApexColors.radiusLg),
        border: Border.all(
          color: isDark ? ApexColors.border : ApexColors.borderLight,
        ),
      ),
      child: Column(
        children: [
          Icon(LucideIcons.inbox,
              size: 36,
              color: isDark ? ApexColors.textMuted : const Color(0xFF94A3B8)),
          const SizedBox(height: 8),
          Text(title,
              style: const TextStyle(
                  color: ApexColors.textMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
          if (sub.isNotEmpty)
            Text(sub,
                style:
                    const TextStyle(color: ApexColors.textMuted, fontSize: 11)),
        ],
      ),
    );
  }
}