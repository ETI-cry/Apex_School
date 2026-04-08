
// GLOBAL DATA CACHE 


import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../screens/biblio_page.dart';
import '../screens/entraide_page.dart';

/// Cache global pour toutes les données de l'app
class _GlobalDataCache {
  static final _GlobalDataCache _instance = _GlobalDataCache._internal();
  factory _GlobalDataCache() => _instance;
  _GlobalDataCache._internal() {
    debugPrint('[GLOBAL_CACHE] 🏗️  Singleton instancié');
  }

  // ═══════════════════════════════════════════════════════════════════════════════
  // ÉTAT DU CACHE
  // ═══════════════════════════════════════════════════════════════════════════════

  final List<DocumentModel> _biblioDocs = [];
  final List<QuestionModel> _questions = [];
  final Map<String, List<Map<String, dynamic>>> _chatMessages = {};

  bool _biblioReady = false;
  bool _questionsReady = false;
  bool _chatReady = false;

  bool get biblioReady => _biblioReady;
  bool get questionsReady => _questionsReady;
  bool get chatReady => _chatReady;

  bool get allReady => _biblioReady && _questionsReady && _chatReady;

  // Listeners pour notifier les pages quand les données sont prêtes
  final _listeners = <VoidCallback>[];
  void addListener(VoidCallback cb) => _listeners.add(cb);
  void removeListener(VoidCallback cb) => _listeners.remove(cb);
  void _notify() {
    debugPrint('[GLOBAL_CACHE] 🔔 Notification aux listeners (allReady: $allReady)');
    for (final cb in List<VoidCallback>.from(_listeners)) {
      try {
        cb();
      } catch (e) {
        debugPrint('[GLOBAL_CACHE] ❌ Erreur listener: $e');
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════════
  // GETTERS (accès direct aux données en cache)
  // ═══════════════════════════════════════════════════════════════════════════════

  List<DocumentModel> get biblioDocs => List.unmodifiable(_biblioDocs);
  List<QuestionModel> get questions => List.unmodifiable(_questions);
  List<Map<String, dynamic>> getMessagesForChannel(String channelId) =>
      List.unmodifiable(_chatMessages[channelId] ?? []);

  /// Accès complet à tous les messages par canal
  Map<String, List<Map<String, dynamic>>> get chatMessages => Map.unmodifiable(_chatMessages);

  /// Vérifie si un canal spécifique est chargé dans le cache
  bool isChatChannelReady(String channelId) => _chatMessages.containsKey(channelId);

  // ═══════════════════════════════════════════════════════════════════════════════
  // PRÉ-CHARGEMENT — Appelé une seule fois après login
  // ═══════════════════════════════════════════════════════════════════════════════

  /// Pré-charge TOUTES les données en arrière-plan
  Future<void> preloadAll() async {
    debugPrint('[GLOBAL_CACHE] 🚀 Début pré-chargement global');

    // Lance tous les chargements en parallèle
    await Future.wait([
      _preloadBiblio(),
      _preloadQuestions(),
      _preloadChatMessages(),
    ]);

    debugPrint('[GLOBAL_CACHE] ✅ Pré-chargement terminé');
    _notify();
  }

  /// Pré-charge bibliothèque (derniers 50 documents)
  Future<void> _preloadBiblio() async {
    debugPrint('[GLOBAL_CACHE] 📚 Pré-chargement biblio...');
    try {
      final snap = await FirebaseFirestore.instance
          .collection('documents')
          .where('isPublic', isEqualTo: true)
          .orderBy('uploadDate', descending: true)
          .limit(50) // On charge un peu plus pour le scroll initial
          .get();

      _biblioDocs
        ..clear()
        ..addAll(snap.docs.map(DocumentModel.fromFirestore));

      _biblioReady = true;
      debugPrint('[GLOBAL_CACHE] ✅ Biblio chargée: ${_biblioDocs.length} docs');
    } catch (e, stack) {
      debugPrint('[GLOBAL_CACHE] ❌ Erreur pré-chargement biblio: $e');
      debugPrint('[GLOBAL_CACHE] Stack: $stack');
      _biblioReady = true; // Marquer comme prêt même en erreur pour éviter blocage
    }
  }

  /// Pré-charge questions d'entraide (dernières 50)
  Future<void> _preloadQuestions() async {
    debugPrint('[GLOBAL_CACHE] 💬 Pré-chargement questions...');
    try {
      // On charge les questions triées par date (les plus récentes)
      final snap = await FirebaseFirestore.instance
          .collection('entraide_questions')
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();

      _questions
        ..clear()
        ..addAll(snap.docs.map(QuestionModel.fromDoc));

      _questionsReady = true;
      debugPrint('[GLOBAL_CACHE] ✅ Questions chargées: ${_questions.length} questions');
    } catch (e, stack) {
      debugPrint('[GLOBAL_CACHE] ❌ Erreur pré-chargement questions: $e');
      debugPrint('[GLOBAL_CACHE] Stack: $stack');
      _questionsReady = true;
    }
  }

  /// Pré-charge messages des canaux les plus actifs
  Future<void> _preloadChatMessages() async {
    debugPrint('[GLOBAL_CACHE] 💭 Pré-chargement messages chat...');
    try {
      // Liste des canaux à pré-charger (ceux de la barre latérale)
      const channels = [
        'general', 'informatique', 'maths', 'physique',
        'chimie', 'francais', 'anglais', 'histoire', 'philo', 'svt'
      ];

      // On charge en parallèle mais avec un délai entre chaque pour pas saturer
      for (final channel in channels) {
        try {
          final snap = await FirebaseFirestore.instance
              .collection('chats')
              .doc(channel)
              .collection('messages')
              .orderBy('timestamp', descending: true)
              .limit(30) // 30 derniers messages par canal
              .get();

          final messages = snap.docs
              .map((doc) => doc.data())
              .toList();

          _chatMessages[channel] = messages;
          debugPrint('[GLOBAL_CACHE] ✅ Canal "$channel": ${messages.length} messages');
        } catch (e) {
          debugPrint('[GLOBAL_CACHE] ⚠️  Canal "$channel": erreur $e');
          _chatMessages[channel] = []; // Vide même en erreur
        }

        // Petit délai pour étaler les requêtes
        await Future.delayed(const Duration(milliseconds: 50));
      }

      _chatReady = true;
      debugPrint('[GLOBAL_CACHE] ✅ Chat pré-chargé sur ${_chatMessages.length} canaux');
    } catch (e, stack) {
      debugPrint('[GLOBAL_CACHE] ❌ Erreur pré-chargement chat: $e');
      debugPrint('[GLOBAL_CACHE] Stack: $stack');
      _chatReady = true;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════════
  // INVALIDATION (pour refresh manuel)
  // ═══════════════════════════════════════════════════════════════════════════════

  void invalidateAll() {
    debugPrint('[GLOBAL_CACHE] 🗑️  Invalidation complète du cache');
    _biblioDocs.clear();
    _questions.clear();
    _chatMessages.clear();
    _biblioReady = false;
    _questionsReady = false;
    _chatReady = false;
  }

  void invalidateBiblio() {
    debugPrint('[GLOBAL_CACHE] 🗑️  Invalidation biblio');
    _biblioDocs.clear();
    _biblioReady = false;
  }

  void invalidateQuestions() {
    debugPrint('[GLOBAL_CACHE] 🗑️  Invalidation questions');
    _questions.clear();
    _questionsReady = false;
  }

  void invalidateChat() {
    debugPrint('[GLOBAL_CACHE] 🗑️  Invalidation chat');
    _chatMessages.clear();
    _chatReady = false;
  }
}

/// Instance globale accessible partout
final GlobalDataCache = _GlobalDataCache();
