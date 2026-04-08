// APEX — CHAT SCREEN · 


import 'dart:async';
import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mime/mime.dart';
import 'package:photo_view/photo_view.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../providers/theme_provider.dart';
import '../services/appwrite_service.dart';
import '../widgets/lucide_bottom_bar.dart';
import 'biblio_page.dart';
import 'entraide_page.dart';
import 'home_screen.dart';
import 'upload_screen.dart';

// ═══════════════════════════════════════════════════════════
// CONSTANTES
// ═══════════════════════════════════════════════════════════

const _kUserPalette = [
  Color(0xFF5865F2),
  Color(0xFF57F287),
  Color(0xFFFEE75C),
  Color(0xFFEB459E),
  Color(0xFFFD5C63),
  Color(0xFF3BA55C),
  Color(0xFF0EA5E9),
  Color(0xFF8B5CF6),
  Color(0xFFEC4899),
  Color(0xFF14B8A6),
];

const int _kMsgLimit = 50;

Color _userColor(String name) =>
    _kUserPalette[name.hashCode.abs() % _kUserPalette.length];

// ═══════════════════════════════════════════════════════════
// MODELS
// ═══════════════════════════════════════════════════════════

class _Channel {
  final String id, name;
  final IconData icon;
  final Color color;
  final String description;
  const _Channel({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.description,
  });
}

/// Message optimiste local affiché AVANT confirmation Firestore
class _OptimisticMsg {
  final String id;
  final String text;
  final String username;
  final String userId;
  final DateTime ts;

  _OptimisticMsg({
    required this.id,
    required this.text,
    required this.username,
    required this.userId,
    required this.ts,
  });
}

// ═══════════════════════════════════════════════════════════
// CHANNELS
// ═══════════════════════════════════════════════════════════

const List<_Channel> _kChannels = [
  _Channel(id: 'general',      name: 'Général',       icon: LucideIcons.globe,      color: Color(0xFF10B981), description: 'Discussions ouvertes'),
  _Channel(id: 'informatique', name: 'Informatique',  icon: LucideIcons.monitor,    color: Color(0xFF5865F2), description: 'Programmation, IA, Réseaux'),
  _Channel(id: 'maths',        name: 'Mathématiques', icon: LucideIcons.calculator, color: Color(0xFF3B82F6), description: 'Algèbre, Analyse, Géométrie'),
  _Channel(id: 'physique',     name: 'Physique',      icon: LucideIcons.zap,        color: Color(0xFFF59E0B), description: 'Mécanique, Thermodynamique'),
  _Channel(id: 'chimie',       name: 'Chimie',        icon: LucideIcons.beaker,     color: Color(0xFFEF4444), description: 'Organique, Inorganique'),
  _Channel(id: 'francais',     name: 'Français',      icon: LucideIcons.bookOpen,   color: Color(0xFF8B5CF6), description: 'Littérature, Grammaire'),
  _Channel(id: 'anglais',      name: 'Anglais',       icon: LucideIcons.languages,  color: Color(0xFF06B6D4), description: 'Expression, Rédaction'),
  _Channel(id: 'histoire',     name: 'Histoire',      icon: LucideIcons.scroll,     color: Color(0xFFD97706), description: 'Histoire mondiale & moderne'),
  _Channel(id: 'philo',        name: 'Philosophie',   icon: LucideIcons.brain,      color: Color(0xFFEC4899), description: 'Éthique, Épistémologie'),
  _Channel(id: 'svt',          name: 'SVT',           icon: LucideIcons.leaf,       color: Color(0xFF22C55E), description: 'Biologie, Écologie'),
];

// ═══════════════════════════════════════════════════════════
// BARRE DE SAISIE — StatefulWidget isolé
// Zéro rebuild du parent lors de la frappe
// ═══════════════════════════════════════════════════════════

class _InputBar extends StatefulWidget {
  final String channelName;
  final bool dark;
  final ValueChanged<String> onSend;
  final VoidCallback onPickFile;
  final String? replyText;
  final VoidCallback? onCancelReply;

  const _InputBar({
    super.key,
    required this.channelName,
    required this.dark,
    required this.onSend,
    required this.onPickFile,
    this.replyText,
    this.onCancelReply,
  });

  @override
  State<_InputBar> createState() => _InputBarState();
}

class _InputBarState extends State<_InputBar> {
  final TextEditingController _ctrl  = TextEditingController();
  final FocusNode             _focus = FocusNode();
  bool _focused  = false;
  bool _hasText  = false;

  Color get _input => widget.dark ? const Color(0xFF383A40) : const Color(0xFFE3E5E8);
  Color get _hint  => widget.dark ? const Color(0xFF949BA4) : const Color(0xFF80848E);
  Color get _text  => widget.dark ? const Color(0xFFDCDEE4) : const Color(0xFF2E3338);

  @override
  void initState() {
    super.initState();
    debugPrint('[INPUT_BAR] 🎹 initState()');
    _focus.addListener(() => setState(() => _focused = _focus.hasFocus));
    _ctrl.addListener(() {
      final has = _ctrl.text.trim().isNotEmpty;
      if (has != _hasText) setState(() => _hasText = has);
    });
  }

  @override
  void dispose() {
    debugPrint('[INPUT_BAR] 🗑️ dispose()');
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _send() {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    debugPrint('[INPUT_BAR] 📤 Envoi texte: "${text.substring(0, min(text.length, 40))}"');
    _ctrl.clear();
    setState(() => _hasText = false);
    widget.onSend(text);
    HapticFeedback.lightImpact();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: widget.dark ? const Color(0xFF313338) : Colors.white,
      padding: EdgeInsets.only(
        left: 12, right: 12, top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom +
            MediaQuery.of(context).padding.bottom + 8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Bannière réponse
          if (widget.replyText != null)
            Container(
              margin: const EdgeInsets.only(bottom: 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: widget.dark ? const Color(0xFF2B2D31) : const Color(0xFFF0F0F0),
                borderRadius: BorderRadius.circular(8),
                border: const Border(left: BorderSide(color: Color(0xFF5865F2), width: 3)),
              ),
              child: Row(children: [
                const Icon(LucideIcons.cornerUpRight, size: 13, color: Color(0xFF5865F2)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(widget.replyText!,
                    style: TextStyle(color: _hint, fontSize: 12, fontStyle: FontStyle.italic),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                GestureDetector(
                  onTap: widget.onCancelReply,
                  child: Icon(LucideIcons.x, size: 15, color: _hint),
                ),
              ]),
            ),
          // Champ Discord
          Container(
            constraints: const BoxConstraints(maxHeight: 140),
            decoration: BoxDecoration(
              color: _input, borderRadius: BorderRadius.circular(8)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                GestureDetector(
                  onTap: widget.onPickFile,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                    child: Icon(LucideIcons.plusCircle, size: 22,
                      color: _focused ? const Color(0xFF5865F2) : _hint),
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    focusNode: _focus,
                    maxLines: null, minLines: 1,
                    style: TextStyle(color: _text, fontSize: 15, height: 1.4),
                    textInputAction: TextInputAction.newline,
                    decoration: InputDecoration(
                      hintText: 'Message #${widget.channelName}',
                      hintStyle: TextStyle(color: _hint, fontSize: 15),
                      border: InputBorder.none, isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 11),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: _send,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 150),
                      child: _hasText
                          ? const Icon(Icons.send_rounded,
                              key: ValueKey('send'), size: 22, color: Color(0xFF5865F2))
                          : Icon(LucideIcons.smile,
                              key: const ValueKey('emoji'), size: 22, color: _hint),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// FILE PREVIEW BAR
// ═══════════════════════════════════════════════════════════

class _FilePreviewBar extends StatelessWidget {
  final XFile? file;
  final String? type;
  final Uint8List? bytes;
  final bool uploading;
  final double progress;
  final bool dark;
  final VoidCallback onCancel;
  final VoidCallback onSend;

  const _FilePreviewBar({
    required this.file, required this.type, required this.bytes,
    required this.uploading, required this.progress, required this.dark,
    required this.onCancel, required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    if (file == null) return const SizedBox.shrink();
    final bg     = dark ? const Color(0xFF2B2D31) : const Color(0xFFF2F3F5);
    final border = dark ? const Color(0xFF1E1F22) : const Color(0xFFD9DADE);
    final tp     = dark ? const Color(0xFFDCDEE4) : const Color(0xFF2E3338);
    final ts     = dark ? const Color(0xFF949BA4) : const Color(0xFF80848E);

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg, borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF5865F2).withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(type == 'image' ? LucideIcons.image : LucideIcons.file,
              color: const Color(0xFF5865F2), size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(file!.name,
            style: TextStyle(color: tp, fontWeight: FontWeight.w600, fontSize: 13),
            maxLines: 1, overflow: TextOverflow.ellipsis)),
          GestureDetector(onTap: onCancel,
            child: Icon(LucideIcons.x, size: 18, color: ts)),
        ]),
        if (type == 'image' && bytes != null) ...[
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.memory(bytes!, height: 150, width: double.infinity, fit: BoxFit.cover)),
        ],
        if (uploading) ...[
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: const Color(0xFF5865F2).withOpacity(0.12),
            valueColor: const AlwaysStoppedAnimation(Color(0xFF5865F2)),
            borderRadius: BorderRadius.circular(4), minHeight: 3,
          ),
        ],
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          TextButton(onPressed: uploading ? null : onCancel,
            child: const Text('Annuler', style: TextStyle(color: Color(0xFF949BA4)))),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: uploading ? null : onSend,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
              decoration: BoxDecoration(
                color: const Color(0xFF5865F2), borderRadius: BorderRadius.circular(6)),
              child: Text(uploading ? 'Envoi…' : 'Envoyer',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
            ),
          ),
        ]),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// CHAT SCREEN PRINCIPAL
// ═══════════════════════════════════════════════════════════

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {

  final User?           _me      = FirebaseAuth.instance.currentUser;
  final AppwriteService _appwrite = AppwriteService();
  final ImagePicker     _picker   = ImagePicker();
  final Uuid            _uuid     = const Uuid();
  final ScrollController _scroll  = ScrollController();

  // ─── Canal courant ───
  String _channelId   = 'general';
  String _channelName = 'Général';

  // ─── Stream DIRECT Firestore (miroir exact BiblioPage) ───
  // Re-créé à chaque changement de canal via _initStream()
  late Stream<List<Map<String, dynamic>>> _messagesStream;

  // ─── Optimistic messages (affichés avant confirmation Firestore) ───
  final Map<String, _OptimisticMsg> _optimistic = {};

  // ─── Sidebar ───
  bool _sidebarOpen = false;
  late AnimationController _sidebarCtrl;
  late Animation<Offset>   _sidebarAnim;

  // ─── FAB scroll ───
  bool _showFab = false;
  late AnimationController _fabCtrl;
  late Animation<double>   _fabAnim;

  // ─── Typing ───
  late AnimationController _typingCtrl;
  Timer? _typingTimer;

  // ─── File upload ───
  XFile?     _filePreview;
  String?    _fileType;
  Uint8List? _fileBytes;
  bool       _uploading       = false;
  double     _uploadProgress  = 0;

  // ─── Reply ───
  String? _replyMsgId;
  String? _replyText;

  // ─── Thème ───
  bool  get _dark         => context.watch<ThemeProvider>().isDarkMode;
  Color get _bg           => _dark ? const Color(0xFF313338) : const Color(0xFFFFFFFF);
  Color get _sidebar      => _dark ? const Color(0xFF2B2D31) : const Color(0xFFF2F3F5);
  Color get _sidebarActive=> _dark ? const Color(0xFF404249) : const Color(0xFFE0E1E5);
  Color get _tp           => _dark ? const Color(0xFFDCDEE4) : const Color(0xFF2E3338);
  Color get _ts           => _dark ? const Color(0xFF949BA4) : const Color(0xFF80848E);
  Color get _msgHover     => _dark ? const Color(0xFF2E3035) : const Color(0xFFF9F9F9);
  Color get _divider      => _dark ? const Color(0xFF3F4147) : const Color(0xFFE3E5E8);
  Color get _header       => _dark ? const Color(0xFF2B2D31) : const Color(0xFFFFFFFF);
  Color get _bubble       => _dark ? const Color(0xFF3B3D44) : const Color(0xFFF2F3F5);

  _Channel get _currentCh =>
      _kChannels.firstWhere((c) => c.id == _channelId, orElse: () => _kChannels[0]);

  // ═══════════════════════════════════════════════════════
  // INIT / DISPOSE
  // ═══════════════════════════════════════════════════════

  @override
  void initState() {
    super.initState();
    debugPrint('[CHAT_SCREEN] 📱 initState() - user: ${_me?.displayName}');
    WidgetsBinding.instance.addObserver(this);

    _sidebarCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 260));
    _sidebarAnim = Tween<Offset>(begin: const Offset(-1, 0), end: Offset.zero)
        .animate(CurvedAnimation(parent: _sidebarCtrl, curve: Curves.easeOutCubic));

    _fabCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 200));
    _fabAnim = CurvedAnimation(parent: _fabCtrl, curve: Curves.easeOut);

    _typingCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))..repeat();

    _scroll.addListener(_onScroll);

    // ✅ Stream DIRECT — identique au pattern BiblioPage
    _initStream();
    _updatePresence(true);
    debugPrint('[CHAT_SCREEN] ✅ initState terminé, stream prêt pour: $_channelId');
  }

  /// Crée le stream Firestore DIRECT pour le canal courant.
  /// Appelé à l'init ET à chaque changement de canal.
  void _initStream() {
    debugPrint('[CHAT_SCREEN] 🔄 _initStream() → canal=$_channelId limit=$_kMsgLimit');
    _messagesStream = FirebaseFirestore.instance
        .collection('chats')
        .doc(_channelId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(_kMsgLimit)
        .snapshots()
        .map((snap) {
          debugPrint('[CHAT_SCREEN] 📡 Firestore stream reçu: '
              '${snap.docs.length} msgs (canal=$_channelId)');
          return snap.docs
              .map((doc) => doc.data())
              .toList();
        });
  }

  @override
  void dispose() {
    debugPrint('[CHAT_SCREEN] 🗑️ dispose()');
    _typingTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _updatePresence(false);
    _sidebarCtrl.dispose();
    _fabCtrl.dispose();
    _typingCtrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    debugPrint('[CHAT_SCREEN] 🔄 Lifecycle: $state');
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _updatePresence(false);
    } else if (state == AppLifecycleState.resumed) {
      _updatePresence(true);
    }
  }

  void _onScroll() {
    final show = _scroll.position.pixels > 300;
    if (show != _showFab) {
      debugPrint('[CHAT_SCREEN] 🔼 FAB visibility: $show');
      setState(() => _showFab = show);
      show ? _fabCtrl.forward() : _fabCtrl.reverse();
    }
  }

  // ═══════════════════════════════════════════════════════
  // PRÉSENCE & TYPING
  // ═══════════════════════════════════════════════════════

  Future<void> _updatePresence(bool online) async {
    if (_me == null) return;
    debugPrint('[CHAT_SCREEN] 👁️ Présence → ${online ? "online" : "offline"}');
    try {
      await FirebaseFirestore.instance.collection('users').doc(_me!.uid).set({
        'uid': _me!.uid,
        'username': _me!.displayName ?? 'Utilisateur',
        'status': online ? 'online' : 'offline',
        'lastSeen': Timestamp.now(),
        'currentChannel': _channelName,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[CHAT_SCREEN] ❌ Erreur présence: $e');
    }
  }

  Future<void> _setTyping(bool typing) async {
    if (_me == null) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(_me!.uid).set(
        {'isTyping': typing, 'currentChannel': _channelName},
        SetOptions(merge: true),
      );
    } catch (e) {
      debugPrint('[CHAT_SCREEN] ❌ Erreur typing: $e');
    }
  }

  // ═══════════════════════════════════════════════════════
  // ENVOI MESSAGE — OPTIMISTE
  // ═══════════════════════════════════════════════════════

  Future<void> _sendText(String text) async {
    if (text.isEmpty || _me == null) return;
    if (text.length > 4000) {
      _snack('Message trop long (max 4000 car.)', error: true);
      return;
    }

    final msgId    = _uuid.v4();
    final username = _me!.displayName ?? 'Utilisateur';
    debugPrint('[CHAT_SCREEN] 📤 Envoi optimiste: id=$msgId canal=$_channelId');

    // 1. Ajout OPTIMISTE local → affichage instantané
    setState(() {
      _optimistic[msgId] = _OptimisticMsg(
        id: msgId, text: text,
        username: username, userId: _me!.uid,
        ts: DateTime.now(),
      );
    });
    debugPrint('[CHAT_SCREEN] ✅ Optimistes en attente: ${_optimistic.length}');

    // Scroll immédiat vers le bas
    if (_scroll.hasClients) {
      _scroll.animateTo(0,
        duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
    }

    // Reset reply
    final replyText = _replyText;
    if (_replyMsgId != null) {
      setState(() { _replyMsgId = null; _replyText = null; });
    }

    // 2. Persistance Firestore en arrière-plan
    try {
      await FirebaseFirestore.instance
          .collection('chats').doc(_channelId)
          .collection('messages').doc(msgId)
          .set({
        'messageId': msgId,
        'message': text,
        'type': 'text',
        'fileUrl': '',
        'fileName': '',
        'fileId': '',
        'fileMime': '',
        'userId': _me!.uid,
        'username': username,
        'timestamp': FieldValue.serverTimestamp(),
        if (replyText != null) 'replyTo': replyText,
      });
      debugPrint('[CHAT_SCREEN] ✅ Confirmé Firestore: $msgId');
      // Le stream va recevoir le message → on retire l'optimiste
      if (mounted) setState(() => _optimistic.remove(msgId));
    } catch (e) {
      debugPrint('[CHAT_SCREEN] ❌ Erreur Firestore: $e');
      _snack('Erreur d\'envoi', error: true);
      if (mounted) setState(() => _optimistic.remove(msgId));
    }
  }

  Future<void> _pickFile() async {
    debugPrint('[CHAT_SCREEN] 📎 Sélection fichier...');
    try {
      final file = await _picker.pickMedia(imageQuality: 85);
      if (file == null) { debugPrint('[CHAT_SCREEN] 📎 Annulé'); return; }
      final bytes = await file.readAsBytes();
      final mime  = lookupMimeType(file.path) ?? lookupMimeType('', headerBytes: bytes);
      if (mime?.startsWith('video/') == true) {
        _snack('Vidéos non supportées', error: true); return;
      }
      String type = 'file';
      if (mime?.startsWith('image/') == true) type = 'image';
      else if (mime == 'application/pdf') type = 'pdf';
      debugPrint('[CHAT_SCREEN] 📎 Fichier: ${file.name} type=$type');
      setState(() { _filePreview = file; _fileType = type; _fileBytes = bytes; });
    } catch (e) {
      debugPrint('[CHAT_SCREEN] ❌ Erreur sélection: $e');
      _snack('Erreur lors de la sélection', error: true);
    }
  }

  Future<void> _uploadAndSend() async {
    if (_filePreview == null || _me == null) return;
    debugPrint('[CHAT_SCREEN] ☁️ Upload: ${_filePreview!.name}');
    setState(() { _uploading = true; _uploadProgress = 0; });
    try {
      final file  = _filePreview!;
      final bytes = _fileBytes;
      final name  = file.name;
      final type  = _fileType ?? 'file';
      final mime  = lookupMimeType(file.path) ?? 'application/octet-stream';

      String fileId;
      if (kIsWeb) {
        if (bytes == null) throw Exception('Données manquantes');
        fileId = await _appwrite.uploadFileWeb(
          bytes: bytes, filename: name, userId: _me!.uid, mime: mime,
          onProgress: (p) { if (mounted) setState(() => _uploadProgress = p / 100); },
        );
      } else {
        String path = file.path;
        if (type == 'image') {
          final c = await FlutterImageCompress.compressAndGetFile(
            file.path, '${file.path}_c.jpg', quality: 80);
          if (c != null) path = c.path;
        }
        fileId = await _appwrite.uploadFile(
          filePath: path, userId: _me!.uid, filename: name, mime: mime,
          onProgress: (p) { if (mounted) setState(() => _uploadProgress = p / 100); },
        );
      }

      final fileUrl = _appwrite.getFileUrl(fileId);
      final msgId   = _uuid.v4();
      debugPrint('[CHAT_SCREEN] ☁️ Upload OK fileId=$fileId → Firestore $msgId');

      await FirebaseFirestore.instance
          .collection('chats').doc(_channelId)
          .collection('messages').doc(msgId)
          .set({
        'messageId': msgId, 'message': name,
        'type': type, 'fileUrl': fileUrl,
        'fileName': name, 'fileId': fileId, 'fileMime': mime,
        'userId': _me!.uid, 'username': _me!.displayName ?? 'Utilisateur',
        'timestamp': FieldValue.serverTimestamp(),
      });

      debugPrint('[CHAT_SCREEN] ✅ Fichier envoyé: $msgId');
      setState(() {
        _filePreview = null; _fileType = null;
        _fileBytes = null; _uploading = false;
      });
      if (_scroll.hasClients) {
        _scroll.animateTo(0,
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    } catch (e) {
      debugPrint('[CHAT_SCREEN] ❌ Erreur upload: $e');
      setState(() => _uploading = false);
      _snack('Erreur d\'upload : $e', error: true);
    }
  }

  Future<void> _deleteMsg(String msgId) async {
    debugPrint('[CHAT_SCREEN] 🗑️ Suppression: $msgId');
    try {
      await FirebaseFirestore.instance
          .collection('chats').doc(_channelId)
          .collection('messages').doc(msgId).delete();
      debugPrint('[CHAT_SCREEN] ✅ Supprimé: $msgId');
    } catch (e) {
      debugPrint('[CHAT_SCREEN] ❌ Erreur suppression: $e');
      _snack('Erreur de suppression', error: true);
    }
  }

  // ═══════════════════════════════════════════════════════
  // CHANGEMENT DE CANAL
  // ═══════════════════════════════════════════════════════

  void _switchChannel(_Channel ch) {
    if (ch.id == _channelId) {
      debugPrint('[CHAT_SCREEN] ⚡ Même canal ignoré: ${ch.id}');
      return;
    }
    debugPrint('[CHAT_SCREEN] 🔀 Switch canal: $_channelId → ${ch.id}');
    setState(() {
      _channelId   = ch.id;
      _channelName = ch.name;
      _sidebarOpen = false;
      _optimistic.clear();
      _initStream(); // ✅ Nouveau stream DIRECT pour ce canal
    });
    _sidebarCtrl.reverse();
    _updatePresence(true);
    debugPrint('[CHAT_SCREEN] ✅ Canal actif: $_channelId — stream recréé');
  }

  // ═══════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    debugPrint('[CHAT_SCREEN] 🎨 build() canal=$_channelId');
    final ch = _currentCh;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: _dark ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: _bg,
        body: Stack(children: [
          Column(children: [
            _buildHeader(ch),
            _buildTypingBanner(),
            Expanded(child: _buildMessageList()),
            _FilePreviewBar(
              file: _filePreview, type: _fileType, bytes: _fileBytes,
              uploading: _uploading, progress: _uploadProgress, dark: _dark,
              onCancel: () => setState(() {
                _filePreview = null; _fileType = null; _fileBytes = null;
              }),
              onSend: _uploadAndSend,
            ),
            _InputBar(
              key: ValueKey(_channelId),
              channelName: _channelName, dark: _dark,
              onSend: _sendText, onPickFile: _pickFile,
              replyText: _replyText,
              onCancelReply: () => setState(() { _replyMsgId = null; _replyText = null; }),
            ),
          ]),

          // FAB
          if (_showFab)
            Positioned(
              bottom: 90 + MediaQuery.of(context).padding.bottom, right: 16,
              child: ScaleTransition(
                scale: _fabAnim,
                child: GestureDetector(
                  onTap: () => _scroll.animateTo(0,
                    duration: const Duration(milliseconds: 300), curve: Curves.easeOut),
                  child: Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: _dark ? const Color(0xFF2B2D31) : Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: _divider),
                      boxShadow: [BoxShadow(
                        color: Colors.black.withOpacity(0.2), blurRadius: 8)],
                    ),
                    child: Icon(Icons.keyboard_arrow_down_rounded, color: _ts, size: 22),
                  ),
                ),
              ),
            ),

          // Overlay sidebar
          if (_sidebarOpen)
            GestureDetector(
              onTap: () { setState(() => _sidebarOpen = false); _sidebarCtrl.reverse(); },
              child: Container(color: Colors.black54),
            ),

          // Sidebar
          SlideTransition(position: _sidebarAnim, child: _buildSidebar()),
        ]),
        bottomNavigationBar: LucideBottomBar(selectedIndex: 3, onTap: _nav),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // HEADER
  // ═══════════════════════════════════════════════════════

  Widget _buildHeader(_Channel ch) {
    return Container(
      height: MediaQuery.of(context).padding.top + 52,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top, left: 12, right: 12),
      decoration: BoxDecoration(
        color: _header,
        border: Border(bottom: BorderSide(color: _divider)),
        boxShadow: [BoxShadow(
          color: Colors.black.withOpacity(0.08), blurRadius: 4, offset: const Offset(0, 1))],
      ),
      child: Row(children: [
        GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            setState(() => _sidebarOpen = true);
            _sidebarCtrl.forward();
          },
          child: Icon(LucideIcons.menu, size: 22, color: _ts),
        ),
        const SizedBox(width: 12),
        Icon(LucideIcons.hash, size: 20, color: _ts),
        const SizedBox(width: 6),
        Text(_channelName,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _tp)),
        const SizedBox(width: 8),
        Expanded(child: Text(ch.description,
          style: TextStyle(fontSize: 12, color: _ts), overflow: TextOverflow.ellipsis)),
        // Utilisateurs en ligne — stream direct
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('users')
              .where('currentChannel', isEqualTo: _channelName)
              .where('status', isEqualTo: 'online')
              .snapshots(),
          builder: (_, snap) {
            final n = snap.data?.docs.length ?? 0;
            debugPrint('[CHAT_SCREEN] 👥 En ligne sur $_channelName: $n');
            return Row(children: [
              Container(width: 8, height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFF23A55A), shape: BoxShape.circle)),
              const SizedBox(width: 4),
              Text('$n', style: TextStyle(
                fontSize: 13, color: _ts, fontWeight: FontWeight.w600)),
            ]);
          },
        ),
      ]),
    );
  }

  // ═══════════════════════════════════════════════════════
  // BANDEAU TYPING
  // ═══════════════════════════════════════════════════════

  Widget _buildTypingBanner() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users')
          .where('currentChannel', isEqualTo: _channelName)
          .where('isTyping', isEqualTo: true)
          .snapshots(),
      builder: (_, snap) {
        if (!snap.hasData) return const SizedBox(height: 2);
        final others = snap.data!.docs
            .where((d) => (d.data() as Map)['uid'] != _me?.uid)
            .map((d) => (d.data() as Map)['username'] ?? 'Quelqu\'un')
            .toList();
        if (others.isEmpty) return const SizedBox(height: 2);

        final text = others.length == 1
            ? '${others[0]} est en train d\'écrire…'
            : others.length == 2
                ? '${others[0]} et ${others[1]} écrivent…'
                : '${others[0]} +${others.length - 1} écrivent…';

        debugPrint('[CHAT_SCREEN] ✍️ Typing: $text');

        return Container(
          height: 24, padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            AnimatedBuilder(
              animation: _typingCtrl,
              builder: (_, __) => Row(
                children: List.generate(3, (i) {
                  final offset = sin((_typingCtrl.value * 2 * pi) + i * 1.1) * 2.5;
                  return Container(
                    width: 4, height: 4, margin: const EdgeInsets.only(right: 3),
                    decoration: BoxDecoration(color: _ts, shape: BoxShape.circle),
                    transform: Matrix4.translationValues(0, -offset, 0),
                  );
                }),
              ),
            ),
            const SizedBox(width: 6),
            Text(text, style: TextStyle(color: _ts, fontSize: 12)),
          ]),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════
  // LISTE DE MESSAGES — StreamBuilder DIRECT (miroir BiblioPage)
  // ═══════════════════════════════════════════════════════

  Widget _buildMessageList() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      // ValueKey force un rebuild propre à chaque changement de canal
      key: ValueKey('stream_$_channelId'),
      stream: _messagesStream,
      builder: (_, snap) {
        debugPrint('[CHAT_SCREEN] 📡 StreamBuilder state=${snap.connectionState} '
            'hasData=${snap.hasData} error=${snap.error}');

        // ── Chargement initial ──
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          debugPrint('[CHAT_SCREEN] ⏳ Shimmer affiché');
          return _buildShimmer();
        }

        // ── Erreur ──
        if (snap.hasError) {
          debugPrint('[CHAT_SCREEN] ❌ Erreur stream: ${snap.error}');
          return _buildError();
        }

        final remoteMessages = snap.data ?? [];
        debugPrint('[CHAT_SCREEN] 📦 Messages Firestore: ${remoteMessages.length}');

        // ── Fusion Firestore + Optimistic ──
        // On retire les optimistes déjà confirmés par Firestore
        final firestoreIds = remoteMessages
            .map((m) => m['messageId'] as String? ?? '')
            .toSet();

        // Nettoyage silencieux des confirmés
        for (final id in firestoreIds.toList()) {
          if (_optimistic.containsKey(id)) {
            debugPrint('[CHAT_SCREEN] 🧹 Optimiste confirmé retiré: $id');
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _optimistic.remove(id));
            });
          }
        }

        final pendingOptimistic = _optimistic.values
            .where((o) => !firestoreIds.contains(o.id))
            .toList()
          ..sort((a, b) => b.ts.compareTo(a.ts));

        debugPrint('[CHAT_SCREEN] ⚡ Optimistes en attente: ${pendingOptimistic.length}');

        // Liste finale (reverse:true → optimistes en haut visuellement)
        final allMessages = [
          ...pendingOptimistic.map((o) => {
            'messageId': o.id,
            'message': o.text,
            'username': o.username,
            'userId': o.userId,
            'timestamp': o.ts,     // DateTime
            'type': 'text',
            'fileUrl': '',
            'fileName': '',
            'replyTo': null,
            '_isOptimistic': true,
          }),
          ...remoteMessages,
        ];

        debugPrint('[CHAT_SCREEN] 📊 Liste finale: ${allMessages.length} messages');

        if (allMessages.isEmpty) return _buildEmpty();

        return ListView.builder(
          controller: _scroll,
          reverse: true,
          padding: const EdgeInsets.only(top: 8, bottom: 8),
          itemCount: allMessages.length,
          itemBuilder: (_, i) {
            final msg = allMessages[i];

            // Optimiste
            if (msg['_isOptimistic'] == true) {
              return _buildOptimisticBubble(msg);
            }

            // Firestore
            final isMe  = msg['userId'] == _me?.uid;
            final docId = msg['messageId'] as String? ?? '';

            // Groupement Discord (< 7 min, même auteur)
            bool showHeader = true;
            if (i < allMessages.length - 1) {
              final next = allMessages[i + 1];
              final tsA  = _toDateTime(msg['timestamp']);
              final tsB  = _toDateTime(next['timestamp']);
              if (next['userId'] == msg['userId'] &&
                  tsA.difference(tsB).inMinutes.abs() < 7) {
                showHeader = false;
              }
            }

            return _buildDiscordBubble(msg, isMe, showHeader, docId);
          },
        );
      },
    );
  }

  /// Convertit Timestamp Firestore OU DateTime local → DateTime.
  DateTime _toDateTime(dynamic ts) {
    if (ts is Timestamp) return ts.toDate();
    if (ts is DateTime)  return ts;
    return DateTime.now();
  }

  // ═══════════════════════════════════════════════════════
  // BUBBLES
  // ═══════════════════════════════════════════════════════

  Widget _buildDiscordBubble(
    Map<String, dynamic> data, bool isMe, bool showHeader, String docId) {
    final username = data['username'] as String? ?? 'Utilisateur';
    final message  = data['message']  as String? ?? '';
    final type     = data['type']     as String? ?? 'text';
    final fileUrl  = data['fileUrl']  as String? ?? '';
    final fileName = data['fileName'] as String? ?? '';
    final replyTo  = data['replyTo']  as String?;
    final ts       = _toDateTime(data['timestamp']);
    final color    = _userColor(username);

    return _HoverableBubble(
      dark: _dark, hoverColor: _msgHover,
      onLongPress: () => _showOptions(data, docId),
      child: Padding(
        padding: EdgeInsets.only(
          left: 16, right: 16, top: showHeader ? 16 : 2, bottom: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 40,
              child: showHeader
                  ? GestureDetector(
                      onTap: () => _showUserInfo(username, color),
                      child: _DiscordAvatar(username: username, color: color, size: 40))
                  : Align(
                      alignment: Alignment.topRight,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          '${ts.hour.toString().padLeft(2,'0')}:${ts.minute.toString().padLeft(2,'0')}',
                          style: TextStyle(fontSize: 10, color: _ts)),
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showHeader)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(children: [
                      Text(username, style: TextStyle(
                        color: color, fontWeight: FontWeight.w700, fontSize: 15)),
                      const SizedBox(width: 8),
                      Text(_formatTime(ts), style: TextStyle(color: _ts, fontSize: 12)),
                      if (isMe) ...[
                        const SizedBox(width: 4),
                        Icon(LucideIcons.checkCheck, size: 12, color: _ts),
                      ],
                    ]),
                  ),
                if (replyTo != null) _buildReplyRef(replyTo),
                _buildContent(type, message, fileUrl, fileName, data),
              ],
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildOptimisticBubble(Map<String, dynamic> data) {
    final username = data['username'] as String? ?? 'Utilisateur';
    final text     = data['message']  as String? ?? '';
    final ts       = _toDateTime(data['timestamp']);
    final color    = _userColor(username);

    debugPrint('[CHAT_SCREEN] 🔵 Rendu optimiste: '
        '"${text.substring(0, min(text.length, 30))}"');

    return Opacity(
      opacity: 0.7,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DiscordAvatar(username: username, color: color, size: 40),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(username, style: TextStyle(
                    color: color, fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(width: 8),
                  Text(_formatTime(ts), style: TextStyle(color: _ts, fontSize: 12)),
                  const SizedBox(width: 6),
                  SizedBox(width: 12, height: 12,
                    child: CircularProgressIndicator(strokeWidth: 1.5, color: _ts)),
                ]),
                const SizedBox(height: 2),
                Text(text, style: TextStyle(
                  color: _tp.withOpacity(0.7), fontSize: 15, height: 1.4)),
              ],
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildReplyRef(String text) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _dark ? const Color(0xFF2B2D31) : const Color(0xFFEEEFF1),
        borderRadius: BorderRadius.circular(4),
        border: const Border(left: BorderSide(color: Color(0xFF5865F2), width: 3)),
      ),
      child: Text(text, style: TextStyle(
        color: _ts, fontSize: 12, fontStyle: FontStyle.italic),
        maxLines: 2, overflow: TextOverflow.ellipsis),
    );
  }

  Widget _buildContent(String type, String message, String fileUrl,
      String fileName, Map<String, dynamic> data) {
    switch (type) {
      case 'image':
        final url = _viewUrl(data);
        if (url.isEmpty) return _noImage();
        return GestureDetector(
          onTap: () => _openFullscreen(url, fileName),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CachedNetworkImage(
              imageUrl: url, width: 320, fit: BoxFit.fitWidth,
              placeholder: (_, __) => Container(
                width: 320, height: 200, color: _bubble,
                child: const Center(child: CircularProgressIndicator(
                  strokeWidth: 2, color: Color(0xFF5865F2)))),
              errorWidget: (_, __, ___) => _noImage(),
            ),
          ),
        );
      case 'pdf':
      case 'file':
        return GestureDetector(
          onTap: () => _openUrl(fileUrl),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _bubble, borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _divider),
            ),
            child: Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF5865F2).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8)),
                child: Icon(
                  type == 'pdf' ? LucideIcons.fileText : LucideIcons.file,
                  color: const Color(0xFF5865F2), size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(fileName, style: TextStyle(
                    color: _tp, fontWeight: FontWeight.w600, fontSize: 13),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text('Appuyer pour ouvrir',
                    style: TextStyle(color: _ts, fontSize: 11)),
                ])),
              Icon(Icons.download_rounded, color: _ts, size: 18),
            ]),
          ),
        );
      default:
        return SelectableText(message,
          style: TextStyle(color: _tp, fontSize: 15, height: 1.45));
    }
  }

  Widget _noImage() => Container(
    width: 320, height: 180,
    decoration: BoxDecoration(color: _bubble, borderRadius: BorderRadius.circular(8)),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(LucideIcons.imageOff, color: _ts, size: 28),
      const SizedBox(height: 6),
      Text('Image indisponible', style: TextStyle(color: _ts, fontSize: 12)),
    ]),
  );

  String _viewUrl(Map<String, dynamic> data) {
    final url = (data['fileUrl'] as String?) ?? '';
    if (url.isEmpty) return '';
    if (url.contains('/preview')) {
      return url
          .replaceAll('/preview', '/view')
          .replaceAll(RegExp(r'[?&]width=\d+'), '')
          .replaceAll(RegExp(r'[?&]height=\d+'), '')
          .replaceAll(RegExp(r'\?&'), '?')
          .replaceAll(RegExp(r'&&'), '&');
    }
    return url;
  }

  void _openFullscreen(String url, String name) {
    Navigator.push(context, PageRouteBuilder(
      pageBuilder: (_, __, ___) => Scaffold(
        backgroundColor: Colors.black,
        body: Stack(children: [
          PhotoView(
            imageProvider: NetworkImage(url),
            backgroundDecoration: const BoxDecoration(color: Colors.black),
            minScale: PhotoViewComputedScale.contained,
            maxScale: PhotoViewComputedScale.covered * 4,
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 10, right: 12,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 38, height: 38,
                decoration: const BoxDecoration(
                  color: Colors.black54, shape: BoxShape.circle),
                child: const Icon(Icons.close, color: Colors.white, size: 20)),
            ),
          ),
          Positioned(
            bottom: 24, left: 20, right: 20,
            child: Text(name,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
              textAlign: TextAlign.center,
              maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
        ]),
      ),
      transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
    ));
  }

  Future<void> _openUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) { debugPrint('[CHAT_SCREEN] ❌ Open URL: $e'); }
  }

  // ═══════════════════════════════════════════════════════
  // OPTIONS (long press)
  // ═══════════════════════════════════════════════════════

  void _showOptions(Map<String, dynamic> data, String msgId) {
    HapticFeedback.mediumImpact();
    debugPrint('[CHAT_SCREEN] 💬 Options message: $msgId');
    final isMe    = data['userId'] == _me?.uid;
    final msg     = data['message'] as String? ?? '';
    final fileUrl = data['fileUrl'] as String? ?? '';
    const emojis  = ['👍', '❤️', '😂', '😮', '😢', '🔥'];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: _dark ? const Color(0xFF2B2D31) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          border: Border.all(color: _divider),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 36, height: 4, margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: _divider, borderRadius: BorderRadius.circular(2))),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: emojis.map((e) => GestureDetector(
              onTap: () { Navigator.pop(context); HapticFeedback.lightImpact(); },
              child: Container(
                width: 46, height: 46,
                decoration: BoxDecoration(
                  color: _dark ? const Color(0xFF383A40) : const Color(0xFFF2F3F5),
                  borderRadius: BorderRadius.circular(12)),
                child: Center(child: Text(e,
                  style: const TextStyle(fontSize: 22)))),
            )).toList(),
          ),
          const SizedBox(height: 12),
          Divider(color: _divider, height: 1),
          const SizedBox(height: 4),
          if (msg.isNotEmpty) ...[
            _optTile(LucideIcons.cornerUpRight, 'Répondre', () {
              Navigator.pop(context);
              setState(() { _replyMsgId = msgId; _replyText = msg; });
            }),
            _optTile(Icons.copy_rounded, 'Copier le texte', () {
              Navigator.pop(context);
              Clipboard.setData(ClipboardData(text: msg));
              _snack('Copié ✓');
            }),
          ],
          if (fileUrl.isNotEmpty)
            _optTile(Icons.download_rounded, 'Télécharger', () {
              Navigator.pop(context); _openUrl(fileUrl);
            }),
          _optTile(Icons.share_rounded, 'Partager', () {
            Navigator.pop(context);
            Share.share(msg.isNotEmpty ? msg : fileUrl);
          }),
          if (isMe)
            _optTile(Icons.delete_rounded, 'Supprimer le message', () {
              Navigator.pop(context); _deleteMsg(msgId);
            }, color: const Color(0xFFED4245)),
        ]),
      ),
    );
  }

  Widget _optTile(IconData icon, String label, VoidCallback fn, {Color? color}) {
    return ListTile(
      leading: Icon(icon, color: color ?? const Color(0xFF5865F2), size: 20),
      title: Text(label, style: TextStyle(
        color: color ?? _tp, fontSize: 15, fontWeight: FontWeight.w500)),
      onTap: fn, dense: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }

  void _showUserInfo(String name, Color color) {
    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _dark ? const Color(0xFF2B2D31) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _divider),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _DiscordAvatar(username: name, color: color, size: 64),
          const SizedBox(height: 12),
          Text(name, style: TextStyle(
            color: _tp, fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF23A55A).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12)),
            child: const Text('En ligne', style: TextStyle(
              color: Color(0xFF23A55A), fontSize: 12, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 16),
        ]),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // SIDEBAR
  // ═══════════════════════════════════════════════════════

  Widget _buildSidebar() {
    return Container(
      width: 280, height: double.infinity, color: _sidebar,
      child: Column(children: [
        Container(
          height: MediaQuery.of(context).padding.top + 52,
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top, left: 16, right: 16),
          decoration: BoxDecoration(
            color: _dark ? const Color(0xFF2B2D31) : const Color(0xFFE3E5E8),
            border: Border(bottom: BorderSide(color: _divider)),
            boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 1))],
          ),
          child: Row(children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF5865F2), Color(0xFF4752C4)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(10)),
              child: const Center(child: Text('A', style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18))),
            ),
            const SizedBox(width: 10),
            Text('APEX', style: TextStyle(
              color: _tp, fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
            const Spacer(),
            Icon(LucideIcons.chevronDown, size: 16, color: _ts),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 16, 12, 6),
          child: Row(children: [
            Icon(LucideIcons.chevronDown, size: 12, color: _ts),
            const SizedBox(width: 4),
            Text('CANAUX TEXTUELS', style: TextStyle(
              color: _ts, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
            const Spacer(),
            Icon(LucideIcons.plus, size: 14, color: _ts),
          ]),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            itemCount: _kChannels.length,
            itemBuilder: (_, i) {
              final ch     = _kChannels[i];
              final active = ch.id == _channelId;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  debugPrint('[CHAT_SCREEN] 🔀 Tap canal sidebar: ${ch.id}');
                  _switchChannel(ch);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.symmetric(vertical: 1),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  decoration: BoxDecoration(
                    color: active ? _sidebarActive : Colors.transparent,
                    borderRadius: BorderRadius.circular(4)),
                  child: Row(children: [
                    Icon(LucideIcons.hash, size: 18, color: active ? _tp : _ts),
                    const SizedBox(width: 6),
                    Expanded(child: Text(ch.name, style: TextStyle(
                      color: active ? _tp : _ts, fontSize: 15,
                      fontWeight: active ? FontWeight.w600 : FontWeight.w400))),
                  ]),
                ),
              );
            },
          ),
        ),
        // Pied profil
        Container(
          padding: EdgeInsets.only(
            left: 8, right: 8, top: 8,
            bottom: 8 + MediaQuery.of(context).padding.bottom),
          decoration: BoxDecoration(
            color: _dark ? const Color(0xFF232428) : const Color(0xFFE3E5E8),
            border: Border(top: BorderSide(color: _divider))),
          child: Row(children: [
            Stack(children: [
              _DiscordAvatar(
                username: _me?.displayName ?? 'U',
                color: _userColor(_me?.displayName ?? 'U'),
                size: 32),
              Positioned(bottom: 0, right: 0,
                child: Container(
                  width: 10, height: 10,
                  decoration: BoxDecoration(
                    color: const Color(0xFF23A55A), shape: BoxShape.circle,
                    border: Border.all(
                      color: _dark ? const Color(0xFF232428) : const Color(0xFFE3E5E8),
                      width: 2)))),
            ]),
            const SizedBox(width: 8),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_me?.displayName ?? 'Utilisateur',
                style: TextStyle(color: _tp, fontSize: 13, fontWeight: FontWeight.w600),
                maxLines: 1, overflow: TextOverflow.ellipsis),
              const Text('En ligne',
                style: TextStyle(color: Color(0xFF23A55A), fontSize: 11)),
            ])),
            Icon(LucideIcons.settings, size: 18, color: _ts),
          ]),
        ),
      ]),
    );
  }

  // ═══════════════════════════════════════════════════════
  // ÉTATS VIDE / SHIMMER / ERREUR
  // ═══════════════════════════════════════════════════════

  Widget _buildShimmer() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      reverse: true,
      itemCount: 8,
      itemBuilder: (_, i) => Padding(
        padding: EdgeInsets.only(top: i % 3 == 0 ? 16 : 2, bottom: 2),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (i % 3 == 0)
            Container(
              width: 40, height: 40, margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: _dark ? const Color(0xFF3B3D44) : const Color(0xFFE3E5E8),
                shape: BoxShape.circle))
          else
            const SizedBox(width: 52),
          Expanded(child: Container(
            height: i % 3 == 0 ? 44 : 20,
            margin: const EdgeInsets.only(right: 60),
            decoration: BoxDecoration(
              color: _dark ? const Color(0xFF3B3D44) : const Color(0xFFE3E5E8),
              borderRadius: BorderRadius.circular(4)))),
        ]),
      ),
    );
  }

  Widget _buildError() => Center(child: Column(
    mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(LucideIcons.wifiOff, size: 40, color: _ts),
      const SizedBox(height: 12),
      Text('Erreur de connexion',
        style: TextStyle(color: _tp, fontWeight: FontWeight.w600)),
      const SizedBox(height: 4),
      Text('Vérifiez votre connexion internet',
        style: TextStyle(color: _ts, fontSize: 13)),
    ]));

  Widget _buildEmpty() {
    final ch = _currentCh;
    return Center(child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(LucideIcons.hash, size: 48, color: _ts),
        const SizedBox(height: 16),
        Text('Bienvenue dans #${ch.name}',
          style: TextStyle(color: _tp, fontSize: 20, fontWeight: FontWeight.w800),
          textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text('C\'est le début de #${ch.name}. ${ch.description}.',
          style: TextStyle(color: _ts, fontSize: 14), textAlign: TextAlign.center),
      ]),
    ));
  }

  // ═══════════════════════════════════════════════════════
  // UTILS
  // ═══════════════════════════════════════════════════════

  String _formatTime(DateTime d) {
    final now = DateTime.now();
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    if (d.day == now.day && d.month == now.month && d.year == now.year) {
      return "Aujourd'hui à $h:$m";
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (d.day == yesterday.day) return "Hier à $h:$m";
    return '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year} $h:$m';
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: Colors.white)),
      backgroundColor: error ? const Color(0xFFED4245) : const Color(0xFF23A55A),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ));
  }

  void _nav(int i) {
    switch (i) {
      case 0: Navigator.pushReplacement(context, _fade(const UploadScreen())); break;
      case 1: Navigator.pushReplacement(context, _fade(const EntraidePage())); break;
      case 2: Navigator.pushReplacement(context, _fade(const HomeScreen())); break;
      case 3: break;
      case 4: Navigator.pushReplacement(context, _fade(const BiblioPage())); break;
    }
  }

  PageRoute _fade(Widget w) => PageRouteBuilder(
    pageBuilder: (_, __, ___) => w,
    transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
    transitionDuration: const Duration(milliseconds: 200),
  );
}

// ═══════════════════════════════════════════════════════════
// DISCORD AVATAR
// ═══════════════════════════════════════════════════════════

class _DiscordAvatar extends StatelessWidget {
  final String username;
  final Color color;
  final double size;

  const _DiscordAvatar({
    required this.username, required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    final initial = username.isNotEmpty ? username[0].toUpperCase() : '?';
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Center(child: Text(initial, style: TextStyle(
        color: Colors.white, fontWeight: FontWeight.w700, fontSize: size * 0.42))),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// HOVERABLE BUBBLE
// ═══════════════════════════════════════════════════════════

class _HoverableBubble extends StatefulWidget {
  final Widget child;
  final Color hoverColor;
  final bool dark;
  final GestureLongPressCallback? onLongPress;

  const _HoverableBubble({
    required this.child, required this.hoverColor,
    required this.dark, this.onLongPress,
  });

  @override
  State<_HoverableBubble> createState() => _HoverableBubbleState();
}

class _HoverableBubbleState extends State<_HoverableBubble> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onLongPress: widget.onLongPress,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          color: _hovered ? widget.hoverColor : Colors.transparent,
          child: widget.child,
        ),
      ),
    );
  }
}