// ═══════════════════════════════════════════════════════════════════════════════════════════
// APEX — UPLOAD SCREEN  ·  WORLD-CLASS ULTIMATE EDITION
// Design premium (V1) + Robustesse pro (V2) + Animations fluides + Logging intelligent
// ═══════════════════════════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mime/mime.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../providers/theme_provider.dart';
import '../services/appwrite_service.dart';
import '../theme/apex_colors.dart';
import '../widgets/lucide_bottom_bar.dart';
import 'biblio_page.dart';
import 'chat_screen.dart';
import 'entraide_page.dart';
import 'home_screen.dart';
import 'settings_screen.dart';

// ═══════════════════════════════════════════════════════════════════════════════════════════
// LOGGER INTELLIGENT (V2 amélioré)
// ═══════════════════════════════════════════════════════════════════════════════════════════

class UploadLogger {
  static String _sessionId = const Uuid().v4().substring(0, 8);
  static final List<String> _logs = [];
  static final bool _verbose = true;

  static void init() {
    _sessionId = const Uuid().v4().substring(0, 8);
    info('SESSION', '🚀 Session upload démarrée · platform=${kIsWeb ? "web" : "mobile"}');
  }

  static void info(String tag, String msg) {
    final log = '📋 [$_sessionId][$tag] $msg';
    if (_verbose) debugPrint(log);
    _logs.add(log);
  }

  static void error(String tag, String msg, {Object? err, StackTrace? stack}) {
    final log = '❌ [$_sessionId][$tag] $msg${err != null ? '\n   Cause: $err' : ''}';
    if (_verbose) debugPrint(log);
    _logs.add(log);
    if (stack != null && _verbose) {
      debugPrint('   📍 Stack: ${stack.toString().split('\n').take(2).join('\n   ')}');
    }
  }

  static void success(String tag, String msg) {
    final log = '✅ [$_sessionId][$tag] $msg';
    if (_verbose) debugPrint(log);
    _logs.add(log);
  }

  static void summary() {
    info('SUMMARY', '=== Session terminée · ${_logs.length} opérations ===');
  }
}

// ═══════════════════════════════════════════════════════════════════════════════════════════
// DONNÉES STATIQUES (V1 enrichi)
// ═══════════════════════════════════════════════════════════════════════════════════════════

const List<String> _kCategories = [
  'Maths', 'Physics', 'Computer Sci', 'French',
  'English', 'CMI', 'Electronics', 'Methods',
];

const Map<String, Color> _kCategoryColors = {
  'Maths': Color(0xFF3B82F6),
  'Physics': Color(0xFFF59E0B),
  'Computer Sci': Color(0xFF10B981),
  'French': Color(0xFF8B5CF6),
  'English': Color(0xFF06B6D4),
  'CMI': Color(0xFF0EA5E9),
  'Electronics': Color(0xFFEF4444),
  'Methods': Color(0xFFD97706),
};

const Map<String, IconData> _kCategoryIcons = {
  'Maths': LucideIcons.calculator,
  'Physics': LucideIcons.zap,
  'Computer Sci': LucideIcons.monitor,
  'French': LucideIcons.bookOpen,
  'English': LucideIcons.languages,
  'CMI': LucideIcons.graduationCap,
  'Electronics': LucideIcons.cpu,
  'Methods': LucideIcons.map,
};

const List<String> _kLevels = ['Grade 10', 'Grade 11', 'Grade 12', 'BTS', 'Bachelor'];

// ═══════════════════════════════════════════════════════════════════════════════════════════
// UPLOAD SCREEN ULTIME
// ═══════════════════════════════════════════════════════════════════════════════════════════

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen>
    with TickerProviderStateMixin {
  
  // ──────────────── SERVICES & USER ────────────────
  final User? _user = FirebaseAuth.instance.currentUser;
  final AppwriteService _appwrite = AppwriteService();

  // ──────────────── ANIMATIONS (V1 premium) ────────────────
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _successController;
  late Animation<double> _successScale;
  late AnimationController _errorShakeController;

  // ──────────────── AVATAR (V1) ────────────────
  Uint8List? _avatarBytes;
  bool _isPickingAvatar = false;
  bool _isSyncingAvatar = false;

  // ──────────────── FILE STATE ────────────────
  XFile? _file;
  Uint8List? _fileBytes;
  String? _fileType;
  bool _isDragging = false;

  // ──────────────── FORM STATE ────────────────
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  String _selectedCategory = 'Computer Sci';
  final List<String> _selectedLevels = [];
  
  // ──────────────── VALIDATION (V2 robuste) ────────────────
  bool _nameError = false;
  bool _levelsError = false;
  String? _generalError;
  
  // ──────────────── UPLOAD STATE ────────────────
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  bool _uploadSuccess = false;
  String? _operationId;

  // ──────────────── THEME GETTERS (V1 élégant) ────────────────
  bool get _isDark => context.watch<ThemeProvider>().isDarkMode;
  Color get _bgColor => _isDark ? const Color(0xFF080C10) : const Color(0xFFF0F4F8);
  Color get _surfaceColor => _isDark ? const Color(0xFF0F1623) : Colors.white;
  Color get _cardColor => _isDark ? const Color(0xFF151E2D) : const Color(0xFFF1F5F9);
  Color get _borderColor => _isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
  Color get _textPrimary => _isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
  Color get _textSecondary => _isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

  bool get _isFormValid => 
      _file != null && 
      _nameController.text.trim().isNotEmpty && 
      _selectedLevels.isNotEmpty;

  @override
  void initState() {
    super.initState();
    UploadLogger.init();

    // Animations premium (V1)
    _pulseController = AnimationController(
      vsync: this, 
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _pulseAnimation = Tween(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _successController = AnimationController(
      vsync: this, 
      duration: const Duration(milliseconds: 600),
    );
    _successScale = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _successController, curve: Curves.elasticOut),
    );

    _errorShakeController = AnimationController(
      vsync: this, 
      duration: const Duration(milliseconds: 500),
    );

    _nameController.addListener(() {
      if (_nameError && _nameController.text.trim().isNotEmpty) {
        setState(() => _nameError = false);
      }
    });

    _loadAvatar();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _successController.dispose();
    _errorShakeController.dispose();
    _nameController.dispose();
    _descController.dispose();
    UploadLogger.summary();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════════════════════════════════
  // AVATAR (V1 premium)
  // ═══════════════════════════════════════════════════════════════════════════════════════════

  Future<void> _loadAvatar() async {
    if (_user == null) return;
    try {
      setState(() => _isSyncingAvatar = true);
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_user!.uid)
          .get()
          .timeout(const Duration(seconds: 15));
      
      final b64 = doc.data()?['avatarBase64'] as String?;
      if (b64 != null && b64.isNotEmpty && mounted) {
        setState(() => _avatarBytes = base64Decode(b64));
        UploadLogger.info('AVATAR', 'Chargé (${_avatarBytes!.length} bytes)');
      }
    } catch (e) {
      UploadLogger.error('AVATAR', 'Échec chargement', err: e);
    } finally {
      if (mounted) setState(() => _isSyncingAvatar = false);
    }
  }

  Future<void> _pickAvatar() async {
    if (_user == null) return;
    try {
      setState(() => _isPickingAvatar = true);
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 512,
        maxHeight: 512,
      );
      
      if (file != null) {
        final bytes = await file.readAsBytes();
        final b64 = base64Encode(bytes);
        setState(() => _avatarBytes = bytes);
        
        await FirebaseFirestore.instance
            .collection('users')
            .doc(_user!.uid)
            .set({'avatarBase64': b64, 'avatarUpdated': Timestamp.now()}, SetOptions(merge: true))
            .timeout(const Duration(seconds: 15));
        
        _showSnackBar('Avatar mis à jour ✓', isError: false);
        UploadLogger.success('AVATAR', 'Mis à jour');
      }
    } catch (e) {
      UploadLogger.error('AVATAR', 'Échec sélection', err: e);
      _showSnackBar('Erreur mise à jour avatar', isError: true);
    } finally {
      if (mounted) setState(() => _isPickingAvatar = false);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════════════════════
  // FILE HANDLING (V1 + validation V2)
  // ═══════════════════════════════════════════════════════════════════════════════════════════

  Future<void> _pickFile() async {
    try {
      final file = await ImagePicker().pickMedia(imageQuality: 90);
      if (file != null) await _processFile(file);
    } catch (e) {
      UploadLogger.error('FILE', 'Sélection échouée', err: e);
    }
  }

  Future<void> _processFile(XFile file) async {
    try {
      final bytes = await file.readAsBytes();
      final sizeMB = bytes.length / 1048576;
      UploadLogger.info('FILE', '${file.name} · ${sizeMB.toStringAsFixed(2)}MB');

      if (sizeMB > 50) {
        _showSnackBar('Fichier trop volumineux (max 50 MB)', isError: true);
        return;
      }

      String? mime = lookupMimeType(file.path) ?? 
                     lookupMimeType('', headerBytes: bytes) ?? 
                     'application/octet-stream';

      if (mime.startsWith('video/')) {
        _showSnackBar('Les vidéos ne sont pas supportées', isError: true);
        return;
      }

      String type = 'file';
      if (mime.startsWith('image/')) type = 'image';
      else if (mime == 'application/pdf') type = 'pdf';
      else if (mime.contains('word') || mime.contains('document')) type = 'document';

      setState(() {
        _file = file;
        _fileBytes = bytes;
        _fileType = type;
        _generalError = null;
      });

      if (_nameController.text.trim().isEmpty) {
        final baseName = file.name.replaceAll(RegExp(r'\.[^.]+$'), '').replaceAll('_', ' ');
        _nameController.text = baseName;
      }

      UploadLogger.info('FILE', 'Traité: type=$type, size=${sizeMB.toStringAsFixed(2)}MB');
    } catch (e) {
      UploadLogger.error('FILE', 'Traitement échoué', err: e);
      _showSnackBar('Erreur lors du traitement du fichier', isError: true);
    }
  }

  void _removeFile() {
    setState(() {
      _file = null;
      _fileBytes = null;
      _fileType = null;
    });
    UploadLogger.info('FILE', 'Fichier supprimé');
  }

  // ═══════════════════════════════════════════════════════════════════════════════════════════
  // UPLOAD ULTIME (V1 UI + V2 robustesse + vérification post-upload)
  // ═══════════════════════════════════════════════════════════════════════════════════════════

  Future<void> _upload() async {
    if (!_isFormValid || _user == null) return;

    // ✅ Validation des niveaux avec feedback immédiat (V2)
    if (_selectedLevels.isEmpty) {
      setState(() => _levelsError = true);
      _errorShakeController.forward().then((_) => _errorShakeController.reset());
      HapticFeedback.heavyImpact();
      _showSnackBar('Sélectionnez au moins un niveau scolaire', isError: true);
      UploadLogger.error('UPLOAD', 'Validation échouée: aucun niveau sélectionné');
      return;
    }

    _operationId = const Uuid().v4().substring(0, 8);
    UploadLogger.info('UPLOAD', '[$_operationId] Début upload · file=${_file!.name} · cat=$_selectedCategory · levels=${_selectedLevels.join(",")}');

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
      _nameError = false;
      _levelsError = false;
      _generalError = null;
    });

    try {
      // ──────────────── 1. DÉTECTION MIME ────────────────
      String? mime = lookupMimeType(_file!.path) ?? 
                     lookupMimeType('', headerBytes: _fileBytes) ?? 
                     'application/octet-stream';
      UploadLogger.info('UPLOAD', '[$_operationId] MIME: $mime');

      // ──────────────── 2. UPLOAD VERS APPWRITE ────────────────
      final String fileId;
      if (kIsWeb) {
        fileId = await _appwrite.uploadFileWeb(
          bytes: _fileBytes!,
          filename: _file!.name,
          userId: _user!.uid,
          mime: mime,
          onProgress: (p) {
            if (mounted) setState(() => _uploadProgress = p / 100);
          },
        );
      } else {
        fileId = await _appwrite.uploadFile(
          filePath: _file!.path,
          userId: _user!.uid,
          filename: _file!.name,
          mime: mime,
          onProgress: (p) {
            if (mounted) setState(() => _uploadProgress = p / 100);
          },
        );
      }
      UploadLogger.success('UPLOAD', '[$_operationId] Appwrite OK · fileId=$fileId');

      // ──────────────── 3. CONSTRUCTION URL ────────────────
      String fileUrl = _appwrite.getFileUrl(fileId);
      if (fileUrl.isEmpty) {
        throw Exception('URL vide retournée par Appwrite');
      }
      UploadLogger.info('UPLOAD', '[$_operationId] URL: $fileUrl');

      // ──────────────── 4. PRÉPARATION DOCUMENT ────────────────
      final docId = const Uuid().v4();
      final now = Timestamp.now();

      final documentData = {
        // Identifiants
        'id': docId,
        'messageId': docId,
        'fileId': fileId,
        
        // Contenu
        'title': _nameController.text.trim(),
        'description': _descController.text.trim(),
        'category': _selectedCategory,
        'levels': List.from(_selectedLevels), // ✅ CRITIQUE pour les filtres
        'tags': [_selectedCategory, ..._selectedLevels],
        
        // Fichier
        'fileUrl': fileUrl,
        'fileType': _fileType,
        'fileMime': mime,
        'type': _fileType,
        'fileName': _file!.name,
        'fileSize': _fileBytes?.length ?? 0,
        
        // Auteur
        'userId': _user!.uid,
        'username': _user!.displayName ?? 'Utilisateur',
        'author': _user!.displayName ?? 'Utilisateur',
        'authorId': _user!.uid,
        
        // Timestamps
        'timestamp': now,
        'uploadDate': now,
        'lastUpdated': now,
        
        // Statistiques
        'downloads': 0,
        'views': 0,
        'likes': 0,
        'likedBy': [], // ✅ CRITIQUE pour les likes
        
        // Visibilité
        'isPublic': true,
        'status': 'published',
        
        // URLs additionnelles
        'thumbnailUrl': _fileType == 'image' ? fileUrl : '',
        'previewUrl': _appwrite.getFilePreviewUrl(fileId, width: 400, height: 300),
      };

      // ──────────────── 5. ÉCRITURE FIRESTORE ────────────────
      await FirebaseFirestore.instance
          .collection('documents')
          .doc(docId)
          .set(documentData)
          .timeout(const Duration(seconds: 15));
      UploadLogger.success('UPLOAD', '[$_operationId] Firestore écrit · docId=$docId');

      // ──────────────── 6. VÉRIFICATION POST-UPLOAD (V2 robuste) ────────────────
      UploadLogger.info('VERIF', '[$_operationId] Vérification post-upload...');
      
      final checkDoc = await FirebaseFirestore.instance
          .collection('documents')
          .doc(docId)
          .get()
          .timeout(const Duration(seconds: 15));
      
      if (!checkDoc.exists) {
        throw Exception('Le document n\'a pas été persisté dans Firestore');
      }
      
      final checkData = checkDoc.data() as Map<String, dynamic>;
      final verificationIssues = <String>[];
      
      // Vérification des champs critiques
      if (checkData['levels'] == null) {
        verificationIssues.add('levels manquant');
      } else if (checkData['levels'] is! List) {
        verificationIssues.add('levels type invalide');
      } else if ((checkData['levels'] as List).isEmpty) {
        verificationIssues.add('levels vide');
      } else {
        UploadLogger.success('VERIF', 'levels OK: ${(checkData['levels'] as List).join(", ")}');
      }
      
      if (checkData['likedBy'] == null) {
        verificationIssues.add('likedBy manquant');
        await FirebaseFirestore.instance
            .collection('documents')
            .doc(docId)
            .update({'likedBy': []})
            .timeout(const Duration(seconds: 15));
        UploadLogger.info('VERIF', 'likedBy corrigé');
      }
      
      if (checkData['fileUrl'] == null || checkData['fileUrl'].toString().isEmpty) {
        verificationIssues.add('fileUrl invalide');
      } else {
        UploadLogger.success('VERIF', 'fileUrl OK');
      }
      
      if (verificationIssues.isNotEmpty) {
        UploadLogger.error('VERIF', 'Problèmes détectés: ${verificationIssues.join(", ")}');
      } else {
        UploadLogger.success('VERIF', '✅ Document valide - Prêt pour la bibliothèque');
      }

      // ──────────────── 7. HISTORIQUE (non critique) ────────────────
      await FirebaseFirestore.instance
          .collection('uploads')
          .doc(docId)
          .set({
            'userId': _user!.uid,
            'timestamp': now,
            'documentId': docId,
            'title': _nameController.text.trim(),
            'category': _selectedCategory,
            'levels': List.from(_selectedLevels),
            'fileSize': _fileBytes?.length ?? 0,
          })
          .timeout(const Duration(seconds: 15))
          .catchError((e) => UploadLogger.error('HISTORY', 'Échec historique', err: e));

      // ──────────────── 8. SUCCÈS ────────────────
      setState(() {
        _isUploading = false;
        _uploadSuccess = true;
      });
      
      _successController.forward();
      HapticFeedback.heavyImpact();
      
      _showSuccessSnackBar(docId);
      
      // Reset après 3 secondes
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          _successController.reverse();
          setState(() {
            _uploadSuccess = false;
            _resetForm();
          });
        }
      });
      
      UploadLogger.success('UPLOAD', '[$_operationId] Upload terminé avec succès');
      
    } catch (e, st) {
      UploadLogger.error('UPLOAD', '[$_operationId] ÉCHEC', err: e, stack: st);
      setState(() {
        _isUploading = false;
        _uploadProgress = 0.0;
        _generalError = e.toString();
      });
      _showSnackBar('Upload échoué: ${e.toString().substring(0, math.min(80, e.toString().length))}', isError: true);
    }
  }

  void _resetForm() {
    setState(() {
      _file = null;
      _fileBytes = null;
      _fileType = null;
      _nameController.clear();
      _descController.clear();
      _selectedCategory = 'Computer Sci';
      _selectedLevels.clear();
      _nameError = false;
      _levelsError = false;
      _generalError = null;
      _operationId = null;
    });
    UploadLogger.info('FORM', 'Formulaire réinitialisé');
  }

  // ═══════════════════════════════════════════════════════════════════════════════════════════
  // SNACKBARS (V1 élégant)
  // ═══════════════════════════════════════════════════════════════════════════════════════════

  void _showSnackBar(String message, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          Icon(isError ? LucideIcons.alertCircle : LucideIcons.checkCircle, 
               color: Colors.white, size: 18),
          const SizedBox(width: 12),
          Expanded(child: Text(message, style: const TextStyle(color: Colors.white))),
        ]),
        backgroundColor: isError ? ApexColors.error : ApexColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showSuccessSnackBar(String docId) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            child: const Icon(LucideIcons.checkCircle, color: Color(0xFF10B981), size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Upload réussi !', 
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                const Text('Document disponible dans la bibliothèque',
                  style: TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
        ]),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        action: SnackBarAction(
          label: 'VOIR',
          textColor: Colors.white,
          onPressed: () => Navigator.pushReplacement(
            context, 
            MaterialPageRoute(builder: (_) => const BiblioPage())
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════════════════════
  // NAVIGATION
  // ═══════════════════════════════════════════════════════════════════════════════════════════

  void _navigateTo(int index) {
    Widget page;
    switch (index) {
      case 0: return;
      case 1: page = const EntraidePage(); break;
      case 2: page = const HomeScreen(); break;
      case 3: page = const ChatScreen(); break;
      case 4: page = const BiblioPage(); break;
      default: return;
    }
    Navigator.pushReplacement(context, _fadeTransition(page));
  }

  PageRoute _fadeTransition(Widget page) => PageRouteBuilder(
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
    transitionDuration: const Duration(milliseconds: 220),
  );

  void _openSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SettingsModal(
        isDarkMode: _isDark,
        userName: _user?.displayName?.trim() ?? 'Utilisateur',
        userEmail: _user?.email ?? '',
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════════════════════
  // BUILD - UI PREMIUM (V1)
  // ═══════════════════════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: Column(children: [
        _buildPremiumHeader(),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SizedBox(height: 20),
              _buildPageTitle(),
              const SizedBox(height: 20),
              _file == null ? _buildDropZone() : _buildFilePreview(),
              const SizedBox(height: 20),
              _buildTitleField(),
              const SizedBox(height: 16),
              _buildDescriptionField(),
              const SizedBox(height: 20),
              _buildCategorySection(),
              const SizedBox(height: 20),
              _buildLevelsSection(),
              const SizedBox(height: 24),
              if (_isUploading) _buildProgressCard(),
              if (_uploadSuccess) _buildSuccessCard(),
              if (_generalError != null) _buildErrorCard(),
              const SizedBox(height: 16),
              _buildActionButtons(),
            ]),
          ),
        ),
      ]),
      bottomNavigationBar: LucideBottomBar(selectedIndex: 0, onTap: _navigateTo),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════════════════════
  // HEADER PREMIUM (V1 glassmorphism)
  // ═══════════════════════════════════════════════════════════════════════════════════════════

  Widget _buildPremiumHeader() {
    final name = _user?.displayName?.trim() ?? 'Explorateur';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'A';

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 10,
            left: 16, right: 16, bottom: 12,
          ),
          decoration: BoxDecoration(
            color: _isDark ? Colors.black.withOpacity(0.55) : Colors.white.withOpacity(0.82),
            border: Border(bottom: BorderSide(color: _borderColor, width: 0.5)),
          ),
          child: Row(children: [
            // Avatar
            GestureDetector(
              onTap: (_isPickingAvatar || _isSyncingAvatar) ? null : _pickAvatar,
              child: Stack(alignment: Alignment.center, children: [
                Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: _avatarBytes == null ? ApexColors.primaryGradient : null,
                    image: _avatarBytes != null
                        ? DecorationImage(image: MemoryImage(_avatarBytes!), fit: BoxFit.cover)
                        : null,
                    border: Border.all(color: ApexColors.primary.withOpacity(0.45), width: 2),
                    boxShadow: [BoxShadow(
                      color: ApexColors.primary.withOpacity(0.22), blurRadius: 12)],
                  ),
                  child: _avatarBytes == null
                      ? Center(child: Text(initial, 
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17)))
                      : null,
                ),
                if (_isPickingAvatar || _isSyncingAvatar)
                  Container(
                    width: 42, height: 42,
                    decoration: BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                    child: const Padding(
                      padding: EdgeInsets.all(9),
                      child: CircularProgressIndicator(strokeWidth: 2, color: ApexColors.primary),
                    ),
                  ),
              ]),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, style: TextStyle(color: _textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance.collection('users').doc(_user?.uid).snapshots(),
                  builder: (_, snap) {
                    final status = (snap.data?.data() as Map?)?['status'] as String? ?? 'online';
                    final statusText = status == 'online' ? 'En ligne' : 'Hors ligne';
                    final statusColor = status == 'online' ? const Color(0xFF10B981) : Colors.grey;
                    return Row(children: [
                      Container(width: 6, height: 6,
                        decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
                      const SizedBox(width: 5),
                      Text(statusText, 
                        style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w600)),
                    ]);
                  },
                ),
              ]),
            ),
            _buildIconButton(_isDark ? LucideIcons.sun : LucideIcons.moon, 
                () { HapticFeedback.lightImpact(); context.read<ThemeProvider>().toggleTheme(); }),
            const SizedBox(width: 6),
            _buildIconButton(LucideIcons.settings, _openSettings),
          ]),
        ),
      ),
    );
  }

  Widget _buildIconButton(IconData icon, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 36, height: 36,
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _borderColor, width: 0.5),
      ),
      child: Icon(icon, size: 17, color: _textSecondary),
    ),
  );

  // ═══════════════════════════════════════════════════════════════════════════════════════════
  // PAGE TITLE (V1)
  // ═══════════════════════════════════════════════════════════════════════════════════════════

  Widget _buildPageTitle() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            gradient: ApexColors.primaryGradient,
            borderRadius: BorderRadius.circular(12),
            boxShadow: ApexColors.shadowGlow,
          ),
          child: const Icon(LucideIcons.upload, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Upload', style: TextStyle(color: _textPrimary, fontSize: 24, fontWeight: FontWeight.w800)),
          Text('Partagez avec la communauté', style: TextStyle(color: _textSecondary, fontSize: 12)),
        ]),
      ]),
      const SizedBox(height: 14),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: ApexColors.primary.withOpacity(0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: ApexColors.primary.withOpacity(0.18)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(LucideIcons.info, size: 15, color: ApexColors.primary),
          const SizedBox(width: 8),
          Expanded(child: Text(
            'Supportés: PDF, Images, Word · Max 50 MB\nVotre document sera visible par toute la communauté.',
            style: TextStyle(color: _textSecondary, fontSize: 12, height: 1.5),
          )),
        ]),
      ),
    ]);
  }

  // ═══════════════════════════════════════════════════════════════════════════════════════════
  // DROP ZONE PREMIUM (V1)
  // ═══════════════════════════════════════════════════════════════════════════════════════════

  Widget _buildDropZone() {
    return DragTarget<XFile>(
      onWillAcceptWithDetails: (_) { setState(() => _isDragging = true); return true; },
      onAcceptWithDetails: (d) { setState(() => _isDragging = false); _processFile(d.data); },
      onLeave: (_) => setState(() => _isDragging = false),
      builder: (_, __, ___) => GestureDetector(
        onTap: _pickFile,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          child: DottedBorder(
            borderType: BorderType.RRect,
            radius: const Radius.circular(20),
            dashPattern: const [7, 4],
            color: _isDragging ? ApexColors.primary : _borderColor,
            strokeWidth: _isDragging ? 2 : 1,
            child: Container(
              height: 220,
              width: double.infinity,
              decoration: BoxDecoration(
                color: _isDragging ? ApexColors.primary.withOpacity(0.05) : _surfaceColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                ScaleTransition(
                  scale: _pulseAnimation,
                  child: Container(
                    width: 76, height: 76,
                    decoration: BoxDecoration(
                      gradient: _isDragging ? ApexColors.primaryGradient : null,
                      color: _isDragging ? null : ApexColors.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                      boxShadow: _isDragging ? ApexColors.shadowGlow : [],
                    ),
                    child: Icon(LucideIcons.upload, size: 34,
                      color: _isDragging ? Colors.white : ApexColors.primary),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _isDragging ? 'Déposez votre fichier !' : 'Glissez-déposez votre document',
                  style: TextStyle(
                    color: _isDragging ? ApexColors.primary : _textPrimary,
                    fontSize: 17, fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text('ou', style: TextStyle(color: _textSecondary, fontSize: 13)),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: ApexColors.primaryGradient,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: ApexColors.shadowGlow,
                  ),
                  child: const Text('Choisir un fichier',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                ),
                const SizedBox(height: 14),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  _buildBadge('PDF'),
                  _buildBadge('JPG'),
                  _buildBadge('PNG'),
                  _buildBadge('DOCX'),
                  _buildBadge('50MB'),
                ]),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(String label) => Container(
    margin: const EdgeInsets.only(right: 6),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: _isDark ? const Color(0xFF1A2636) : const Color(0xFFE8EFF5),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(label, 
      style: TextStyle(color: _textSecondary, fontSize: 10, fontWeight: FontWeight.w600)),
  );

  // ═══════════════════════════════════════════════════════════════════════════════════════════
  // FILE PREVIEW PREMIUM (V1)
  // ═══════════════════════════════════════════════════════════════════════════════════════════

  Widget _buildFilePreview() {
    final sizeMB = _fileBytes != null ? (_fileBytes!.length / 1048576).toStringAsFixed(2) : '0';

    return Animate(
      effects: [
        FadeEffect(duration: 300.ms),
        ScaleEffect(begin: const Offset(0.95, 0.95), end: const Offset(1, 1),
          duration: 350.ms, curve: Curves.easeOutCubic),
      ],
      child: Container(
        decoration: BoxDecoration(
          color: _surfaceColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _borderColor, width: 0.5),
          boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(_isDark ? 0.2 : 0.06),
            blurRadius: 16, offset: const Offset(0, 4),
          )],
        ),
        child: Column(children: [
          if (_fileType == 'image' && _fileBytes != null)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              child: Image.memory(_fileBytes!, height: 180, width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildFilePlaceholder()),
            )
          else
            _buildFilePlaceholder(),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: _getFileTypeColor().withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_getFileTypeIcon(), color: _getFileTypeColor(), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_file!.name,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: _textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
                  Text('$sizeMB MB · ${(_fileType ?? 'file').toUpperCase()}',
                    style: TextStyle(color: _textSecondary, fontSize: 12)),
                ]),
              ),
              GestureDetector(
                onTap: _removeFile,
                child: Container(
                  width: 30, height: 30,
                  decoration: BoxDecoration(
                    color: ApexColors.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(LucideIcons.x, size: 15, color: ApexColors.error),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _buildFilePlaceholder() {
    final color = _getFileTypeColor();
    return Container(
      height: 120, width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.15), color.withOpacity(0.05)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(_getFileTypeIcon(), size: 36, color: color),
        const SizedBox(height: 8),
        Text((_fileType ?? 'file').toUpperCase(),
          style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
      ]),
    );
  }

  Color _getFileTypeColor() {
    switch (_fileType) {
      case 'image': return ApexColors.primary;
      case 'pdf': return const Color(0xFFEF4444);
      case 'document': return const Color(0xFF3B82F6);
      default: return _textSecondary;
    }
  }

  IconData _getFileTypeIcon() {
    switch (_fileType) {
      case 'image': return LucideIcons.image;
      case 'pdf': return LucideIcons.fileText;
      case 'document': return LucideIcons.file;
      default: return LucideIcons.file;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════════════════════
  // FORM FIELDS (V1 élégant)
  // ═══════════════════════════════════════════════════════════════════════════════════════════

  Widget _buildTitleField() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text('Titre du document', style: TextStyle(color: _textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
        const Text(' *', style: TextStyle(color: Colors.red, fontSize: 14)),
      ]),
      const SizedBox(height: 8),
      AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _nameError ? ApexColors.error : _borderColor,
            width: _nameError ? 1.5 : 1,
          ),
          boxShadow: _nameError ? [BoxShadow(color: ApexColors.error.withOpacity(0.1), blurRadius: 8)] : [],
        ),
        child: TextField(
          controller: _nameController,
          style: TextStyle(color: _textPrimary, fontSize: 14.5),
          decoration: InputDecoration(
            hintText: 'Ex: Mathématiques - Chapitre 5',
            hintStyle: TextStyle(color: _textSecondary, fontSize: 14),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ),
      if (_nameError) Padding(
        padding: const EdgeInsets.only(top: 6, left: 4),
        child: Row(children: [
          Icon(LucideIcons.alertCircle, size: 12, color: ApexColors.error),
          const SizedBox(width: 5),
          Text('Le titre est requis', style: TextStyle(color: ApexColors.error, fontSize: 11)),
        ]),
      ),
    ]);
  }

  Widget _buildDescriptionField() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Description', style: TextStyle(color: _textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
      const SizedBox(height: 8),
      Container(
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _borderColor, width: 1),
        ),
        child: TextField(
          controller: _descController,
          maxLines: 3,
          style: TextStyle(color: _textPrimary, fontSize: 14.5),
          decoration: InputDecoration(
            hintText: 'Ajoutez une description pour aider les autres...',
            hintStyle: TextStyle(color: _textSecondary, fontSize: 14),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ),
    ]);
  }

  // ═══════════════════════════════════════════════════════════════════════════════════════════
  // CATEGORY GRID (V1 colorée)
  // ═══════════════════════════════════════════════════════════════════════════════════════════

  Widget _buildCategorySection() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text('Catégorie', style: TextStyle(color: _textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
        const Text(' *', style: TextStyle(color: Colors.red, fontSize: 14)),
      ]),
      const SizedBox(height: 12),
      GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 3.2,
        ),
        itemCount: _kCategories.length,
        itemBuilder: (_, i) {
          final cat = _kCategories[i];
          final isSelected = _selectedCategory == cat;
          final color = _kCategoryColors[cat] ?? ApexColors.primary;
          
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _selectedCategory = cat);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                color: isSelected ? color : _cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isSelected ? color : _borderColor, width: isSelected ? 0 : 1),
                boxShadow: isSelected ? [BoxShadow(color: color.withOpacity(0.3), blurRadius: 10)] : [],
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(_kCategoryIcons[cat] ?? LucideIcons.tag, size: 15,
                  color: isSelected ? Colors.white : _textSecondary),
                const SizedBox(width: 7),
                Text(cat, style: TextStyle(
                  color: isSelected ? Colors.white : _textPrimary,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                  fontSize: 13,
                )),
              ]),
            ),
          );
        },
      ),
    ]);
  }

  // ═══════════════════════════════════════════════════════════════════════════════════════════
  // LEVELS SECTION (V2 avec validation visuelle)
  // ═══════════════════════════════════════════════════════════════════════════════════════════

  Widget _buildLevelsSection() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text('Niveaux scolaires', style: TextStyle(color: _textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
        const Text(' *', style: TextStyle(color: Colors.red, fontSize: 14)),
      ]),
      const SizedBox(height: 12),
      AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _kLevels.map((level) {
            final isSelected = _selectedLevels.contains(level);
            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() {
                  if (isSelected) {
                    _selectedLevels.remove(level);
                  } else {
                    _selectedLevels.add(level);
                  }
                  _levelsError = _selectedLevels.isEmpty;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? ApexColors.primary : _cardColor,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: isSelected ? ApexColors.primary : _borderColor,
                  ),
                  boxShadow: isSelected ? ApexColors.shadowGlow : [],
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (isSelected) ...[
                    const Icon(LucideIcons.check, size: 13, color: Colors.white),
                    const SizedBox(width: 6),
                  ],
                  Text(level, style: TextStyle(
                    color: isSelected ? Colors.white : _textPrimary,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                    fontSize: 13,
                  )),
                ]),
              ),
            );
          }).toList(),
        ),
      ),
      if (_levelsError) ...[
  const SizedBox(height: 8),
  AnimatedBuilder(
    animation: _errorShakeController,
    builder: (context, child) {
      return Transform.translate(
        offset: Offset(
          -0.02 * (1 - _errorShakeController.value), 
          0
        ),
        child: child,
      );
    },
    child: Row(
      children: [
        Icon(LucideIcons.alertCircle, size: 13, color: ApexColors.error),
        const SizedBox(width: 5),
        Text(
          'Sélectionnez au moins un niveau',
          style: TextStyle(
            color: ApexColors.error, 
            fontSize: 12, 
            fontWeight: FontWeight.w500
          ),
        ),
      ],
    ),
  ),
],
    ]);
  }

  // ═══════════════════════════════════════════════════════════════════════════════════════════
  // PROGRESS & STATUS CARDS (V1 premium)
  // ═══════════════════════════════════════════════════════════════════════════════════════════

  Widget _buildProgressCard() {
    final pct = (_uploadProgress * 100).toStringAsFixed(0);
    return Animate(
      effects: [
        FadeEffect(duration: 300.ms),
        SlideEffect(begin: const Offset(0, 0.3), end: Offset.zero, duration: 350.ms),
      ],
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: _surfaceColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _borderColor, width: 0.5),
          boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(_isDark ? 0.2 : 0.05),
            blurRadius: 12, offset: const Offset(0, 4),
          )],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: _uploadProgress),
              duration: const Duration(milliseconds: 300),
              builder: (_, v, __) => Stack(alignment: Alignment.center, children: [
                SizedBox(width: 46, height: 46,
                  child: CircularProgressIndicator(
                    value: v, strokeWidth: 3,
                    backgroundColor: ApexColors.primary.withOpacity(0.1),
                    valueColor: const AlwaysStoppedAnimation(ApexColors.primary),
                  ),
                ),
                Text('$pct%', style: TextStyle(color: _textPrimary, fontSize: 10, fontWeight: FontWeight.w700)),
              ]),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Téléversement en cours...',
                  style: TextStyle(color: _textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
                const SizedBox(height: 3),
                Text('${_file?.name ?? ''} · $pct%',
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: _textSecondary, fontSize: 12)),
              ]),
            ),
          ]),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: _uploadProgress, minHeight: 6,
              backgroundColor: ApexColors.primary.withOpacity(0.1),
              valueColor: const AlwaysStoppedAnimation(ApexColors.primary),
            ),
          ),
          const SizedBox(height: 8),
          Row(children: [
            Icon(LucideIcons.shield, size: 11, color: _textSecondary),
            const SizedBox(width: 4),
            Text('Transfert sécurisé · Chiffré de bout en bout',
              style: TextStyle(color: _textSecondary, fontSize: 10)),
          ]),
        ]),
      ),
    );
  }

  Widget _buildSuccessCard() {
    return ScaleTransition(
      scale: _successScale,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [const Color(0xFF10B981).withOpacity(0.12), const Color(0xFF10B981).withOpacity(0.04)],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFF10B981).withOpacity(0.35)),
        ),
        child: Row(children: [
          Container(
            width: 46, height: 46,
            decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle),
            child: const Icon(LucideIcons.checkCircle, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Upload réussi !',
                style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 3),
              Text('Votre document est maintenant disponible dans la bibliothèque.',
                style: TextStyle(color: const Color(0xFF10B981).withOpacity(0.8), fontSize: 12)),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _buildErrorCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ApexColors.error.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ApexColors.error.withOpacity(0.3)),
      ),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(color: ApexColors.error, shape: BoxShape.circle),
          child: const Icon(LucideIcons.alertCircle, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Erreur', style: TextStyle(color: ApexColors.error, fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(height: 2),
            Text(_generalError?.substring(0, math.min(100, _generalError?.length ?? 100)) ?? 'Erreur inconnue',
              style: TextStyle(color: ApexColors.error.withOpacity(0.8), fontSize: 12)),
          ]),
        ),
      ]),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════════════════════
  // ACTION BUTTONS (V1)
  // ═══════════════════════════════════════════════════════════════════════════════════════════

  Widget _buildActionButtons() {
    return Row(children: [
      Expanded(
        child: GestureDetector(
          onTap: _isUploading ? null : () {
            HapticFeedback.lightImpact();
            _resetForm();
            Navigator.pushReplacement(context, _fadeTransition(const HomeScreen()));
          },
          child: Container(
            height: 52,
            decoration: BoxDecoration(
              color: _cardColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _borderColor),
            ),
            child: Center(child: Text('Annuler',
              style: TextStyle(color: _textPrimary, fontWeight: FontWeight.w600, fontSize: 15))),
          ),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        flex: 2,
        child: GestureDetector(
          onTap: (_isFormValid && !_isUploading) ? _upload : () {
            if (_file == null) _showSnackBar('Sélectionnez un fichier', isError: true);
            if (_nameController.text.trim().isEmpty) setState(() => _nameError = true);
            if (_selectedLevels.isEmpty) {
              setState(() => _levelsError = true);
              _errorShakeController.forward().then((_) => _errorShakeController.reset());
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            height: 52,
            decoration: BoxDecoration(
              gradient: (_isFormValid && !_isUploading) ? ApexColors.primaryGradient : null,
              color: (_isFormValid && !_isUploading) ? null : _borderColor,
              borderRadius: BorderRadius.circular(14),
              boxShadow: (_isFormValid && !_isUploading) ? ApexColors.shadowGlow : [],
            ),
            child: _isUploading
                ? const Center(child: SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)))
                : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(LucideIcons.upload, size: 18, color: _isFormValid ? Colors.white : _textSecondary),
                    const SizedBox(width: 8),
                    Text(
                      _isFormValid ? 'Publier' : 'Complétez le formulaire',
                      style: TextStyle(
                        color: _isFormValid ? Colors.white : _textSecondary,
                        fontWeight: FontWeight.w700, fontSize: 14,
                      ),
                    ),
                  ]),
          ),
        ),
      ),
    ]);
  }
}