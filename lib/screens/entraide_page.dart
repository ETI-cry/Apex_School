
// APEX — PAGE ENTRAIDE  ·  



import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mime/mime.dart';
import 'package:photo_view/photo_view.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shimmer/shimmer.dart';
import 'package:uuid/uuid.dart';

import '../providers/theme_provider.dart';
import '../services/appwrite_service.dart';
import '../theme/apex_colors.dart';
import '../widgets/lucide_bottom_bar.dart';
import 'biblio_page.dart';
import 'chat_screen.dart';
import 'home_screen.dart';
import 'settings_screen.dart';
import 'upload_screen.dart';

// ═══════════════════════════════════════════════════════════════════════════════════════════
// CONSTANTES
// ═══════════════════════════════════════════════════════════════════════════════════════════

const String _kQuestions = 'entraide_questions';
const String _kAnswers = 'entraide_reponses';
const int _kMaxQuestionsPerHour = 5;
const int _kMaxAnswersPerMinute = 10;

// ═══════════════════════════════════════════════════════════════════════════════════════════
// RATE LIMITER
// ═══════════════════════════════════════════════════════════════════════════════════════════

class RateLimiter {
  static final RateLimiter _instance = RateLimiter._internal();
  factory RateLimiter() => _instance;
  RateLimiter._internal();

  final Map<String, List<DateTime>> _actions = {};

  bool isAllowed(String userId, String action, Duration window, int maxActions) {
    final key = '$userId:$action';
    final now = DateTime.now();
    final userActions = _actions[key] ?? [];
    userActions.removeWhere((t) => now.difference(t) > window);
    if (userActions.length >= maxActions) return false;
    userActions.add(now);
    _actions[key] = userActions;
    return true;
  }

  int getRemainingActions(String userId, String action, Duration window, int maxActions) {
    final key = '$userId:$action';
    final now = DateTime.now();
    final userActions = _actions[key] ?? [];
    userActions.removeWhere((t) => now.difference(t) > window);
    return (maxActions - userActions.length).clamp(0, maxActions);
  }
}

// ═══════════════════════════════════════════════════════════════════════════════════════════
// AVATAR SERVICE
// ═══════════════════════════════════════════════════════════════════════════════════════════

class AvatarService {
  static final AvatarService _instance = AvatarService._internal();
  factory AvatarService() => _instance;
  AvatarService._internal();

  final Map<String, String?> _urlCache = {};
  final Map<String, DateTime> _cacheTime = {};
  static const int _maxCacheSize = 200;
  static const Duration _cacheDuration = Duration(hours: 1);

  Future<String?> getAvatarUrl(String userId) async {
    if (userId.isEmpty) return null;

    if (_urlCache.containsKey(userId)) {
      final t = _cacheTime[userId];
      if (t != null && DateTime.now().difference(t) < _cacheDuration) {
        return _urlCache[userId];
      }
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get()
          .timeout(const Duration(seconds: 5));

      final data = doc.data();
      String? url;

      if (data != null) {
        url = data['avatarUrl'] as String?;
        if (url == null || url.isEmpty) {
          url = null;
        }
      }

      _setCache(userId, url);
      return url;
    } catch (_) {
      return null;
    }
  }

  void _setCache(String userId, String? url) {
    if (_urlCache.length >= _maxCacheSize) {
      final oldest = _cacheTime.entries.reduce((a, b) => a.value.isBefore(b.value) ? a : b).key;
      _urlCache.remove(oldest);
      _cacheTime.remove(oldest);
    }
    _urlCache[userId] = url;
    _cacheTime[userId] = DateTime.now();
  }

  void invalidate(String userId) {
    _urlCache.remove(userId);
    _cacheTime.remove(userId);
  }

  Future<String> uploadAvatar(XFile file, String userId) async {
    final bytes = await file.readAsBytes();
    final optimized = await _optimizeForStorage(bytes);

    final appwrite = AppwriteService();
    final fileId = await appwrite.uploadFile(
      filePath: file.path,
      userId: userId,
      filename: 'avatar_$userId.webp',
      mime: 'image/webp',
      onProgress: (_) {},
    );

    final url = appwrite.getFileUrl(fileId);

    await FirebaseFirestore.instance.collection('users').doc(userId).update({
      'avatarUrl': url,
      'avatarBase64': FieldValue.delete(),
      'avatarUpdatedAt': FieldValue.serverTimestamp(),
    });

    invalidate(userId);
    return url;
  }

  Future<Uint8List> _optimizeForStorage(Uint8List bytes) async {
    try {
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return bytes;
      final size = decoded.width > decoded.height ? decoded.width : decoded.height;
      final target = size > 512 ? 512 : size;
      final resized = img.copyResize(decoded, width: target, height: target);
      return Uint8List.fromList(img.encodeJpg(resized, quality: 90));
    } catch (_) {
      return bytes;
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════════════════════
// AVATAR WIDGET
// ═══════════════════════════════════════════════════════════════════════════════════════════

class Avatar extends StatefulWidget {
  final String userId;
  final String name;
  final double radius;
  final bool showStatus;
  final VoidCallback? onTap;

  const Avatar({
    super.key,
    required this.userId,
    required this.name,
    this.radius = 20,
    this.showStatus = false,
    this.onTap,
  });

  @override
  State<Avatar> createState() => _AvatarState();
}

class _AvatarState extends State<Avatar> {
  String? _avatarUrl;
  bool _loaded = false;

  static const List<Color> _palette = [
    Color(0xFF3B82F6), Color(0xFFEF4444), Color(0xFF22C55E),
    Color(0xFFF59E0B), Color(0xFF8B5CF6), Color(0xFF06B6D4),
    Color(0xFFEC4899), Color(0xFF10B981), Color(0xFFF97316),
  ];

  Color get _color {
    if (widget.name.isEmpty) return _palette[0];
    return _palette[widget.name.codeUnitAt(0) % _palette.length];
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(Avatar old) {
    super.didUpdateWidget(old);
    if (old.userId != widget.userId) {
      _loaded = false;
      _avatarUrl = null;
      _load();
    }
  }

  Future<void> _load() async {
    if (widget.userId.isEmpty) {
      if (mounted) setState(() => _loaded = true);
      return;
    }
    final url = await AvatarService().getAvatarUrl(widget.userId);
    if (mounted) setState(() { _avatarUrl = url; _loaded = true; });
  }

  @override
  Widget build(BuildContext context) {
    final initial = widget.name.isNotEmpty ? widget.name[0].toUpperCase() : '?';

    Widget avatar;

    if (_loaded && _avatarUrl != null && _avatarUrl!.isNotEmpty) {
      avatar = CachedNetworkImage(
        imageUrl: _avatarUrl!,
        imageBuilder: (_, img) => Container(
          width: widget.radius * 2,
          height: widget.radius * 2,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            image: DecorationImage(image: img, fit: BoxFit.cover),
          ),
        ),
        placeholder: (_, __) => _buildInitial(initial),
        errorWidget: (_, __, ___) => _buildInitial(initial),
        width: widget.radius * 2,
        height: widget.radius * 2,
        memCacheWidth: (widget.radius * 4).toInt(),
        memCacheHeight: (widget.radius * 4).toInt(),
      );
    } else {
      avatar = _buildInitial(initial);
    }

    return GestureDetector(
      onTap: widget.onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          avatar,
          if (widget.showStatus)
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: widget.radius * 0.55,
                height: widget.radius * 0.55,
                decoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    width: 1.5,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInitial(String initial) {
    return Container(
      width: widget.radius * 2,
      height: widget.radius * 2,
      decoration: BoxDecoration(
        color: _color,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: widget.radius * 0.75,
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════════════════
// IMAGE SERVICE
// ═══════════════════════════════════════════════════════════════════════════════════════════

class ImageService {
  static final ImageService _instance = ImageService._internal();
  factory ImageService() => _instance;
  ImageService._internal();

  Future<Uint8List> optimizeForUpload(XFile file) async {
    final bytes = await file.readAsBytes();
    final mime = lookupMimeType(file.path) ?? 'image/jpeg';
    if (!mime.startsWith('image/')) return bytes;

    try {
      final compressed = await FlutterImageCompress.compressWithList(
        bytes,
        quality: 88,
        minWidth: 1920,
        minHeight: 1920,
        format: CompressFormat.webp,
      );
      return compressed.length < bytes.length ? compressed : bytes;
    } catch (_) {
      return bytes;
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════════════════════
// CATÉGORIES
// ═══════════════════════════════════════════════════════════════════════════════════════════

const Map<String, Color> kCatColors = {
  'Maths': Color(0xFF3B82F6),
  'Physique': Color(0xFFF59E0B),
  'Chimie': Color(0xFFEF4444),
  'SVT': Color(0xFF22C55E),
  'Français': Color(0xFF8B5CF6),
  'Anglais': Color(0xFF06B6D4),
  'Histoire': Color(0xFFD97706),
  'Philosophie': Color(0xFFEC4899),
  'Informatique': Color(0xFF10B981),
  'Électronique': Color(0xFFF97316),
  'Méthodes': Color(0xFF64748B),
  'CMI': Color(0xFF0EA5E9),
};

const Map<String, IconData> kCatIcons = {
  'Maths': LucideIcons.calculator,
  'Physique': LucideIcons.zap,
  'Chimie': LucideIcons.beaker,
  'SVT': LucideIcons.leaf,
  'Français': LucideIcons.bookOpen,
  'Anglais': LucideIcons.languages,
  'Histoire': LucideIcons.scroll,
  'Philosophie': LucideIcons.brain,
  'Informatique': LucideIcons.monitor,
  'Électronique': LucideIcons.cpu,
  'Méthodes': LucideIcons.map,
  'CMI': LucideIcons.graduationCap,
};

const List<String> kAllCats = [
  'Maths', 'Physique', 'Chimie', 'SVT', 'Français', 'Anglais',
  'Histoire', 'Philosophie', 'Informatique', 'Électronique', 'Méthodes', 'CMI',
];

const List<String> kAllLevels = [
  'Seconde', 'Première', 'Terminale', 'BTS', 'Licence',
];

// ═══════════════════════════════════════════════════════════════════════════════════════════
// MODÈLES
// ═══════════════════════════════════════════════════════════════════════════════════════════

class QuestionModel {
  final String id, title, content, authorId, authorName;
  final DateTime createdAt;
  final List<String> categories, levels;
  final int likes, views, answersCount;
  final bool isResolved, isPinned;
  final List<Map<String, dynamic>> attachments;
  final List<String> likedBy;
  final String? bestAnswerId;

  QuestionModel({
    required this.id,
    required this.title,
    required this.content,
    required this.authorId,
    required this.authorName,
    required this.createdAt,
    required this.categories,
    required this.levels,
    required this.likes,
    required this.views,
    required this.answersCount,
    required this.isResolved,
    required this.isPinned,
    required this.attachments,
    required this.likedBy,
    this.bestAnswerId,
  });

  factory QuestionModel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return QuestionModel(
      id: doc.id,
      title: (d['title'] as String?) ?? '',
      content: (d['content'] as String?) ?? '',
      authorId: (d['authorId'] as String?) ?? '',
      authorName: (d['authorName'] as String?) ?? 'Anonyme',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      categories: List<String>.from(d['categories'] ?? []),
      levels: List<String>.from(d['levels'] ?? []),
      likes: (d['likes'] as int?) ?? 0,
      views: (d['views'] as int?) ?? 0,
      answersCount: (d['answersCount'] as int?) ?? 0,
      isResolved: (d['isResolved'] as bool?) ?? false,
      isPinned: (d['isPinned'] as bool?) ?? false,
      attachments: List<Map<String, dynamic>>.from(d['attachments'] ?? []),
      likedBy: List<String>.from(d['likedBy'] ?? []),
      bestAnswerId: d['bestAnswerId'] as String?,
    );
  }

  String get timeAgo => _formatTimeAgo(createdAt);
  String get formattedDate => DateFormat('dd MMM yyyy · HH:mm', 'fr').format(createdAt);
}

class AnswerModel {
  final String id, questionId, content, authorId, authorName;
  final DateTime createdAt;
  int likes;
  bool isBest;
  final List<Map<String, dynamic>> attachments;
  List<String> likedBy;

  AnswerModel({
    required this.id,
    required this.questionId,
    required this.content,
    required this.authorId,
    required this.authorName,
    required this.createdAt,
    required this.likes,
    required this.isBest,
    required this.attachments,
    required this.likedBy,
  });

  factory AnswerModel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return AnswerModel(
      id: doc.id,
      questionId: (d['questionId'] as String?) ?? '',
      content: (d['content'] as String?) ?? '',
      authorId: (d['authorId'] as String?) ?? '',
      authorName: (d['authorName'] as String?) ?? 'Anonyme',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      likes: (d['likes'] as int?) ?? 0,
      isBest: (d['isBestAnswer'] as bool?) ?? false,
      attachments: List<Map<String, dynamic>>.from(d['attachments'] ?? []),
      likedBy: List<String>.from(d['likedBy'] ?? []),
    );
  }

  String get timeAgo => _formatTimeAgo(createdAt);
}

String _formatTimeAgo(DateTime date) {
  final diff = DateTime.now().difference(date);
  if (diff.inDays >= 365) return '${(diff.inDays / 365).floor()}an';
  if (diff.inDays >= 30) return '${(diff.inDays / 30).floor()}mois';
  if (diff.inDays > 0) return '${diff.inDays}j';
  if (diff.inHours > 0) return '${diff.inHours}h';
  if (diff.inMinutes > 0) return '${diff.inMinutes}min';
  return 'maintenant';
}

String _formatNum(int n) {
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
  return '$n';
}

// ═══════════════════════════════════════════════════════════════════════════════════════════
// SERVICE ENTRAIDE
// ═══════════════════════════════════════════════════════════════════════════════════════════

class EntraideService {
  final _db = FirebaseFirestore.instance;
  final _appwrite = AppwriteService();

  Future<String> createQuestion({
    required String title,
    required String content,
    required List<String> cats,
    required List<String> levels,
    required List<Map<String, dynamic>> att,
    required String uid,
    required String name,
  }) async {
    final id = const Uuid().v4();
    debugPrint('[ENTRAIDE_SERVICE] 📝 Création question: $title');
    await _db.collection(_kQuestions).doc(id).set({
      'id': id,
      'title': title.trim(),
      'content': content.trim(),
      'authorId': uid,
      'authorName': name,
      'createdAt': Timestamp.now(),
      'categories': cats,
      'levels': levels,
      'likes': 0,
      'views': 0,
      'answersCount': 0,
      'isResolved': false,
      'isPinned': false,
      'attachments': att,
      'likedBy': [],
      'bestAnswerId': null,
      'searchKeywords': _generateKeywords('$title $content'),
    });
    return id;
  }

  Future<String> createAnswer({
    required String qid,
    required String content,
    required String uid,
    required String name,
    required List<Map<String, dynamic>> att,
  }) async {
    final id = const Uuid().v4();
    debugPrint('[ENTRAIDE_SERVICE] 💬 Création réponse pour: $qid');
    final batch = _db.batch();
    batch.set(_db.collection(_kAnswers).doc(id), {
      'questionId': qid,
      'content': content.trim(),
      'authorId': uid,
      'authorName': name,
      'createdAt': Timestamp.now(),
      'likes': 0,
      'isBestAnswer': false,
      'attachments': att,
      'likedBy': [],
    });
    batch.update(_db.collection(_kQuestions).doc(qid), {
      'answersCount': FieldValue.increment(1),
    });
    await batch.commit();
    return id;
  }

  Future<void> toggleLikeQuestion(String id, String uid, bool liked) async {
    debugPrint('[ENTRAIDE_SERVICE] ❤️ Toggle like question: $id, liked: $liked');
    await _db.collection(_kQuestions).doc(id).update(liked
        ? {'likes': FieldValue.increment(1), 'likedBy': FieldValue.arrayUnion([uid])}
        : {'likes': FieldValue.increment(-1), 'likedBy': FieldValue.arrayRemove([uid])});
  }

  Future<void> toggleLikeAnswer(String id, String uid, bool liked) async {
    debugPrint('[ENTRAIDE_SERVICE] ❤️ Toggle like réponse: $id, liked: $liked');
    await _db.collection(_kAnswers).doc(id).update(liked
        ? {'likes': FieldValue.increment(1), 'likedBy': FieldValue.arrayUnion([uid])}
        : {'likes': FieldValue.increment(-1), 'likedBy': FieldValue.arrayRemove([uid])});
  }

  Future<void> markBest(String qid, String aid) async {
    debugPrint('[ENTRAIDE_SERVICE] ⭐ Marquer meilleure réponse: $aid');
    final batch = _db.batch();
    batch.update(_db.collection(_kAnswers).doc(aid), {'isBestAnswer': true});
    batch.update(_db.collection(_kQuestions).doc(qid), {
      'bestAnswerId': aid,
      'isResolved': true,
    });
    await batch.commit();
  }

  Future<void> deleteAnswer(String aid, String qid) async {
    debugPrint('[ENTRAIDE_SERVICE] 🗑️ Suppression réponse: $aid');
    final batch = _db.batch();
    batch.delete(_db.collection(_kAnswers).doc(aid));
    batch.update(_db.collection(_kQuestions).doc(qid), {
      'answersCount': FieldValue.increment(-1),
    });
    await batch.commit();
  }

  Future<void> incViews(String id) async {
    debugPrint('[ENTRAIDE_SERVICE] 👁️ Inc views: $id');
    await _db.collection(_kQuestions).doc(id).update({'views': FieldValue.increment(1)});
  }

  Future<Map<String, dynamic>> uploadAttachment(XFile file, String uid) async {
    debugPrint('[ENTRAIDE_SERVICE] 📎 Upload attachment: ${file.name}');
    final bytes = await ImageService().optimizeForUpload(file);
    final mime = lookupMimeType(file.path) ?? 'application/octet-stream';

    final fileId = kIsWeb
        ? await _appwrite.uploadFileWeb(
            bytes: bytes, filename: file.name, userId: uid, mime: mime, onProgress: (_) {})
        : await _appwrite.uploadFile(
            filePath: file.path, userId: uid, filename: file.name, mime: mime, onProgress: (_) {});

    return {
      'url': _appwrite.getFileUrl(fileId),
      'fileId': fileId,
      'type': mime.startsWith('image/') ? 'image' : 'file',
      'name': file.name,
      'mime': mime,
      'size': bytes.length,
    };
  }

  List<String> _generateKeywords(String text) {
    final words = text.toLowerCase().split(RegExp(r'\s+'));
    final kw = <String>{};
    for (final w in words) {
      if (w.length > 2) {
        for (var i = 2; i <= w.length && i <= 5; i++) kw.add(w.substring(0, i));
      }
    }
    return kw.toList();
  }
}

// ═══════════════════════════════════════════════════════════════════════════════════════════
// ATTACHMENT PREVIEW
// ═══════════════════════════════════════════════════════════════════════════════════════════

class AttachmentPreview extends StatelessWidget {
  final Map<String, dynamic> attachment;
  final VoidCallback? onRemove;
  final bool isSmall;

  const AttachmentPreview({
    super.key,
    required this.attachment,
    this.onRemove,
    this.isSmall = false,
  });

  void _openFullScreen(BuildContext context) {
    final url = attachment['url'] as String? ?? '';
    if (url.isEmpty) return;
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => _FullScreenImage(url: url),
        transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
        transitionDuration: const Duration(milliseconds: 250),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final type = attachment['type'] as String? ?? 'file';
    final url = attachment['url'] as String? ?? '';
    final name = attachment['name'] as String? ?? 'Fichier';
    final size = isSmall ? 60.0 : 140.0;
    final radius = isSmall ? 10.0 : 14.0;

    return GestureDetector(
      onTap: type == 'image' ? () => _openFullScreen(context) : null,
      child: Container(
        width: size,
        height: size,
        margin: EdgeInsets.only(right: isSmall ? 8 : 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E30) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: ApexColors.primary.withOpacity(0.25), width: 1.5),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: type == 'image' && url.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: url,
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                  memCacheWidth: size.toInt() * 2,
                  placeholder: (_, __) => Container(color: isDark ? const Color(0xFF2A2A3E) : Colors.grey.shade200),
                  errorWidget: (_, __, ___) => _fileIcon(type, size, name, isDark),
                )
              : _fileIcon(type, size, name, isDark),
        ),
      ),
    );
  }

  Widget _fileIcon(String type, double size, String name, bool isDark) {
    final icon = type == 'pdf' ? LucideIcons.fileText : type == 'image' ? LucideIcons.image : LucideIcons.file;
    final color = type == 'pdf' ? Colors.red : ApexColors.primary;

    return Stack(
      children: [
        Container(
          width: size,
          height: size,
          color: isDark ? const Color(0xFF1E1E30) : const Color(0xFFF1F5F9),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: size * 0.35),
              if (!isSmall) ...[
                const SizedBox(height: 4),
                Text(
                  type.toUpperCase(),
                  style: TextStyle(color: color, fontSize: size * 0.07, fontWeight: FontWeight.w700),
                ),
              ],
            ],
          ),
        ),
        if (onRemove != null)
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                width: 22,
                height: 22,
                decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                child: const Icon(LucideIcons.x, size: 12, color: Colors.white),
              ),
            ),
          ),
      ],
    );
  }
}

class _FullScreenImage extends StatelessWidget {
  final String url;
  const _FullScreenImage({required this.url});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PhotoView(
            imageProvider: CachedNetworkImageProvider(url),
            backgroundDecoration: const BoxDecoration(color: Colors.black),
            minScale: PhotoViewComputedScale.contained,
            maxScale: PhotoViewComputedScale.covered * 4,
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            right: 16,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                child: const Icon(Icons.close, color: Colors.white, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════════════════
// ANSWER BAR
// ═══════════════════════════════════════════════════════════════════════════════════════════

class AnswerBar extends StatefulWidget {
  final String questionId;
  final VoidCallback onAnswerSent;

  const AnswerBar({super.key, required this.questionId, required this.onAnswerSent});

  @override
  State<AnswerBar> createState() => _AnswerBarState();
}

class _AnswerBarState extends State<AnswerBar> {
  final User? _user = FirebaseAuth.instance.currentUser;
  final EntraideService _service = EntraideService();
  final TextEditingController _ctrl = TextEditingController();
  final List<Map<String, dynamic>> _attachments = [];

  bool _isSending = false;
  bool _isUploading = false;
  String? _limitMsg;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  bool get _canSend =>
      (_ctrl.text.trim().isNotEmpty || _attachments.isNotEmpty) &&
      !_isSending &&
      !_isUploading &&
      _limitMsg == null;

  Future<void> _pickAttachment() async {
    if (_user == null) return;
    setState(() => _isUploading = true);
    try {
      final file = await ImagePicker().pickMedia();
      if (file != null) {
        final att = await _service.uploadAttachment(file, _user!.uid);
        setState(() => _attachments.add(att));
      }
    } catch (e) {
      _snack('Erreur upload : $e', error: true);
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _send() async {
    if (!_canSend || _user == null) return;

    if (!RateLimiter().isAllowed(_user!.uid, 'answer', const Duration(minutes: 1), _kMaxAnswersPerMinute)) {
      final rem = RateLimiter().getRemainingActions(_user!.uid, 'answer', const Duration(minutes: 1), _kMaxAnswersPerMinute);
      setState(() => _limitMsg = 'Patientez avant d\'envoyer ($rem/$_kMaxAnswersPerMinute restants)');
      HapticFeedback.heavyImpact();
      Future.delayed(const Duration(seconds: 3), () { if (mounted) setState(() => _limitMsg = null); });
      return;
    }

    final content = _ctrl.text.trim();
    setState(() { _isSending = true; _ctrl.clear(); });

    try {
      await _service.createAnswer(
        qid: widget.questionId,
        content: content,
        uid: _user!.uid,
        name: _user!.displayName ?? 'Anonyme',
        att: List.from(_attachments),
      );
      setState(() => _attachments.clear());
      widget.onAnswerSent();
    } catch (e) {
      _snack('Erreur : $e', error: true);
      _ctrl.text = content;
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _snack(String msg, {required bool error}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? ApexColors.error : ApexColors.success,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.only(
        left: 12, right: 12, top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F0F1A) : Colors.white,
        border: Border(top: BorderSide(color: isDark ? Colors.white10 : Colors.black12)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_attachments.isNotEmpty)
            SizedBox(
              height: 68,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _attachments.length,
                itemBuilder: (_, i) => AttachmentPreview(
                  attachment: _attachments[i],
                  onRemove: () => setState(() => _attachments.removeAt(i)),
                  isSmall: true,
                ),
              ),
            ),
          if (_limitMsg != null)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: ApexColors.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(LucideIcons.clock, size: 14, color: ApexColors.error),
                const SizedBox(width: 6),
                Text(_limitMsg!, style: const TextStyle(color: ApexColors.error, fontSize: 12)),
              ]),
            ),
          Row(
            children: [
              IconButton(
                onPressed: _isUploading ? null : _pickAttachment,
                icon: _isUploading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(LucideIcons.paperclip, size: 22),
                color: isDark ? Colors.white70 : Colors.grey.shade600,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1A1A2E) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: TextField(
                    controller: _ctrl,
                    maxLines: null,
                    minLines: 1,
                    onChanged: (_) => setState(() {}),
                    style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Écrire une réponse...',
                      hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.grey.shade500, fontSize: 14),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _canSend ? _send : null,
                icon: _isSending
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.send_rounded, size: 22),
                color: _canSend ? ApexColors.primary : (isDark ? Colors.white24 : Colors.grey.shade300),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════════════════
// QUESTION DETAIL PAGE
// ═══════════════════════════════════════════════════════════════════════════════════════════

class QuestionDetailPage extends StatefulWidget {
  final QuestionModel question;
  const QuestionDetailPage({super.key, required this.question});

  @override
  State<QuestionDetailPage> createState() => _QuestionDetailPageState();
}

class _QuestionDetailPageState extends State<QuestionDetailPage> {
  final User? _user = FirebaseAuth.instance.currentUser;
  final EntraideService _service = EntraideService();
  final ScrollController _scroll = ScrollController();

  bool _isLiked = false;
  bool _showFab = false;
  late QuestionModel _q;

  @override
  void initState() {
    super.initState();
    debugPrint('[DETAIL_PAGE] 📖 initState - question: ${widget.question.title}');
    _q = widget.question;
    _isLiked = _q.likedBy.contains(_user?.uid);
    _scroll.addListener(() {
      final show = _scroll.position.pixels > 300;
      if (_showFab != show) setState(() => _showFab = show);
    });
    _service.incViews(_q.id);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToBottom() => _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = _q.categories.isNotEmpty
        ? kCatColors[_q.categories.first] ?? ApexColors.primary
        : ApexColors.primary;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : const Color(0xFFF8FAFC),
      body: Column(
        children: [
          _buildHeader(isDark),
          Expanded(
            child: CustomScrollView(
              controller: _scroll,
              slivers: [
                SliverToBoxAdapter(child: _buildQuestionCard(isDark, primaryColor)),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                    child: Row(
                      children: [
                        Icon(LucideIcons.messageSquare, size: 15, color: isDark ? Colors.white54 : Colors.grey.shade600),
                        const SizedBox(width: 6),
                        Text(
                          '${_q.answersCount} réponse${_q.answersCount > 1 ? 's' : ''}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection(_kAnswers)
                      .where('questionId', isEqualTo: _q.id)
                      .snapshots(),
                  builder: (_, snap) {
                    debugPrint('[DETAIL_PAGE] 📡 Réponses stream - hasData: ${snap.hasData}');
                    if (!snap.hasData) {
                      return const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                        ),
                      );
                    }

                    final answers = snap.data!.docs.map(AnswerModel.fromDoc).toList()
                      ..sort((a, b) {
                        if (a.isBest && !b.isBest) return -1;
                        if (!a.isBest && b.isBest) return 1;
                        return b.createdAt.compareTo(a.createdAt);
                      });

                    if (answers.isEmpty) {
                      return SliverToBoxAdapter(child: _buildEmptyAnswers(isDark));
                    }

                    return SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (_, i) => _buildAnswerCard(answers[i], isDark),
                          childCount: answers.length,
                        ),
                      ),
                    );
                  },
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 20)),
              ],
            ),
          ),
          AnswerBar(questionId: _q.id, onAnswerSent: _scrollToBottom),
        ],
      ),
      floatingActionButton: _showFab
          ? FloatingActionButton.small(
              onPressed: _scrollToBottom,
              backgroundColor: ApexColors.primary,
              child: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildHeader(bool isDark) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 4, right: 8, bottom: 8,
      ),
      decoration: BoxDecoration(
        color: isDark ? Colors.black : Colors.white,
        border: Border(bottom: BorderSide(color: isDark ? Colors.white10 : Colors.black12)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(LucideIcons.arrowLeft),
            color: ApexColors.primary,
            onPressed: () => Navigator.pop(context),
          ),
          const Spacer(),
          IconButton(
            icon: Icon(LucideIcons.share2, color: isDark ? Colors.white70 : Colors.grey.shade600),
            onPressed: () => Share.share('${_q.title}\n\n${_q.content}'),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionCard(bool isDark, Color primaryColor) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.25 : 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Avatar(userId: _q.authorId, name: _q.authorName, radius: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _q.authorName,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    Text(
                      _q.formattedDate,
                      style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              if (_q.isResolved)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(children: [
                    Icon(LucideIcons.checkCircle, size: 12, color: Colors.green),
                    SizedBox(width: 4),
                    Text('Résolu', style: TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.w600)),
                  ]),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _q.title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : Colors.black,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _q.content,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white70 : Colors.grey.shade700,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              ..._q.categories.map((c) => _tag(c, kCatColors[c] ?? ApexColors.primary)),
              ..._q.levels.map((l) => _levelTag(l, isDark)),
            ],
          ),
          if (_q.attachments.isNotEmpty) ...[
            const SizedBox(height: 14),
            SizedBox(
              height: 140,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _q.attachments.length,
                itemBuilder: (_, i) => AttachmentPreview(attachment: _q.attachments[i]),
              ),
            ),
          ],
          const SizedBox(height: 14),
          Divider(color: isDark ? Colors.white10 : Colors.grey.shade200),
          const SizedBox(height: 10),
          Row(
            children: [
              GestureDetector(
                onTap: () async {
                  if (_user == null) return;
                  setState(() => _isLiked = !_isLiked);
                  await _service.toggleLikeQuestion(_q.id, _user!.uid, _isLiked);
                  HapticFeedback.lightImpact();
                },
                child: Row(children: [
                  Icon(
                    _isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    size: 18,
                    color: _isLiked ? Colors.red : (isDark ? Colors.white54 : Colors.grey.shade600),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _formatNum(_q.likes + (_isLiked ? 1 : 0)),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _isLiked ? Colors.red : (isDark ? Colors.white70 : Colors.grey.shade700),
                    ),
                  ),
                ]),
              ),
              const SizedBox(width: 20),
              Row(children: [
                Icon(LucideIcons.eye, size: 15, color: isDark ? Colors.white54 : Colors.grey.shade600),
                const SizedBox(width: 6),
                Text(
                  _formatNum(_q.views),
                  style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.grey.shade700),
                ),
              ]),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnswerCard(AnswerModel answer, bool isDark) {
    final isLiked = answer.likedBy.contains(_user?.uid);
    final isAuthor = answer.authorId == _user?.uid;
    final isOwner = _q.authorId == _user?.uid;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: answer.isBest
            ? (isDark ? Colors.green.withOpacity(0.08) : Colors.green.withOpacity(0.04))
            : (isDark ? const Color(0xFF1A1A2E) : Colors.white),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: answer.isBest
              ? Colors.green.withOpacity(0.35)
              : (isDark ? Colors.white10 : Colors.grey.shade200),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Avatar(userId: answer.authorId, name: answer.authorName, radius: 16),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Text(
                        answer.authorName,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      if (answer.isBest) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(10)),
                          child: const Text('Meilleure', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ]),
                    Text(
                      answer.timeAgo,
                      style: TextStyle(fontSize: 10, color: isDark ? Colors.white54 : Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              if (isOwner && !answer.isBest && !_q.isResolved)
                IconButton(
                  icon: const Icon(LucideIcons.checkCircle, size: 18, color: Colors.green),
                  tooltip: 'Marquer meilleure réponse',
                  onPressed: () async {
                    await _service.markBest(_q.id, answer.id);
                    setState(() {});
                  },
                ),
              if (isAuthor)
                IconButton(
                  icon: const Icon(LucideIcons.trash2, size: 16, color: Colors.red),
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Supprimer la réponse'),
                        content: const Text('Cette action est irréversible.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(context, true),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                            child: const Text('Supprimer'),
                          ),
                        ],
                      ),
                    );
                    if (ok == true) await _service.deleteAnswer(answer.id, _q.id);
                  },
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            answer.content,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white70 : Colors.grey.shade800,
              height: 1.45,
            ),
          ),
          if (answer.attachments.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 140,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: answer.attachments.length,
                itemBuilder: (_, i) => AttachmentPreview(attachment: answer.attachments[i]),
              ),
            ),
          ],
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () async {
              if (_user == null) return;
              setState(() {
                if (isLiked) answer.likedBy.remove(_user!.uid);
                else answer.likedBy.add(_user!.uid);
              });
              await _service.toggleLikeAnswer(answer.id, _user!.uid, !isLiked);
              HapticFeedback.lightImpact();
            },
            child: Row(children: [
              Icon(
                isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                size: 14,
                color: isLiked ? Colors.red : (isDark ? Colors.white54 : Colors.grey.shade600),
              ),
              const SizedBox(width: 4),
              Text(
                _formatNum(answer.likes + (isLiked ? 1 : 0)),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isLiked ? Colors.red : (isDark ? Colors.white70 : Colors.grey.shade700),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyAnswers(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(gradient: ApexColors.primaryGradient, shape: BoxShape.circle),
            child: const Icon(LucideIcons.messageSquare, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 16),
          Text(
            'Aucune réponse pour le moment',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black),
          ),
          const SizedBox(height: 6),
          Text(
            'Soyez le premier à répondre !',
            style: TextStyle(fontSize: 13, color: isDark ? Colors.white54 : Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _tag(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
        child: Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
      );

  Widget _levelTag(String label, bool isDark) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isDark ? Colors.white10 : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : Colors.grey.shade700, fontWeight: FontWeight.w500),
        ),
      );
}

// ═══════════════════════════════════════════════════════════════════════════════════════════
// ASK QUESTION PAGE
// ═══════════════════════════════════════════════════════════════════════════════════════════

class AskQuestionPage extends StatefulWidget {
  final VoidCallback? onQuestionCreated;
  const AskQuestionPage({super.key, this.onQuestionCreated});

  @override
  State<AskQuestionPage> createState() => _AskQuestionPageState();
}

class _AskQuestionPageState extends State<AskQuestionPage> {
  final User? _user = FirebaseAuth.instance.currentUser;
  final EntraideService _service = EntraideService();
  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _contentCtrl = TextEditingController();

  final List<String> _selCats = [];
  final List<String> _selLevels = [];
  final List<Map<String, dynamic>> _attachments = [];

  bool _submitting = false;
  bool _uploading = false;
  String? _limitMsg;

  bool get _valid =>
      _titleCtrl.text.trim().length >= 5 &&
      _contentCtrl.text.trim().length >= 10 &&
      _selCats.isNotEmpty &&
      _selLevels.isNotEmpty;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAtt() async {
    if (_user == null) return;
    setState(() => _uploading = true);
    try {
      final file = await ImagePicker().pickMedia();
      if (file != null) {
        final att = await _service.uploadAttachment(file, _user!.uid);
        setState(() => _attachments.add(att));
      }
    } catch (e) {
      _snack('Erreur upload : $e', error: true);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _submit() async {
    if (!_valid || _user == null) return;

    if (!RateLimiter().isAllowed(_user!.uid, 'question', const Duration(hours: 1), _kMaxQuestionsPerHour)) {
      setState(() => _limitMsg = 'Limite atteinte : $_kMaxQuestionsPerHour questions/heure');
      HapticFeedback.heavyImpact();
      Future.delayed(const Duration(seconds: 3), () { if (mounted) setState(() => _limitMsg = null); });
      return;
    }

    setState(() => _submitting = true);
    try {
      await _service.createQuestion(
        title: _titleCtrl.text.trim(),
        content: _contentCtrl.text.trim(),
        cats: _selCats,
        levels: _selLevels,
        att: _attachments.map((a) { final c = Map<String, dynamic>.from(a); c.remove('bytes'); return c; }).toList(),
        uid: _user!.uid,
        name: _user!.displayName ?? 'Utilisateur',
      );
      widget.onQuestionCreated?.call();
      if (mounted) {
        Navigator.pop(context);
        _snack('Question publiée !', error: false);
      }
    } catch (e) {
      _snack('Erreur : $e', error: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _snack(String msg, {required bool error}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? ApexColors.error : ApexColors.success,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Poser une question'),
        centerTitle: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: GestureDetector(
              onTap: _valid && !_submitting ? _submit : null,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  gradient: _valid && !_submitting ? ApexColors.primaryGradient : null,
                  color: _valid && !_submitting ? null : (isDark ? Colors.white10 : Colors.grey.shade200),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: _submitting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(
                        'Publier',
                        style: TextStyle(
                          color: _valid ? Colors.white : (isDark ? Colors.white54 : Colors.grey.shade500),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_limitMsg != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: ApexColors.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(children: [
                  const Icon(LucideIcons.clock, size: 18, color: ApexColors.error),
                  const SizedBox(width: 12),
                  Expanded(child: Text(_limitMsg!, style: const TextStyle(color: ApexColors.error))),
                ]),
              ),
            _sectionLabel('Titre'),
            const SizedBox(height: 8),
            _inputField(
              controller: _titleCtrl,
              hint: 'Ex: Comment résoudre une équation du second degré ?',
              isDark: isDark,
            ),
            if (_titleCtrl.text.isNotEmpty && _titleCtrl.text.trim().length < 5)
              _validationMsg('Minimum 5 caractères'),
            const SizedBox(height: 20),
            _sectionLabel('Description'),
            const SizedBox(height: 8),
            _inputField(
              controller: _contentCtrl,
              hint: 'Expliquez votre problème en détail...',
              maxLines: 6,
              isDark: isDark,
            ),
            if (_contentCtrl.text.isNotEmpty && _contentCtrl.text.trim().length < 10)
              _validationMsg('Minimum 10 caractères'),
            const SizedBox(height: 20),
            _sectionLabel('Matières'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: kAllCats.map((c) {
                final sel = _selCats.contains(c);
                final color = kCatColors[c] ?? ApexColors.primary;
                return GestureDetector(
                  onTap: () { setState(() => sel ? _selCats.remove(c) : _selCats.add(c)); HapticFeedback.selectionClick(); },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: sel ? color : (isDark ? const Color(0xFF1A1A2E) : Colors.white),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: sel ? color : (isDark ? Colors.white24 : Colors.grey.shade300)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(kCatIcons[c] ?? LucideIcons.tag, size: 13, color: sel ? Colors.white : (isDark ? Colors.white70 : Colors.grey.shade600)),
                      const SizedBox(width: 6),
                      Text(c, style: TextStyle(fontSize: 13, color: sel ? Colors.white : (isDark ? Colors.white70 : Colors.grey.shade700), fontWeight: sel ? FontWeight.w600 : FontWeight.normal)),
                    ]),
                  ),
                );
              }).toList(),
            ),
            if (_selCats.isEmpty) _validationMsg('Sélectionnez au moins une matière'),
            const SizedBox(height: 20),
            _sectionLabel('Niveaux'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: kAllLevels.map((l) {
                final sel = _selLevels.contains(l);
                return GestureDetector(
                  onTap: () { setState(() => sel ? _selLevels.remove(l) : _selLevels.add(l)); HapticFeedback.selectionClick(); },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: sel ? ApexColors.primary : (isDark ? const Color(0xFF1A1A2E) : Colors.white),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: sel ? ApexColors.primary : (isDark ? Colors.white24 : Colors.grey.shade300)),
                    ),
                    child: Text(l, style: TextStyle(color: sel ? Colors.white : (isDark ? Colors.white70 : Colors.grey.shade700), fontWeight: sel ? FontWeight.w600 : FontWeight.normal)),
                  ),
                );
              }).toList(),
            ),
            if (_selLevels.isEmpty) _validationMsg('Sélectionnez au moins un niveau'),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _sectionLabel('Pièces jointes'),
                TextButton.icon(
                  onPressed: _uploading ? null : _pickAtt,
                  icon: _uploading
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(LucideIcons.paperclip, size: 18),
                  label: Text(_uploading ? 'Envoi...' : 'Ajouter'),
                ),
              ],
            ),
            if (_attachments.isNotEmpty)
              SizedBox(
                height: 140,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _attachments.length,
                  itemBuilder: (_, i) => AttachmentPreview(
                    attachment: _attachments[i],
                    onRemove: () => setState(() => _attachments.removeAt(i)),
                  ),
                ),
              ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String label) => Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600));

  Widget _inputField({required TextEditingController controller, required String hint, int maxLines = 1, required bool isDark}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.grey.shade500),
        filled: true,
        fillColor: isDark ? const Color(0xFF1A1A2E) : Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _validationMsg(String msg) => Padding(
        padding: const EdgeInsets.only(top: 5, left: 4),
        child: Text(msg, style: const TextStyle(fontSize: 12, color: ApexColors.error)),
      );
}

// ═══════════════════════════════════════════════════════════════════════════════════════════
// ENTRAIDE PAGE — VERSION ULTRA FLUIDE
// ═══════════════════════════════════════════════════════════════════════════════════════════

class EntraidePage extends StatefulWidget {
  const EntraidePage({super.key});

  @override
  State<EntraidePage> createState() => _EntraidePageState();
}

class _EntraidePageState extends State<EntraidePage>
    with SingleTickerProviderStateMixin {
  final User? _user = FirebaseAuth.instance.currentUser;
  final EntraideService _service = EntraideService();
  final ScrollController _scroll = ScrollController();
  final TextEditingController _searchCtrl = TextEditingController();

  // État local pour les filtres
  Set<String> _selectedCategories = {};
  String _sortBy = 'recent';
  String _searchQuery = '';
  bool _isGridView = false;
  final bool _showFilters = false;

  Timer? _debounce;

  late AnimationController _fabCtrl;
  late Animation<double> _fabAnim;

  // Stream de données Firestore DIRECT
  late final Stream<List<QuestionModel>> _questionsStream;

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  @override
  void initState() {
    super.initState();
    debugPrint('[ENTRAIDE_PAGE] 📱 initState() - Démarrage');

    _fabCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _fabAnim = CurvedAnimation(parent: _fabCtrl, curve: Curves.easeOutBack);
    _fabCtrl.forward();

    // ✅ STREAMBUILDER DIRECT - Pas de cache, pas de singleton
    _questionsStream = FirebaseFirestore.instance
        .collection(_kQuestions)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) {
          debugPrint('[ENTRAIDE_PAGE] 📡 Firestore stream: ${snap.docs.length} questions reçues');
          return snap.docs.map(QuestionModel.fromDoc).toList();
        });

    debugPrint('[ENTRAIDE_PAGE] ✅ Stream initialisé');
  }

  @override
  void dispose() {
    _scroll.dispose();
    _debounce?.cancel();
    _searchCtrl.dispose();
    _fabCtrl.dispose();
    super.dispose();
  }

  void _onSearch(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      setState(() {
        _searchQuery = q.trim().toLowerCase();
      });
    });
  }

  void _toggleCategory(String cat) {
    setState(() {
      if (_selectedCategories.contains(cat)) {
        _selectedCategories.remove(cat);
      } else {
        _selectedCategories.add(cat);
      }
    });
  }

  void _setSort(String sort) {
    setState(() {
      _sortBy = sort;
    });
  }

  void _resetFilters() {
    setState(() {
      _selectedCategories.clear();
      _sortBy = 'recent';
      _searchQuery = '';
      _searchCtrl.clear();
    });
  }

  // ═══════════════════════════════════════════════════════════════════════
  // APPLICATION DES FILTRES (localement sur les données du stream)
  // ═══════════════════════════════════════════════════════════════════════

  List<QuestionModel> _applyFilters(List<QuestionModel> questions) {
    debugPrint('[ENTRAIDE_PAGE] 🔍 Application filtres - questions entrantes: ${questions.length}');
    
    var filtered = List<QuestionModel>.from(questions);

    // Filtre recherche textuelle
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((q) =>
        q.title.toLowerCase().contains(_searchQuery) ||
        q.content.toLowerCase().contains(_searchQuery) ||
        q.categories.any((c) => c.toLowerCase().contains(_searchQuery))
      ).toList();
      debugPrint('[ENTRAIDE_PAGE] 🔍 Après recherche: ${filtered.length}');
    }

    // Filtre catégories
    if (_selectedCategories.isNotEmpty) {
      filtered = filtered.where((q) =>
        q.categories.any((c) => _selectedCategories.contains(c))
      ).toList();
      debugPrint('[ENTRAIDE_PAGE] 🔍 Après catégories: ${filtered.length}');
    }

    // Tri
    switch (_sortBy) {
      case 'recent':
        filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case 'oldest':
        filtered.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
      case 'votes':
        filtered.sort((a, b) => b.likes.compareTo(a.likes));
        break;
      case 'reponses':
        filtered.sort((a, b) => b.answersCount.compareTo(a.answersCount));
        break;
    }
    debugPrint('[ENTRAIDE_PAGE] 🔍 Après tri ($_sortBy): ${filtered.length}');

    return filtered;
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FilterSheet(
        selectedCategories: _selectedCategories.toList(),
        sortBy: _sortBy,
        onApply: (cats, sort) {
          setState(() {
            _selectedCategories = cats.toSet();
            _sortBy = sort;
          });
          Navigator.pop(context);
        },
        onReset: () {
          setState(() {
            _selectedCategories.clear();
            _sortBy = 'recent';
          });
          Navigator.pop(context);
        },
      ),
    );
  }

  void _snack(String msg, {required bool error}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? ApexColors.error : ApexColors.success,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _isDark ? Colors.black : const Color(0xFFF8FAFC),
      body: Column(
        children: [
          _buildHeader(),
          _buildSearchBar(),
          _buildCategoryChips(),
          const SizedBox(height: 4),
          Expanded(
            child: StreamBuilder<List<QuestionModel>>(
              stream: _questionsStream,
              builder: (context, snapshot) {
                debugPrint('[ENTRAIDE_PAGE] 📡 StreamBuilder - state: ${snapshot.connectionState}, hasData: ${snapshot.hasData}');

                // Chargement initial
                if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                  debugPrint('[ENTRAIDE_PAGE] ⏳ Affichage shimmer');
                  return _buildShimmer();
                }

                // Erreur
                if (snapshot.hasError) {
                  debugPrint('[ENTRAIDE_PAGE] ❌ Erreur: ${snapshot.error}');
                  return _buildError();
                }

                // Pas de données
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  debugPrint('[ENTRAIDE_PAGE] 📭 Pas de données');
                  return _buildEmpty();
                }

                // Données reçues - application des filtres
                final allQuestions = snapshot.data!;
                debugPrint('[ENTRAIDE_PAGE] 📦 Données reçues: ${allQuestions.length} questions');

                final filteredQuestions = _applyFilters(allQuestions);
                debugPrint('[ENTRAIDE_PAGE] 📊 Affichage final: ${filteredQuestions.length} questions');

                if (filteredQuestions.isEmpty) {
                  return _buildEmpty();
                }

                if (_isGridView) {
                  return GridView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 100),
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 380,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.82,
                    ),
                    itemCount: filteredQuestions.length,
                    itemBuilder: (_, i) => _buildCard(filteredQuestions[i], i),
                  );
                }

                return ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                  itemCount: filteredQuestions.length,
                  itemBuilder: (_, i) => _buildCard(filteredQuestions[i], i),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: ScaleTransition(
        scale: _fabAnim,
        child: FloatingActionButton.extended(
          onPressed: _navigateToAsk,
          icon: const Icon(LucideIcons.plus, size: 18),
          label: const Text('Poser', style: TextStyle(fontWeight: FontWeight.w600)),
          backgroundColor: ApexColors.primary,
          foregroundColor: Colors.white,
        ),
      ),
      bottomNavigationBar: LucideBottomBar(
        selectedIndex: 1,
        onTap: _onBottomTap,
      ),
    );
  }

  Widget _buildHeader() {
    final name = _user?.displayName?.trim() ?? 'Explorateur';

    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12,
        left: 16, right: 16, bottom: 12,
      ),
      decoration: BoxDecoration(
        color: _isDark ? Colors.black : Colors.white,
        border: Border(bottom: BorderSide(color: _isDark ? Colors.white10 : Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Avatar(
            userId: _user?.uid ?? '',
            name: name,
            radius: 22,
            showStatus: true,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700,
                    color: _isDark ? Colors.white : Colors.black,
                  ),
                ),
                Text(
                  'Entraide académique',
                  style: TextStyle(fontSize: 12, color: _isDark ? Colors.white54 : Colors.grey.shade600),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => setState(() => _isGridView = !_isGridView),
            icon: Icon(_isGridView ? Icons.list_rounded : Icons.grid_view_rounded, size: 22),
            color: ApexColors.primary,
            tooltip: _isGridView ? 'Vue liste' : 'Vue grille',
          ),
          IconButton(
            onPressed: () => context.read<ThemeProvider>().toggleTheme(),
            icon: Icon(_isDark ? LucideIcons.sun : LucideIcons.moon, size: 22),
            color: ApexColors.primary,
          ),
          IconButton(
            onPressed: _openSettings,
            icon: const Icon(LucideIcons.settings, size: 22),
            color: ApexColors.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    final hasFilters = _selectedCategories.isNotEmpty || _searchQuery.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: _isDark ? const Color(0xFF1A1A2E) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _isDark ? Colors.white24 : Colors.grey.shade300),
        ),
        child: Row(
          children: [
            const SizedBox(width: 16),
            Icon(LucideIcons.search, size: 18, color: _isDark ? Colors.white54 : Colors.grey.shade500),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                onChanged: _onSearch,
                style: TextStyle(color: _isDark ? Colors.white : Colors.black, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Rechercher une question...',
                  hintStyle: TextStyle(color: _isDark ? Colors.white38 : Colors.grey.shade400, fontSize: 14),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            if (_searchCtrl.text.isNotEmpty)
              IconButton(
                onPressed: () { _searchCtrl.clear(); _onSearch(''); },
                icon: Icon(LucideIcons.x, size: 16, color: _isDark ? Colors.white54 : Colors.grey.shade500),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32),
              ),
            GestureDetector(
              onTap: _showFilterSheet,
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: hasFilters ? ApexColors.primary.withOpacity(0.1) : null,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: hasFilters ? ApexColors.primary : (_isDark ? Colors.white24 : Colors.grey.shade300),
                  ),
                ),
                child: Row(children: [
                  Icon(LucideIcons.slidersHorizontal, size: 15,
                    color: hasFilters ? ApexColors.primary : (_isDark ? Colors.white54 : Colors.grey.shade500)),
                  const SizedBox(width: 5),
                  Text(
                    hasFilters ? 'Actifs' : 'Filtres',
                    style: TextStyle(
                      fontSize: 12,
                      color: hasFilters ? ApexColors.primary : (_isDark ? Colors.white70 : Colors.grey.shade700),
                      fontWeight: hasFilters ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChips() {
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: kAllCats.length,
        itemBuilder: (_, i) {
          final cat = kAllCats[i];
          final sel = _selectedCategories.contains(cat);
          final color = kCatColors[cat] ?? ApexColors.primary;
          return GestureDetector(
            onTap: () {
              _toggleCategory(cat);
              HapticFeedback.selectionClick();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: sel ? color : (_isDark ? const Color(0xFF1A1A2E) : Colors.white),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: sel ? color : (_isDark ? Colors.white24 : Colors.grey.shade300)),
              ),
              child: Row(children: [
                Icon(kCatIcons[cat] ?? LucideIcons.tag, size: 13,
                  color: sel ? Colors.white : (_isDark ? Colors.white70 : Colors.grey.shade600)),
                const SizedBox(width: 5),
                Text(
                  cat,
                  style: TextStyle(
                    fontSize: 12,
                    color: sel ? Colors.white : (_isDark ? Colors.white70 : Colors.grey.shade700),
                    fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ]),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCard(QuestionModel q, int idx) {
    final isLiked = q.likedBy.contains(_user?.uid);
    final color = q.categories.isNotEmpty ? kCatColors[q.categories.first] ?? ApexColors.primary : ApexColors.primary;
    final firstImg = q.attachments.firstWhere((a) => a['type'] == 'image', orElse: () => const {});
    final hasImg = firstImg.isNotEmpty && (firstImg['url'] as String? ?? '').isNotEmpty;

    return Animate(
      effects: [
        FadeEffect(duration: 280.ms, delay: (idx * 40).clamp(0, 300).ms),
        SlideEffect(begin: const Offset(0, 0.04), end: Offset.zero, duration: 320.ms),
      ],
      child: GestureDetector(
        onTap: () => _toDetail(q),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: _isDark ? const Color(0xFF1A1A2E) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(_isDark ? 0.25 : 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: _isGridView
              ? _gridCard(q, color, isLiked, hasImg, firstImg)
              : _listCard(q, color, isLiked, hasImg, firstImg),
        ),
      ),
    );
  }

  Widget _gridCard(QuestionModel q, Color color, bool isLiked, bool hasImg, Map<String, dynamic> img) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color.withOpacity(0.85), color.withOpacity(0.4)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Row(children: [
            Avatar(userId: q.authorId, name: q.authorName, radius: 13),
            const SizedBox(width: 8),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(q.authorName, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                Text(q.timeAgo, style: const TextStyle(color: Colors.white70, fontSize: 9)),
              ]),
            ),
            if (q.isResolved)
              const Icon(LucideIcons.checkCircle, size: 14, color: Colors.white),
          ]),
        ),
        if (hasImg)
          CachedNetworkImage(
            imageUrl: img['url'] as String,
            height: 90, width: double.infinity, fit: BoxFit.cover,
            memCacheWidth: 360,
            placeholder: (_, __) => Container(height: 90, color: _isDark ? const Color(0xFF2A2A3E) : Colors.grey.shade200),
            errorWidget: (_, __, ___) => const SizedBox.shrink(),
          ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(q.title, maxLines: 2, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                color: _isDark ? Colors.white : Colors.black, height: 1.3)),
            const SizedBox(height: 5),
            Text(q.content, maxLines: 2, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: _isDark ? Colors.white60 : Colors.grey.shade600)),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _likeBtn(isLiked, q.likes),
                Row(children: [
                  Icon(LucideIcons.messageCircle, size: 13, color: _isDark ? Colors.white54 : Colors.grey.shade500),
                  const SizedBox(width: 3),
                  Text(_formatNum(q.answersCount), style: TextStyle(fontSize: 11, color: _isDark ? Colors.white70 : Colors.grey.shade600)),
                ]),
                Row(children: [
                  Icon(LucideIcons.eye, size: 13, color: _isDark ? Colors.white54 : Colors.grey.shade500),
                  const SizedBox(width: 3),
                  Text(_formatNum(q.views), style: TextStyle(fontSize: 11, color: _isDark ? Colors.white70 : Colors.grey.shade600)),
                ]),
              ],
            ),
          ]),
        ),
      ],
    );
  }

  Widget _listCard(QuestionModel q, Color color, bool isLiked, bool hasImg, Map<String, dynamic> imgMap) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Avatar(userId: q.authorId, name: q.authorName, radius: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(q.authorName,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                          color: _isDark ? Colors.white : Colors.black)),
                      Text(q.timeAgo,
                        style: TextStyle(fontSize: 11, color: _isDark ? Colors.white54 : Colors.grey.shade600)),
                    ]),
                  ),
                  if (q.isResolved)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text('Résolu',
                        style: TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.w600)),
                    ),
                ]),
                const SizedBox(height: 6),
                Text(q.title,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                    color: _isDark ? Colors.white : Colors.black, height: 1.3)),
                const SizedBox(height: 4),
                if (hasImg)
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(
                      child: Text(q.content, maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, color: _isDark ? Colors.white70 : Colors.grey.shade600)),
                    ),
                    const SizedBox(width: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CachedNetworkImage(
                        imageUrl: imgMap['url'] as String,
                        width: 52, height: 52, fit: BoxFit.cover,
                        memCacheWidth: 104,
                        placeholder: (_, __) => Container(width: 52, height: 52,
                          color: _isDark ? const Color(0xFF2A2A3E) : Colors.grey.shade200),
                        errorWidget: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),
                  ])
                else
                  Text(q.content, maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: _isDark ? Colors.white70 : Colors.grey.shade600)),
                const SizedBox(height: 10),
                Row(children: [
                  _likeBtn(isLiked, q.likes),
                  const SizedBox(width: 14),
                  Row(children: [
                    Icon(LucideIcons.messageCircle, size: 14, color: _isDark ? Colors.white54 : Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Text(_formatNum(q.answersCount),
                      style: TextStyle(fontSize: 12, color: _isDark ? Colors.white70 : Colors.grey.shade600)),
                  ]),
                  const Spacer(),
                  Row(children: [
                    Icon(LucideIcons.eye, size: 14, color: _isDark ? Colors.white54 : Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Text(_formatNum(q.views),
                      style: TextStyle(fontSize: 12, color: _isDark ? Colors.white70 : Colors.grey.shade600)),
                  ]),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _likeBtn(bool isLiked, int count) {
    return Row(children: [
      Icon(
        isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
        size: 16,
        color: isLiked ? Colors.red : (_isDark ? Colors.white54 : Colors.grey.shade500),
      ),
      const SizedBox(width: 4),
      Text(
        _formatNum(count),
        style: TextStyle(
          fontSize: 12,
          fontWeight: isLiked ? FontWeight.w600 : FontWeight.normal,
          color: isLiked ? Colors.red : (_isDark ? Colors.white70 : Colors.grey.shade600),
        ),
      ),
    ]);
  }

  Widget _buildShimmer() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
      itemCount: 5,
      itemBuilder: (_, __) => Shimmer.fromColors(
        baseColor: _isDark ? const Color(0xFF1E1E30) : Colors.grey.shade200,
        highlightColor: _isDark ? const Color(0xFF2A2A42) : Colors.grey.shade100,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          height: 110,
          decoration: BoxDecoration(
            color: _isDark ? const Color(0xFF1A1A2E) : Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(LucideIcons.wifiOff, size: 48, color: _isDark ? Colors.white54 : Colors.grey.shade400),
        const SizedBox(height: 16),
        Text('Erreur de connexion',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _isDark ? Colors.white : Colors.black)),
        const SizedBox(height: 8),
        Text('Vérifiez votre connexion internet',
          style: TextStyle(fontSize: 13, color: _isDark ? Colors.white54 : Colors.grey.shade600)),
      ]),
    );
  }

  Widget _buildEmpty() {
    final hasFilters = _selectedCategories.isNotEmpty || _searchQuery.isNotEmpty;
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 72, height: 72,
          decoration: BoxDecoration(gradient: ApexColors.primaryGradient, shape: BoxShape.circle),
          child: const Icon(LucideIcons.messageSquare, color: Colors.white, size: 28),
        ),
        const SizedBox(height: 16),
        Text(
          hasFilters ? 'Aucun résultat trouvé' : 'Aucune question',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _isDark ? Colors.white : Colors.black),
        ),
        const SizedBox(height: 8),
        Text(
          hasFilters
              ? 'Essayez des filtres différents'
              : 'Soyez le premier à poser une question !',
          style: TextStyle(fontSize: 13, color: _isDark ? Colors.white54 : Colors.grey.shade600),
        ),
      ]),
    );
  }

  void _toDetail(QuestionModel q) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => QuestionDetailPage(question: q)));
  }

  void _navigateToAsk() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AskQuestionPage(onQuestionCreated: () {})),
    );
  }

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

  void _onBottomTap(int index) {
    switch (index) {
      case 0: Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const UploadScreen())); break;
      case 1: break;
      case 2: Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen())); break;
      case 3: Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const ChatScreen())); break;
      case 4: Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const BiblioPage())); break;
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════════════════════
// FILTER SHEET
// ═══════════════════════════════════════════════════════════════════════════════════════════

class _FilterSheet extends StatefulWidget {
  final List<String> selectedCategories;
  final String sortBy;
  final Function(List<String>, String) onApply;
  final VoidCallback onReset;

  const _FilterSheet({
    required this.selectedCategories,
    required this.sortBy,
    required this.onApply,
    required this.onReset,
  });

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late List<String> _cats;
  late String _sort;

  @override
  void initState() {
    super.initState();
    _cats = List.from(widget.selectedCategories);
    _sort = widget.sortBy;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.72,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Filtres', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black)),
                TextButton(
                  onPressed: widget.onReset,
                  child: const Text('Tout effacer', style: TextStyle(color: ApexColors.primary)),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Trier par', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black)),
                  const SizedBox(height: 10),
                  Row(children: [
                    _sortChip('recent', 'Récents', LucideIcons.clock, isDark),
                    const SizedBox(width: 8),
                    _sortChip('votes', 'Populaires', LucideIcons.trendingUp, isDark),
                    const SizedBox(width: 8),
                    _sortChip('reponses', 'Sans réponse', LucideIcons.messageSquare, isDark),
                  ]),
                  const SizedBox(height: 22),
                  Text('Matières', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: kAllCats.map((c) {
                      final sel = _cats.contains(c);
                      final color = kCatColors[c] ?? ApexColors.primary;
                      return GestureDetector(
                        onTap: () { setState(() => sel ? _cats.remove(c) : _cats.add(c)); HapticFeedback.selectionClick(); },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: sel ? color : (isDark ? const Color(0xFF2A2A3E) : Colors.grey.shade100),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: sel ? color : (isDark ? Colors.white24 : Colors.grey.shade300)),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(kCatIcons[c] ?? LucideIcons.tag, size: 13,
                              color: sel ? Colors.white : (isDark ? Colors.white70 : Colors.grey.shade600)),
                            const SizedBox(width: 6),
                            Text(c, style: TextStyle(fontSize: 13,
                              color: sel ? Colors.white : (isDark ? Colors.white70 : Colors.grey.shade700),
                              fontWeight: sel ? FontWeight.w600 : FontWeight.normal)),
                          ]),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: ElevatedButton(
              onPressed: () => widget.onApply(_cats, _sort),
              style: ElevatedButton.styleFrom(
                backgroundColor: ApexColors.primary,
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('Appliquer', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sortChip(String value, String label, IconData icon, bool isDark) {
    final sel = _sort == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _sort = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: sel ? ApexColors.primary : (isDark ? const Color(0xFF2A2A3E) : Colors.grey.shade100),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: sel ? ApexColors.primary : (isDark ? Colors.white24 : Colors.grey.shade300)),
          ),
          child: Column(children: [
            Icon(icon, size: 17, color: sel ? Colors.white : (isDark ? Colors.white70 : Colors.grey.shade600)),
            const SizedBox(height: 4),
            Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 10,
              color: sel ? Colors.white : (isDark ? Colors.white70 : Colors.grey.shade600),
              fontWeight: sel ? FontWeight.w600 : FontWeight.normal)),
          ]),
        ),
      ),
    );
  }
}