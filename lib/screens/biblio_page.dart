
// APEX — BIBLIO PAGE  · 



import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:photo_view/photo_view.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/biblio_provider.dart';
import '../providers/theme_provider.dart';
import '../services/appwrite_service.dart';
import '../theme/apex_colors.dart';
import '../widgets/lucide_bottom_bar.dart';
import 'chat_screen.dart';
import 'entraide_page.dart';
import 'home_screen.dart';
import 'settings_screen.dart';
import 'upload_screen.dart';

// ═══════════════════════════════════════════════════════════════════════
// CACHE IMAGE MANAGER
// ═══════════════════════════════════════════════════════════════════════

class _ImageCache {
  static final instance = CacheManager(Config(
    'apexBiblioCache',
    stalePeriod: const Duration(days: 30),
    maxNrOfCacheObjects: 500,
    repo: JsonCacheInfoRepository(databaseName: 'apexBiblioCache'),
    fileService: HttpFileService(),
  ));
}

// ═══════════════════════════════════════════════════════════════════════
// FIX URL APPWRITE
// ═══════════════════════════════════════════════════════════════════════

String _fixUrl(String url) {
  if (url.isEmpty) return '';
  if (url.contains('/view') && !url.contains('/preview')) return url;
  return url
      .replaceAll('/preview', '/view')
      .replaceAll(RegExp(r'[?&]width=\d+'), '')
      .replaceAll(RegExp(r'[?&]height=\d+'), '')
      .replaceAll(RegExp(r'[?&]quality=\d+'), '')
      .replaceAll(RegExp(r'[?&]output=\w+'), '')
      .replaceAll(RegExp(r'\?&'), '?')
      .replaceAll(RegExp(r'&&+'), '&')
      .replaceAll(RegExp(r'[?&]$'), '');
}

// ═══════════════════════════════════════════════════════════════════════
// AVATAR SERVICE
// ═══════════════════════════════════════════════════════════════════════

class _AvatarService {
  static final _AvatarService _i = _AvatarService._();
  factory _AvatarService() => _i;
  _AvatarService._();

  final _cache = <String, Uint8List?>{};
  final _time = <String, DateTime>{};
  static const _ttl = Duration(hours: 4);

  Future<Uint8List?> get(String uid) async {
    if (uid.isEmpty) return null;
    final t = _time[uid];
    if (_cache.containsKey(uid) && t != null && DateTime.now().difference(t) < _ttl) {
      return _cache[uid];
    }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get()
          .timeout(const Duration(seconds: 4));
      final d = doc.data();
      Uint8List? bytes;
      if (d != null) {
        final b64 = d['avatarBase64'] as String?;
        if (b64 != null && b64.isNotEmpty) bytes = base64Decode(b64);
      }
      _cache[uid] = bytes;
      _time[uid] = DateTime.now();
      return bytes;
    } catch (_) {
      return null;
    }
  }

  Future<void> upload(String uid, XFile file) async {
    final bytes = await file.readAsBytes();
    _cache[uid] = bytes;
    _time[uid] = DateTime.now();
    await FirebaseFirestore.instance.collection('users').doc(uid).set(
      {'avatarBase64': base64Encode(bytes)},
      SetOptions(merge: true),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// AVATAR WIDGET
// ═══════════════════════════════════════════════════════════════════════

class _Avatar extends StatefulWidget {
  final String uid, name;
  final double radius;
  final Color? color;
  final VoidCallback? onTap;

  const _Avatar({
    required this.uid,
    required this.name,
    this.radius = 18,
    this.color,
    this.onTap,
  });

  @override
  State<_Avatar> createState() => _AvatarState();
}

class _AvatarState extends State<_Avatar> {
  Uint8List? _bytes;

  static const _pal = [
    Color(0xFF5865F2), Color(0xFF10B981), Color(0xFF8B5CF6),
    Color(0xFFEC4899), Color(0xFFF59E0B), Color(0xFF0EA5E9),
    Color(0xFFEF4444), Color(0xFF22C55E),
  ];

  Color get _col => widget.color ?? _pal[widget.uid.hashCode.abs() % _pal.length];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final b = await _AvatarService().get(widget.uid);
    if (mounted) setState(() => _bytes = b);
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.radius * 2;
    final initial = widget.name.isNotEmpty ? widget.name[0].toUpperCase() : '?';
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        width: d, height: d,
        decoration: BoxDecoration(
          color: _bytes == null ? _col : null,
          shape: BoxShape.circle,
          image: _bytes != null
              ? DecorationImage(image: MemoryImage(_bytes!), fit: BoxFit.cover)
              : null,
        ),
        child: _bytes == null
            ? Center(child: Text(initial, style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700, fontSize: d * 0.42)))
            : null,
      ),
    );
  }
}


// DOCUMENT MODEL


class DocumentModel {
  final String id, title, description, category;
  final String fileUrl, fileType, fileName, author, authorId;
  final List<String> levels, tags;
  final DateTime uploadDate;
  final int downloads, views, likes, fileSize;
  final bool isPublic;
  final String? thumbnailUrl, previewUrl, fileId;

  DocumentModel({
    required this.id, required this.title, required this.description,
    required this.category, required this.levels, required this.fileUrl,
    required this.fileType, required this.fileName, required this.author,
    required this.authorId, required this.uploadDate, required this.downloads,
    required this.views, required this.likes, required this.tags,
    required this.isPublic, this.thumbnailUrl, this.previewUrl,
    required this.fileSize, this.fileId,
  });

  factory DocumentModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return DocumentModel(
      id: doc.id,
      title: d['title'] ?? d['message'] ?? 'Sans titre',
      description: d['description'] ?? '',
      category: d['category'] ?? 'Général',
      levels: List<String>.from(d['levels'] ?? []),
      fileUrl: d['fileUrl'] ?? '',
      fileType: d['fileType'] ?? d['type'] ?? 'file',
      fileName: d['fileName'] ?? 'document',
      author: d['author'] ?? d['username'] ?? 'Anonyme',
      authorId: d['authorId'] ?? d['userId'] ?? '',
      uploadDate: (d['uploadDate'] ?? d['timestamp'] ?? Timestamp.now()).toDate(),
      downloads: d['downloads'] ?? 0,
      views: d['views'] ?? 0,
      likes: d['likes'] ?? 0,
      tags: List<String>.from(d['tags'] ?? []),
      isPublic: d['isPublic'] ?? true,
      thumbnailUrl: d['thumbnailUrl'],
      previewUrl: d['previewUrl'],
      fileSize: d['fileSize'] ?? 0,
      fileId: d['fileId'],
    );
  }

  String get imageUrl {
    if (fileType == 'image') {
      if (fileUrl.isNotEmpty) return _fixUrl(fileUrl);
      if (thumbnailUrl?.isNotEmpty == true) return _fixUrl(thumbnailUrl!);
      if (previewUrl?.isNotEmpty == true) return _fixUrl(previewUrl!);
      if (fileId?.isNotEmpty == true) {
        return _fixUrl(AppwriteService().getFileUrl(fileId!));
      }
    }
    if (fileType == 'pdf') {
      if (thumbnailUrl?.isNotEmpty == true) return _fixUrl(thumbnailUrl!);
      if (previewUrl?.isNotEmpty == true) return _fixUrl(previewUrl!);
    }
    return '';
  }

  String get downloadUrl {
    if (fileUrl.isNotEmpty) return _fixUrl(fileUrl);
    if (previewUrl?.isNotEmpty == true) return _fixUrl(previewUrl!);
    if (fileId?.isNotEmpty == true) {
      return _fixUrl(AppwriteService().getFileUrl(fileId!));
    }
    return '';
  }

  bool get isImage => fileType == 'image';
  bool get isPdf => fileType == 'pdf';
  bool get hasImagePreview => imageUrl.isNotEmpty;

  String get formattedDate => DateFormat('dd MMM yyyy', 'fr').format(uploadDate);
  String get formattedDateDetail => DateFormat('dd MMM yyyy · HH:mm', 'fr').format(uploadDate);

  String get formattedSize {
    if (fileSize <= 0) return '';
    if (fileSize < 1024) return '${fileSize}o';
    if (fileSize < 1048576) return '${(fileSize / 1024).toStringAsFixed(1)}Ko';
    return '${(fileSize / 1048576).toStringAsFixed(1)}Mo';
  }

  int searchScore(String q) {
    if (q.isEmpty) return 0;
    int s = 0;
    final tl = title.toLowerCase(), dl = description.toLowerCase();
    if (tl.startsWith(q)) s += 100;
    if (tl.contains(q)) s += 60;
    if (dl.contains(q)) s += 20;
    if (author.toLowerCase().contains(q)) s += 30;
    for (final t in tags) if (t.toLowerCase().contains(q)) s += 15;
    return s;
  }

  bool matchesQuery(String q) => searchScore(q) > 0;

  Color get authorColor {
    const p = [
      Color(0xFF5865F2), Color(0xFF10B981), Color(0xFF8B5CF6),
      Color(0xFFEC4899), Color(0xFFF59E0B), Color(0xFF0EA5E9),
      Color(0xFFEF4444), Color(0xFF22C55E),
    ];
    return p[authorId.hashCode.abs() % p.length];
  }
}

// ═══════════════════════════════════════════════════════════════════════
// SERVICE BIBLIO
// ═══════════════════════════════════════════════════════════════════════

class _BiblioService {
  final _db = FirebaseFirestore.instance;
  
  Future<void> incDownloads(String id) async {
    debugPrint('[BIBLIO_SERVICE] 📥 Inc downloads: $id');
    await _db.collection('documents').doc(id).update({'downloads': FieldValue.increment(1)});
  }
  
  Future<void> incViews(String id) async {
    debugPrint('[BIBLIO_SERVICE] 👁️ Inc views: $id');
    await _db.collection('documents').doc(id).update({'views': FieldValue.increment(1)});
  }
  
  Future<void> toggleLike(String id, String uid, bool liked) async {
    debugPrint('[BIBLIO_SERVICE] ❤️ Toggle like: $id, liked: $liked');
    final ref = _db.collection('documents').doc(id);
    if (liked) {
      await ref.update({'likes': FieldValue.increment(1), 'likedBy': FieldValue.arrayUnion([uid])});
    } else {
      await ref.update({'likes': FieldValue.increment(-1), 'likedBy': FieldValue.arrayRemove([uid])});
    }
  }
  
  Future<bool> isLiked(String id, String uid) async {
    final doc = await _db.collection('documents').doc(id).get();
    return List<String>.from(doc.data()?['likedBy'] ?? []).contains(uid);
  }
}

// ═══════════════════════════════════════════════════════════════════════
// CATÉGORIES
// ═══════════════════════════════════════════════════════════════════════

const _kCats = [
  'Tout', 'Maths', 'Physique', 'Informatique', 'Français', 'Anglais',
  'Chimie', 'Histoire', 'Philosophie', 'SVT', 'Électronique', 'Méthodes',
];

const _kCatColors = <String, Color>{
  'Tout': Color(0xFF64748B), 'Maths': Color(0xFF3B82F6),
  'Physique': Color(0xFFF59E0B), 'Informatique': Color(0xFF10B981),
  'Français': Color(0xFF8B5CF6), 'Anglais': Color(0xFF06B6D4),
  'Chimie': Color(0xFFEF4444), 'Histoire': Color(0xFFD97706),
  'Philosophie': Color(0xFFEC4899), 'SVT': Color(0xFF22C55E),
  'Électronique': Color(0xFFF97316), 'Méthodes': Color(0xFF64748B),
};

const _kCatIcons = <String, IconData>{
  'Tout': LucideIcons.library, 'Maths': LucideIcons.calculator,
  'Physique': LucideIcons.zap, 'Informatique': LucideIcons.monitor,
  'Français': LucideIcons.bookOpen, 'Anglais': LucideIcons.languages,
  'Chimie': LucideIcons.beaker, 'Histoire': LucideIcons.scroll,
  'Philosophie': LucideIcons.brain, 'SVT': LucideIcons.leaf,
  'Électronique': LucideIcons.cpu, 'Méthodes': LucideIcons.map,
};

// ═══════════════════════════════════════════════════════════════════════
// BIBLIO PAGE — VERSION ULTRA FLUIDE
// ═══════════════════════════════════════════════════════════════════════

class BiblioPage extends StatefulWidget {
  const BiblioPage({super.key});
  @override
  State<BiblioPage> createState() => _BiblioPageState();
}

class _BiblioPageState extends State<BiblioPage> {
  final _user = FirebaseAuth.instance.currentUser;
  final _svc = _BiblioService();
  final _scroll = ScrollController();
  final _searchCtrl = TextEditingController();
  
  // État local pour les filtres
  String _cat = 'Tout';
  String _sort = 'recent';
  String _query = '';
  bool _showHistory = false;
  List<String> _history = [];
  Timer? _debounce;
  Uint8List? _avatarBytes;
  
  // Stream de données Firestore DIRECT
  late final Stream<List<DocumentModel>> _documentsStream;

  bool get _dark => context.watch<ThemeProvider>().isDarkMode;
  Color get _bg => _dark ? const Color(0xFF0B0E14) : const Color(0xFFF5F7FA);
  Color get _surf => _dark ? const Color(0xFF141920) : Colors.white;
  Color get _card => _dark ? const Color(0xFF1C2333) : const Color(0xFFF0F3F8);
  Color get _cardHi => _dark ? const Color(0xFF232D42) : const Color(0xFFE4EAF4);
  Color get _bord => _dark ? const Color(0xFF252E42) : const Color(0xFFDDE3EF);
  Color get _tp => _dark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
  Color get _ts => _dark ? const Color(0xFF8899BB) : const Color(0xFF6B7A99);

  @override
  void initState() {
    super.initState();
    debugPrint('[BIBLIO_PAGE] 📱 initState() - Démarrage');
    
    _scroll.addListener(_onScroll);
    _loadAvatar();
    _loadHistory();
    
    // ✅ STREAMBUILDER DIRECT - Pas de cache, pas de singleton
    _documentsStream = FirebaseFirestore.instance
        .collection('documents')
        .where('isPublic', isEqualTo: true)
        .orderBy('uploadDate', descending: true)
        .snapshots()
        .map((snap) {
          debugPrint('[BIBLIO_PAGE] 📡 Firestore stream: ${snap.docs.length} documents reçus');
          return snap.docs.map(DocumentModel.fromFirestore).toList();
        });
    
    debugPrint('[BIBLIO_PAGE] ✅ Stream initialisé');
  }

  @override
  void dispose() {
    debugPrint('[BIBLIO_PAGE] 🗑️ dispose()');
    _scroll.dispose();
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    // Pagination plus tard si besoin
  }

  void _onSearch(String raw) {
    _debounce?.cancel();
    setState(() { 
      _query = raw.toLowerCase().trim(); 
      _showHistory = false; 
    });
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (raw.trim().length >= 2) _addHistory(raw.trim());
    });
  }

  Future<void> _loadHistory() async {
    final p = await SharedPreferences.getInstance();
    _history = p.getStringList('biblio_history_v2') ?? [];
    if (mounted) setState(() {});
  }

  Future<void> _addHistory(String q) async {
    final p = await SharedPreferences.getInstance();
    _history.remove(q);
    _history.insert(0, q);
    if (_history.length > 8) _history.removeLast();
    await p.setStringList('biblio_history_v2', _history);
  }

  Future<void> _loadAvatar() async {
    if (_user == null) return;
    final b = await _AvatarService().get(_user!.uid);
    if (mounted) setState(() => _avatarBytes = b);
  }

  Future<void> _pickAvatar() async {
    final f = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (f != null && _user != null) {
      await _AvatarService().upload(_user!.uid, f);
      await _loadAvatar();
      _snack('Avatar mis à jour ✓');
    }
  }

  void _nav(int i) {
    switch (i) {
      case 0: _push(const UploadScreen()); break;
      case 1: _push(const EntraidePage()); break;
      case 2: _push(const HomeScreen()); break;
      case 3: _push(const ChatScreen()); break;
      case 4: break;
    }
  }

  void _push(Widget w) => Navigator.pushReplacement(
    context,
    PageRouteBuilder(
      pageBuilder: (_, __, ___) => w,
      transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
      transitionDuration: const Duration(milliseconds: 200),
    ),
  );

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: Colors.white)),
      backgroundColor: error ? ApexColors.error : ApexColors.success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      duration: const Duration(seconds: 2),
    ));
  }

  // ═══════════════════════════════════════════════════════════════════════
  // FILTRES (appliqués LOCALEMENT sur les données du stream)
  // ═══════════════════════════════════════════════════════════════════════
  
  List<DocumentModel> _applyFilters(List<DocumentModel> docs) {
    debugPrint('[BIBLIO_PAGE] 🔍 Application filtres - docs entrants: ${docs.length}');
    
    var filtered = List<DocumentModel>.from(docs);
    
    // Filtre texte
    if (_query.isNotEmpty) {
      filtered = filtered.where((d) => d.matchesQuery(_query)).toList();
      filtered.sort((a, b) => b.searchScore(_query).compareTo(a.searchScore(_query)));
      debugPrint('[BIBLIO_PAGE] 🔍 Après filtre texte: ${filtered.length}');
    }
    
    // Filtre catégorie
    if (_cat != 'Tout') {
      filtered = filtered.where((d) => d.category == _cat).toList();
      debugPrint('[BIBLIO_PAGE] 🔍 Après filtre catégorie ($_cat): ${filtered.length}');
    }
    
    // Tri
    if (_query.isEmpty) {
      switch (_sort) {
        case 'populaire':
          filtered.sort((a, b) => (b.downloads + b.views).compareTo(a.downloads + a.views));
          break;
        case 'alphabétique':
          filtered.sort((a, b) => a.title.compareTo(b.title));
          break;
        default:
          filtered.sort((a, b) => b.uploadDate.compareTo(a.uploadDate));
      }
      debugPrint('[BIBLIO_PAGE] 🔍 Tri appliqué: $_sort');
    }
    
    debugPrint('[BIBLIO_PAGE] ✅ Résultat final: ${filtered.length} documents');
    return filtered;
  }

  // ═══════════════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final p = context.watch<BiblioProvider>();
    
    debugPrint('[BIBLIO_PAGE] 🎨 build() - cat: $_cat, query: $_query, sort: $_sort');

    return Scaffold(
      backgroundColor: _bg,
      body: Column(
        children: [
          _buildHeader(p),
          _buildSearchBar(),
          if (_showHistory && _history.isNotEmpty)
            _buildHistoryPanel()
          else ...[
            _buildCategoryChips(),
            Expanded(
              child: StreamBuilder<List<DocumentModel>>(
                stream: _documentsStream,
                builder: (context, snapshot) {
                  debugPrint('[BIBLIO_PAGE] 📡 StreamBuilder - state: ${snapshot.connectionState}, hasData: ${snapshot.hasData}');
                  
                  // Chargement initial
                  if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                    debugPrint('[BIBLIO_PAGE] ⏳ Affichage shimmer');
                    return _buildShimmer(p.isGrid);
                  }
                  
                  // Erreur
                  if (snapshot.hasError) {
                    debugPrint('[BIBLIO_PAGE] ❌ Erreur: ${snapshot.error}');
                    return _buildError();
                  }
                  
                  // Pas de données
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    debugPrint('[BIBLIO_PAGE] 📭 Pas de données');
                    return _buildEmpty();
                  }
                  
                  // Données reçues - application des filtres
                  final allDocs = snapshot.data!;
                  debugPrint('[BIBLIO_PAGE] 📦 Données reçues: ${allDocs.length} documents');
                  
                  final filteredDocs = _applyFilters(allDocs);
                  debugPrint('[BIBLIO_PAGE] 📊 Affichage final: ${filteredDocs.length} documents');
                  
                  if (filteredDocs.isEmpty) {
                    return _buildEmpty();
                  }
                  
                  if (p.isGrid) {
                    return GridView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 100),
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 340,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 14,
                        childAspectRatio: 0.72,
                      ),
                      itemCount: filteredDocs.length,
                      itemBuilder: (_, i) => RepaintBoundary(
                        child: _gridCard(filteredDocs[i], i, p),
                      ),
                    );
                  }
                  
                  return ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                    itemCount: filteredDocs.length,
                    itemBuilder: (_, i) => RepaintBoundary(
                      child: _listCard(filteredDocs[i], i, p),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
      bottomNavigationBar: LucideBottomBar(selectedIndex: 4, onTap: _nav),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // HEADER
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildHeader(BiblioProvider p) {
    final name = _user?.displayName?.trim() ?? 'Explorateur';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12,
        left: 16, right: 16, bottom: 12,
      ),
      decoration: BoxDecoration(
        color: _surf,
        border: Border(bottom: BorderSide(color: _bord, width: 0.5)),
        boxShadow: [BoxShadow(
          color: Colors.black.withOpacity(_dark ? 0.3 : 0.06),
          blurRadius: 8, offset: const Offset(0, 2),
        )],
      ),
      child: Row(children: [
        GestureDetector(
          onTap: _pickAvatar,
          child: Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: _avatarBytes == null ? ApexColors.primary : null,
              shape: BoxShape.circle,
              image: _avatarBytes != null
                  ? DecorationImage(image: MemoryImage(_avatarBytes!), fit: BoxFit.cover)
                  : null,
              border: Border.all(color: ApexColors.primary.withOpacity(0.4), width: 2),
            ),
            child: _avatarBytes == null
                ? Center(child: Text(initial, style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17)))
                : null,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _tp)),
          StreamBuilder<List<DocumentModel>>(
            stream: _documentsStream,
            builder: (_, snap) {
              final count = snap.hasData ? snap.data!.length : 0;
              return Text(
                'Bibliothèque · $count document${count > 1 ? 's' : ''}',
                style: TextStyle(fontSize: 11, color: _ts),
              );
            },
          ),
        ])),
        _hBtn(p.isGrid ? LucideIcons.layoutList : LucideIcons.layoutGrid,
          () { HapticFeedback.lightImpact(); p.toggleGrid(); }),
        const SizedBox(width: 6),
        _hBtn(_dark ? LucideIcons.sun : LucideIcons.moon,
          () { HapticFeedback.lightImpact(); context.read<ThemeProvider>().toggleTheme(); }),
        const SizedBox(width: 6),
        _hBtn(LucideIcons.settings, () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => SettingsModal(
            isDarkMode: _dark,
            userName: _user?.displayName?.trim() ?? 'Utilisateur',
            userEmail: _user?.email ?? '',
          ),
        )),
      ]),
    );
  }

  Widget _hBtn(IconData icon, VoidCallback fn) => GestureDetector(
    onTap: fn,
    child: Container(
      width: 36, height: 36,
      decoration: BoxDecoration(
        color: _card, borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _bord),
      ),
      child: Icon(icon, size: 17, color: _ts),
    ),
  );

  // ═══════════════════════════════════════════════════════════════════════
  // SEARCH BAR
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildSearchBar() {
    final active = _searchCtrl.text.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 46,
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: active ? ApexColors.primary : _bord, width: active ? 1.5 : 1),
          boxShadow: active ? [BoxShadow(color: ApexColors.primary.withOpacity(0.1), blurRadius: 10)] : [],
        ),
        child: Row(children: [
          const SizedBox(width: 12),
          Icon(LucideIcons.search, size: 17, color: active ? ApexColors.primary : _ts),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              onChanged: _onSearch,
              onTap: () => setState(() => _showHistory = _history.isNotEmpty),
              onSubmitted: (q) { setState(() => _showHistory = false); _onSearch(q); },
              style: TextStyle(color: _tp, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Rechercher des documents, auteurs…',
                hintStyle: TextStyle(color: _ts, fontSize: 14),
                border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          if (active)
            GestureDetector(
              onTap: () {
                _searchCtrl.clear();
                setState(() { _query = ''; _showHistory = false; });
              },
              child: Padding(padding: const EdgeInsets.only(right: 12),
                child: Icon(LucideIcons.x, size: 16, color: _ts)),
            )
          else
            GestureDetector(
              onTap: _showFilterSheet,
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: (_cat != 'Tout') ? ApexColors.primary.withOpacity(0.1) : _cardHi,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(LucideIcons.slidersHorizontal, size: 13,
                    color: (_cat != 'Tout') ? ApexColors.primary : _ts),
                  const SizedBox(width: 4),
                  Text('Filtres', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                    color: (_cat != 'Tout') ? ApexColors.primary : _ts)),
                ]),
              ),
            ),
        ]),
      ),
    );
  }

  Widget _buildHistoryPanel() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      decoration: BoxDecoration(
        color: _surf, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _bord),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(_dark ? 0.3 : 0.08), blurRadius: 16)],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
          child: Row(children: [
            Icon(LucideIcons.history, size: 13, color: _ts),
            const SizedBox(width: 6),
            Text('Recherches récentes', style: TextStyle(color: _ts, fontSize: 11, fontWeight: FontWeight.w600)),
            const Spacer(),
            GestureDetector(
              onTap: () async {
                final p = await SharedPreferences.getInstance();
                await p.remove('biblio_history_v2');
                setState(() { _history.clear(); _showHistory = false; });
              },
              child: const Text('Effacer', style: TextStyle(color: ApexColors.primary, fontSize: 11, fontWeight: FontWeight.w600)),
            ),
          ]),
        ),
        ..._history.map((q) => GestureDetector(
          onTap: () {
            _searchCtrl.text = q;
            _onSearch(q);
            setState(() => _showHistory = false);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(children: [
              Icon(LucideIcons.search, size: 13, color: _ts),
              const SizedBox(width: 10),
              Expanded(child: Text(q, style: TextStyle(color: _tp, fontSize: 14))),
              GestureDetector(
                onTap: () async {
                  final p = await SharedPreferences.getInstance();
                  setState(() => _history.remove(q));
                  await p.setStringList('biblio_history_v2', _history);
                },
                child: Icon(LucideIcons.x, size: 13, color: _ts),
              ),
            ]),
          ),
        )),
        const SizedBox(height: 6),
      ]),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // CATEGORY CHIPS
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildCategoryChips() {
    return SizedBox(
      height: 42,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 5, 16, 0),
        itemCount: _kCats.length,
        itemBuilder: (_, i) {
          final cat = _kCats[i];
          final sel = _cat == cat;
          final color = _kCatColors[cat] ?? ApexColors.primary;
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _cat = cat);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: sel ? color : _card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: sel ? color : _bord),
                boxShadow: sel ? [BoxShadow(color: color.withOpacity(0.3), blurRadius: 6)] : [],
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(_kCatIcons[cat] ?? LucideIcons.tag, size: 12,
                  color: sel ? Colors.white : _ts),
                const SizedBox(width: 5),
                Text(cat, style: TextStyle(
                  color: sel ? Colors.white : _ts,
                  fontSize: 11.5,
                  fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
                )),
              ]),
            ),
          );
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // IMAGE WIDGET
  // ═══════════════════════════════════════════════════════════════════════

  Widget _img(DocumentModel doc, {double? width, double? height, BoxFit fit = BoxFit.cover}) {
    final url = doc.imageUrl;

    if (url.isNotEmpty) {
      return CachedNetworkImage(
        cacheManager: _ImageCache.instance,
        imageUrl: url,
        fit: fit,
        width: width,
        height: height,
        memCacheWidth: width != null ? (width * 2).toInt() : 600,
        memCacheHeight: height != null ? (height * 2).toInt() : 600,
        placeholder: (_, __) => _shimmerBox(width: width, height: height),
        errorWidget: (_, __, ___) => _placeholder(doc, width: width, height: height),
      );
    }

    return _placeholder(doc, width: width, height: height);
  }

  Widget _shimmerBox({double? width, double? height}) => Shimmer.fromColors(
    baseColor: _dark ? const Color(0xFF1C2333) : const Color(0xFFE4EAF4),
    highlightColor: _dark ? const Color(0xFF252E42) : const Color(0xFFF5F7FA),
    child: Container(width: width, height: height, color: _cardHi),
  );

  Widget _placeholder(DocumentModel doc, {double? width, double? height}) {
    final color = _kCatColors[doc.category] ?? ApexColors.primary;
    final h = height ?? 130.0;
    if (doc.isPdf) {
      return Container(
        width: width, height: h,
        decoration: BoxDecoration(gradient: LinearGradient(
          colors: [const Color(0xFFEF4444).withOpacity(0.15), const Color(0xFFEF4444).withOpacity(0.04)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        )),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: h * 0.32, height: h * 0.4,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.4), width: 1.5),
            ),
            child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(LucideIcons.fileText, color: Color(0xFFEF4444), size: 20),
              SizedBox(height: 3),
              Text('PDF', style: TextStyle(color: Color(0xFFEF4444), fontSize: 8, fontWeight: FontWeight.w800)),
            ]),
          ),
        ]),
      );
    }
    return Container(
      width: width, height: h,
      decoration: BoxDecoration(gradient: LinearGradient(
        colors: [color.withOpacity(0.15), color.withOpacity(0.04)],
        begin: Alignment.topLeft, end: Alignment.bottomRight,
      )),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(_fileIcon(doc.fileType), size: h * 0.26, color: color.withOpacity(0.7)),
        if (h > 60) ...[
          const SizedBox(height: 4),
          Text(doc.fileType.toUpperCase(), style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.w700)),
        ],
      ]),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // GRID CARD
  // ═══════════════════════════════════════════════════════════════════════

  Widget _gridCard(DocumentModel doc, int idx, BiblioProvider p) {
    final liked = p.isLiked(doc.id);
    final catColor = _kCatColors[doc.category] ?? ApexColors.primary;

    return Animate(
      effects: [
        FadeEffect(duration: 220.ms, delay: (math.min(idx, 5) * 30).ms),
        ScaleEffect(begin: const Offset(0.96, 0.96), end: const Offset(1, 1),
          duration: 280.ms, curve: Curves.easeOutCubic),
      ],
      child: GestureDetector(
        onTap: () => _openDetail(doc),
        child: Container(
          decoration: BoxDecoration(
            color: _surf, borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _bord, width: 0.5),
            boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(_dark ? 0.2 : 0.05),
              blurRadius: 10, offset: const Offset(0, 3),
            )],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(height: 130, child: Stack(children: [
                Positioned.fill(child: _img(doc, height: 130)),
                Positioned(top: 8, left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(color: catColor, borderRadius: BorderRadius.circular(20)),
                    child: Text(doc.category, style: const TextStyle(
                      color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
                  )),
                Positioned(top: 8, right: 8,
                  child: GestureDetector(
                    onTap: () async {
                      HapticFeedback.lightImpact();
                      if (_user != null) {
                        await _svc.toggleLike(doc.id, _user!.uid, !liked);
                        p.toggleLike(doc.id);
                      }
                    },
                    child: Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(color: Colors.black.withOpacity(0.5), shape: BoxShape.circle),
                      child: Icon(liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        size: 14, color: liked ? Colors.red : Colors.white),
                    ),
                  )),
                Positioned(bottom: 6, right: 8,
                  child: Container(
                    width: 24, height: 24,
                    decoration: BoxDecoration(color: Colors.black.withOpacity(0.5), shape: BoxShape.circle),
                    child: Icon(_fileIcon(doc.fileType), size: 12, color: Colors.white),
                  )),
              ])),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _highlight(doc.title, style: TextStyle(color: _tp, fontSize: 13, fontWeight: FontWeight.w700, height: 1.3), maxLines: 2),
                  const SizedBox(height: 5),
                  Row(children: [
                    _Avatar(uid: doc.authorId, name: doc.author, radius: 8, color: doc.authorColor),
                    const SizedBox(width: 5),
                    Expanded(child: Text(doc.author, style: TextStyle(color: _ts, fontSize: 10),
                      maxLines: 1, overflow: TextOverflow.ellipsis)),
                  ]),
                  const SizedBox(height: 6),
                  Row(children: [
                    _stat(LucideIcons.download, _fmt(doc.downloads)),
                    const SizedBox(width: 8),
                    _stat(LucideIcons.eye, _fmt(doc.views)),
                    const Spacer(),
                    _stat(Icons.favorite_rounded, _fmt(doc.likes + (liked ? 1 : 0)),
                      color: liked ? Colors.red : _ts),
                  ]),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // LIST CARD
  // ═══════════════════════════════════════════════════════════════════════

  Widget _listCard(DocumentModel doc, int idx, BiblioProvider p) {
    final liked = p.isLiked(doc.id);
    final catColor = _kCatColors[doc.category] ?? ApexColors.primary;

    return Animate(
      effects: [
        FadeEffect(duration: 200.ms, delay: (math.min(idx, 5) * 22).ms),
        SlideEffect(begin: const Offset(0, 0.05), end: Offset.zero,
          duration: 250.ms, curve: Curves.easeOutCubic),
      ],
      child: GestureDetector(
        onTap: () => _openDetail(doc),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _surf, borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _bord, width: 0.5),
            boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(_dark ? 0.15 : 0.04),
              blurRadius: 8, offset: const Offset(0, 2),
            )],
          ),
          child: Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(width: 64, height: 64, child: Stack(children: [
                Positioned.fill(child: _img(doc, width: 64, height: 64)),
                Positioned(top: 3, left: 3,
                  child: Container(
                    width: 16, height: 16,
                    decoration: BoxDecoration(color: catColor, shape: BoxShape.circle),
                    child: Icon(_kCatIcons[doc.category] ?? LucideIcons.file, size: 9, color: Colors.white),
                  )),
              ])),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: _highlight(doc.title,
                  style: TextStyle(color: _tp, fontSize: 14, fontWeight: FontWeight.w700), maxLines: 1)),
                GestureDetector(
                  onTap: () async {
                    HapticFeedback.lightImpact();
                    if (_user != null) {
                      await _svc.toggleLike(doc.id, _user!.uid, !liked);
                      p.toggleLike(doc.id);
                    }
                  },
                  child: Icon(liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    size: 18, color: liked ? Colors.red : _ts),
                ),
              ]),
              const SizedBox(height: 3),
              Row(children: [
                _Avatar(uid: doc.authorId, name: doc.author, radius: 7, color: doc.authorColor),
                const SizedBox(width: 5),
                Text(doc.author, style: TextStyle(color: _ts, fontSize: 11)),
                Padding(padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: Text('·', style: TextStyle(color: _ts))),
                Text(doc.formattedDate, style: TextStyle(color: _ts, fontSize: 11)),
              ]),
              const SizedBox(height: 5),
              Row(children: [
                _stat(LucideIcons.download, _fmt(doc.downloads)),
                const SizedBox(width: 10),
                _stat(LucideIcons.eye, _fmt(doc.views)),
              ]),
            ])),
            PopupMenuButton<String>(
              icon: Icon(LucideIcons.moreVertical, size: 18, color: _ts),
              color: _surf,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onSelected: (v) async {
                if (v == 'dl') await _download(doc);
                if (v == 'sh') await Share.share('📚 ${doc.title}\n\n${doc.downloadUrl}');
                if (v == 'info') _openDetail(doc);
              },
              itemBuilder: (_) => [
                _mItem('dl', LucideIcons.download, 'Télécharger'),
                _mItem('sh', LucideIcons.share2, 'Partager'),
                _mItem('info', LucideIcons.info, 'Détails'),
              ],
            ),
          ]),
        ),
      ),
    );
  }

  PopupMenuItem<String> _mItem(String v, IconData icon, String label) =>
      PopupMenuItem(value: v, child: Row(children: [
        Icon(icon, size: 16, color: ApexColors.primary),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(color: _tp)),
      ]));

  // ═══════════════════════════════════════════════════════════════════════
  // ÉTATS VIDE / SHIMMER / ERREUR
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildShimmer(bool grid) {
    if (grid) {
      return GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 100),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 340, crossAxisSpacing: 14, mainAxisSpacing: 14, childAspectRatio: 0.72),
        itemCount: 6,
        itemBuilder: (_, __) => Shimmer.fromColors(
          baseColor: _dark ? const Color(0xFF1C2333) : const Color(0xFFE4EAF4),
          highlightColor: _dark ? const Color(0xFF252E42) : const Color(0xFFF5F7FA),
          child: Container(
            decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(18)),
            child: Column(children: [
              Container(height: 130, decoration: BoxDecoration(
                color: _cardHi, borderRadius: const BorderRadius.vertical(top: Radius.circular(18)))),
              Padding(padding: const EdgeInsets.all(10), child: Column(children: [
                Container(height: 12, decoration: BoxDecoration(color: _cardHi, borderRadius: BorderRadius.circular(4))),
                const SizedBox(height: 6),
                Container(height: 10, width: 80, decoration: BoxDecoration(color: _cardHi, borderRadius: BorderRadius.circular(4))),
              ])),
            ]),
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: 6,
      itemBuilder: (_, __) => Shimmer.fromColors(
        baseColor: _dark ? const Color(0xFF1C2333) : const Color(0xFFE4EAF4),
        highlightColor: _dark ? const Color(0xFF252E42) : const Color(0xFFF5F7FA),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10), height: 88,
          decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }

  Widget _buildError() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Icon(LucideIcons.wifiOff, size: 40, color: _ts),
    const SizedBox(height: 12),
    Text('Erreur de connexion', style: TextStyle(color: _tp, fontWeight: FontWeight.w600)),
    const SizedBox(height: 4),
    Text('Vérifiez votre connexion internet', style: TextStyle(color: _ts, fontSize: 13)),
  ]));

  Widget _buildEmpty() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Container(width: 72, height: 72,
      decoration: BoxDecoration(gradient: ApexColors.primaryGradient, shape: BoxShape.circle),
      child: const Icon(LucideIcons.library, color: Colors.white, size: 30)),
    const SizedBox(height: 16),
    Text(_query.isNotEmpty || _cat != 'Tout' ? 'Aucun résultat' : 'Bibliothèque vide',
      style: TextStyle(color: _tp, fontSize: 18, fontWeight: FontWeight.w700)),
    const SizedBox(height: 8),
    Text(_query.isNotEmpty || _cat != 'Tout' ? 'Essayez d\'autres mots-clés' : 'Partagez le premier document !',
      style: TextStyle(color: _ts, fontSize: 13)),
    if (_query.isEmpty && _cat == 'Tout') ...[
      const SizedBox(height: 20),
      GestureDetector(
        onTap: () => _push(const UploadScreen()),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(gradient: ApexColors.primaryGradient, borderRadius: BorderRadius.circular(20)),
          child: const Text('Uploader', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        ),
      ),
    ],
  ]));

  // ═══════════════════════════════════════════════════════════════════════
  // HIGHLIGHT
  // ═══════════════════════════════════════════════════════════════════════

  Widget _highlight(String text, {required TextStyle style, int maxLines = 2}) {
    if (_query.isEmpty) return Text(text, style: style, maxLines: maxLines, overflow: TextOverflow.ellipsis);
    final lower = text.toLowerCase();
    final idx = lower.indexOf(_query);
    if (idx < 0) return Text(text, style: style, maxLines: maxLines, overflow: TextOverflow.ellipsis);
    return Text.rich(
      TextSpan(children: [
        TextSpan(text: text.substring(0, idx), style: style),
        TextSpan(text: text.substring(idx, idx + _query.length),
          style: style.copyWith(color: ApexColors.primary, fontWeight: FontWeight.w900,
            backgroundColor: ApexColors.primary.withOpacity(0.12))),
        TextSpan(text: text.substring(idx + _query.length), style: style),
      ]),
      maxLines: maxLines, overflow: TextOverflow.ellipsis,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // FILTER SHEET
  // ═══════════════════════════════════════════════════════════════════════

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(builder: (ctx, setSt) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: BoxDecoration(
          color: _surf, borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border.all(color: _bord),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(children: [
          Container(width: 36, height: 4, margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(color: _bord, borderRadius: BorderRadius.circular(2))),
          Row(children: [
            Text('Filtres', style: TextStyle(color: _tp, fontSize: 20, fontWeight: FontWeight.w700)),
            const Spacer(),
            TextButton(
              onPressed: () {
                setSt(() {});
                setState(() { _cat = 'Tout'; _sort = 'recent'; });
              },
              child: const Text('Réinitialiser', style: TextStyle(color: ApexColors.primary)),
            ),
          ]),
          Expanded(child: SingleChildScrollView(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Trier par', style: TextStyle(color: _ts, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8,
                children: [
                  ('recent', 'Récents'),
                  ('populaire', 'Populaires'),
                  ('alphabétique', 'A→Z'),
                ].map((s) {
                  final act = _sort == s.$1;
                  return GestureDetector(
                    onTap: () { setSt(() {}); setState(() => _sort = s.$1); },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                      decoration: BoxDecoration(
                        color: act ? ApexColors.primary : _card,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: act ? ApexColors.primary : _bord),
                      ),
                      child: Text(s.$2, style: TextStyle(
                        color: act ? Colors.white : _tp, fontSize: 13,
                        fontWeight: act ? FontWeight.w700 : FontWeight.w400)),
                    ),
                  );
                }).toList()),
              const SizedBox(height: 20),
              Text('Niveaux', style: TextStyle(color: _ts, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8,
                children: ['Seconde', 'Première', 'Terminale', 'BTS', 'Licence'].map((l) {
                  final sel = context.read<BiblioProvider>().levels.contains(l);
                  return GestureDetector(
                    onTap: () { setSt(() {}); context.read<BiblioProvider>().toggleLevel(l); },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                      decoration: BoxDecoration(
                        color: sel ? ApexColors.primary : _card,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: sel ? ApexColors.primary : _bord),
                      ),
                      child: Text(l, style: TextStyle(
                        color: sel ? Colors.white : _tp, fontSize: 13,
                        fontWeight: sel ? FontWeight.w600 : FontWeight.w400)),
                    ),
                  );
                }).toList()),
              const SizedBox(height: 16),
            ],
          ))),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: double.infinity, height: 50,
              decoration: BoxDecoration(gradient: ApexColors.primaryGradient, borderRadius: BorderRadius.circular(14)),
              child: const Center(child: Text('Appliquer',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15))),
            ),
          ),
        ]),
      )),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // DETAIL PAGE
  // ═══════════════════════════════════════════════════════════════════════

  Future<void> _openDetail(DocumentModel doc) async {
    debugPrint('[BIBLIO_PAGE] 📖 Ouverture détail: ${doc.title}');
    _svc.incViews(doc.id);
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => _DetailPage(doc: doc, svc: _svc, dark: _dark),
        transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
        transitionDuration: const Duration(milliseconds: 220),
      ),
    );
  }

  Future<void> _download(DocumentModel doc) async {
    try {
      debugPrint('[BIBLIO_PAGE] 📥 Téléchargement: ${doc.title}');
      await _svc.incDownloads(doc.id);
      final url = doc.downloadUrl;
      if (url.isEmpty) { _snack('URL manquante', error: true); return; }
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      }
    } catch (e) { _snack('Erreur : $e', error: true); }
  }

  Widget _stat(dynamic icon, String v, {Color? color}) => Row(children: [
    Icon(icon as IconData, size: 11, color: color ?? _ts),
    const SizedBox(width: 3),
    Text(v, style: TextStyle(color: color ?? _ts, fontSize: 10)),
  ]);

  IconData _fileIcon(String t) {
    switch (t) {
      case 'image': return LucideIcons.image;
      case 'pdf': return LucideIcons.fileText;
      default: return LucideIcons.file;
    }
  }

  String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }
}

// ═══════════════════════════════════════════════════════════════════════
// DETAIL PAGE
// ═══════════════════════════════════════════════════════════════════════

class _DetailPage extends StatefulWidget {
  final DocumentModel doc;
  final _BiblioService svc;
  final bool dark;
  const _DetailPage({required this.doc, required this.svc, required this.dark});
  @override
  State<_DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends State<_DetailPage> with SingleTickerProviderStateMixin {
  final _user = FirebaseAuth.instance.currentUser;
  bool _liked = false, _expanded = false;
  late AnimationController _likeCtrl;

  Color get _bg => widget.dark ? const Color(0xFF0B0E14) : const Color(0xFFF5F7FA);
  Color get _surf => widget.dark ? const Color(0xFF141920) : Colors.white;
  Color get _tp => widget.dark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
  Color get _ts => widget.dark ? const Color(0xFF8899BB) : const Color(0xFF6B7A99);
  Color get _bord => widget.dark ? const Color(0xFF252E42) : const Color(0xFFDDE3EF);
  Color get _card => widget.dark ? const Color(0xFF1C2333) : const Color(0xFFF0F3F8);

  @override
  void initState() {
    super.initState();
    debugPrint('[DETAIL_PAGE] 📖 initState - doc: ${widget.doc.title}');
    _likeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 280));
    _checkLiked();
  }

  Future<void> _checkLiked() async {
    if (_user == null) return;
    final v = await widget.svc.isLiked(widget.doc.id, _user!.uid);
    if (mounted) setState(() => _liked = v);
  }

  @override
  void dispose() { _likeCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final doc = widget.doc;
    final imgUrl = doc.imageUrl;

    return Scaffold(
      backgroundColor: _bg,
      body: CustomScrollView(slivers: [
        SliverAppBar(
          expandedHeight: 280, pinned: true, stretch: true,
          backgroundColor: _bg,
          leading: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              margin: const EdgeInsets.all(8),
              decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
              child: const Icon(LucideIcons.arrowLeft, color: Colors.white, size: 20),
            ),
          ),
          actions: [
            GestureDetector(
              onTap: () => Share.share('📚 ${doc.title}\n\n${doc.downloadUrl}'),
              child: Container(
                margin: const EdgeInsets.all(8),
                decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                child: const Padding(padding: EdgeInsets.all(9),
                  child: Icon(LucideIcons.share2, color: Colors.white, size: 18)),
              ),
            ),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: Stack(fit: StackFit.expand, children: [
              if (imgUrl.isNotEmpty)
                CachedNetworkImage(
                  cacheManager: _ImageCache.instance,
                  imageUrl: imgUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(color: _card),
                  errorWidget: (_, __, ___) => _detailPlaceholder(doc),
                )
              else
                _detailPlaceholder(doc),
              Container(decoration: BoxDecoration(gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black.withOpacity(0.85)],
              ))),
              Positioned(bottom: 20, left: 20, right: 20,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(doc.title, style: const TextStyle(
                    color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800, height: 1.2)),
                  const SizedBox(height: 8),
                  Wrap(spacing: 6, children: [
                    _badge(doc.category, _kCatColors[doc.category] ?? ApexColors.primary),
                    ...doc.levels.map((l) => _badge(l, Colors.white.withOpacity(0.2))),
                  ]),
                ])),
            ]),
          ),
        ),

        SliverPadding(
          padding: const EdgeInsets.all(20),
          sliver: SliverList(delegate: SliverChildListDelegate([
            Row(children: [
              _Avatar(uid: doc.authorId, name: doc.author, radius: 18, color: doc.authorColor),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(doc.author, style: TextStyle(color: _tp, fontSize: 14, fontWeight: FontWeight.w600)),
                Text('Publié le ${doc.formattedDateDetail}', style: TextStyle(color: _ts, fontSize: 11)),
              ])),
              if (doc.formattedSize.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(8), border: Border.all(color: _bord)),
                  child: Text(doc.formattedSize, style: TextStyle(color: _ts, fontSize: 11)),
                ),
            ]),
            const SizedBox(height: 20),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: _surf, borderRadius: BorderRadius.circular(14), border: Border.all(color: _bord, width: 0.5)),
              child: Row(children: [
                _statBlock(LucideIcons.download, _fmt(doc.downloads), 'Téléchargements', const Color(0xFF10B981)),
                Container(width: 1, height: 48, color: _bord),
                _statBlock(LucideIcons.eye, _fmt(doc.views), 'Vues', ApexColors.primary),
                Container(width: 1, height: 48, color: _bord),
                _statBlock(Icons.favorite_rounded, _fmt(doc.likes + (_liked ? 1 : 0)),
                  'Likes', _liked ? Colors.red : const Color(0xFF8B5CF6)),
              ]),
            ),
            const SizedBox(height: 16),

            if (doc.description.isNotEmpty) ...[
              Text('Description', style: TextStyle(color: _tp, fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: _surf, borderRadius: BorderRadius.circular(12), border: Border.all(color: _bord, width: 0.5)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(doc.description,
                    maxLines: _expanded ? null : 3,
                    overflow: _expanded ? null : TextOverflow.ellipsis,
                    style: TextStyle(color: _tp, fontSize: 14, height: 1.55)),
                  if (doc.description.length > 120)
                    GestureDetector(
                      onTap: () => setState(() => _expanded = !_expanded),
                      child: Padding(padding: const EdgeInsets.only(top: 8),
                        child: Text(_expanded ? 'Voir moins' : 'Voir plus',
                          style: const TextStyle(color: ApexColors.primary, fontWeight: FontWeight.w600, fontSize: 13))),
                    ),
                ]),
              ),
              const SizedBox(height: 16),
            ],

            if (doc.tags.isNotEmpty) ...[
              Wrap(spacing: 6, runSpacing: 6,
                children: doc.tags.map((t) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: ApexColors.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: ApexColors.primary.withOpacity(0.2))),
                  child: Text('#$t', style: const TextStyle(color: ApexColors.primary, fontSize: 11, fontWeight: FontWeight.w600)),
                )).toList()),
              const SizedBox(height: 16),
            ],

            if (imgUrl.isNotEmpty) ...[
              Text('Aperçu', style: TextStyle(color: _tp, fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () => Navigator.push(context, PageRouteBuilder(
                  pageBuilder: (_, __, ___) => Scaffold(
                    backgroundColor: Colors.black,
                    body: Stack(children: [
                      PhotoView(
                        imageProvider: CachedNetworkImageProvider(imgUrl, cacheManager: _ImageCache.instance),
                        backgroundDecoration: const BoxDecoration(color: Colors.black),
                        minScale: PhotoViewComputedScale.contained,
                        maxScale: PhotoViewComputedScale.covered * 4,
                      ),
                      Positioned(top: MediaQuery.of(context).padding.top + 10, right: 12,
                        child: GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(width: 36, height: 36,
                            decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                            child: const Icon(Icons.close, color: Colors.white, size: 20)),
                        )),
                    ]),
                  ),
                  transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
                )),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CachedNetworkImage(
                    cacheManager: _ImageCache.instance,
                    imageUrl: imgUrl, fit: BoxFit.cover,
                    width: double.infinity, height: 220,
                    placeholder: (_, __) => Container(height: 220, color: _card,
                      child: const Center(child: CircularProgressIndicator(strokeWidth: 2, color: ApexColors.primary))),
                    errorWidget: (_, __, ___) => Container(height: 100, color: _card),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            Row(children: [
              Expanded(
                child: GestureDetector(
                  onTap: () async {
                    try {
                      await widget.svc.incDownloads(doc.id);
                      final url = doc.downloadUrl;
                      if (url.isEmpty) return;
                      if (await canLaunchUrl(Uri.parse(url))) {
                        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                      }
                    } catch (e) {
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Erreur : $e'), backgroundColor: ApexColors.error));
                    }
                  },
                  child: Container(
                    height: 52,
                    decoration: BoxDecoration(gradient: ApexColors.primaryGradient, borderRadius: BorderRadius.circular(14)),
                    child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(LucideIcons.download, color: Colors.white, size: 18),
                      SizedBox(width: 8),
                      Text('Télécharger', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                    ]),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ScaleTransition(
                scale: Tween(begin: 1.0, end: 1.25).animate(CurvedAnimation(parent: _likeCtrl, curve: Curves.elasticOut)),
                child: GestureDetector(
                  onTap: () async {
                    HapticFeedback.lightImpact();
                    _likeCtrl.forward().then((_) => _likeCtrl.reverse());
                    if (_user != null) {
                      await widget.svc.toggleLike(doc.id, _user!.uid, !_liked);
                      setState(() => _liked = !_liked);
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 52, height: 52,
                    decoration: BoxDecoration(
                      color: _liked ? Colors.red.withOpacity(0.1) : _surf,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _liked ? Colors.red : _bord, width: 1.5)),
                    child: Icon(
                      _liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      size: 22, color: _liked ? Colors.red : ApexColors.primary),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 40),
          ])),
        ),
      ]),
    );
  }

  Widget _detailPlaceholder(DocumentModel doc) {
    final color = _kCatColors[doc.category] ?? ApexColors.primary;
    return Container(
      decoration: BoxDecoration(gradient: LinearGradient(
        colors: [color.withOpacity(0.3), color.withOpacity(0.08)],
        begin: Alignment.topLeft, end: Alignment.bottomRight)),
      child: Center(child: Icon(LucideIcons.fileText, size: 56, color: color.withOpacity(0.5))),
    );
  }

  Widget _badge(String t, Color c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(20)),
    child: Text(t, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
  );

  Widget _statBlock(dynamic icon, String value, String label, Color color) => Expanded(
    child: Column(children: [
      Container(width: 36, height: 36,
        decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon as IconData, color: color, size: 18)),
      const SizedBox(height: 6),
      Text(value, style: TextStyle(color: _tp, fontSize: 18, fontWeight: FontWeight.w800)),
      Text(label, style: TextStyle(color: _ts, fontSize: 9), textAlign: TextAlign.center),
    ]),
  );

  String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }
}