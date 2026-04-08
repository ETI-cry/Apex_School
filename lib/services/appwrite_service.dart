import 'dart:typed_data';

import 'package:appwrite/appwrite.dart';
import 'package:http/http.dart' as http;

import 'constants.dart';

class AppwriteService {
  late final Client client;
  late final Storage storage;

  AppwriteService() {
    client = Client()
        .setEndpoint(appwriteEndpoint)
        .setProject(projectId)
        .setSelfSigned(status: true);

    storage = Storage(client);
    
    print('[APPWRITE] ✅ Service initialisé');
    print('[APPWRITE] Endpoint: $appwriteEndpoint');
    print('[APPWRITE] Project ID: $projectId');
    print('[APPWRITE] Bucket ID: $bucketId');
  }

  /// ===================== UPLOAD FICHIERS =====================

  Future<String> uploadFile({
    required String filePath,
    required String userId,
    required String filename,
    required String mime,
    required void Function(int progress) onProgress,
  }) async {
    try {
      print('[APPWRITE] 📤 Upload fichier: $filename');

      final file = InputFile.fromPath(
        path: filePath,
        filename: filename,
        contentType: mime,
      );

      final result = await storage.createFile(
        bucketId: bucketId,
        fileId: ID.unique(),
        file: file,
        permissions: [
          Permission.read(Role.any()),
        ],
      );

      print('[APPWRITE] ✅ Fichier uploadé: ${result.$id}');
      
      for (int p = 0; p <= 100; p += 20) {
        await Future.delayed(const Duration(milliseconds: 50));
        onProgress(p);
      }
      onProgress(100);

      return result.$id;
    } catch (e) {
      print('❌ [APPWRITE] Erreur upload: $e');
      rethrow;
    }
  }

  Future<String> uploadFileWeb({
    required Uint8List bytes,
    required String filename,
    required String userId,
    required String mime,
    required void Function(int progress) onProgress,
  }) async {
    try {
      print('[APPWRITE] 🌐 Upload Web: $filename');

      final file = InputFile.fromBytes(
        bytes: bytes,
        filename: filename,
        contentType: mime,
      );

      final result = await storage.createFile(
        bucketId: bucketId,
        fileId: ID.unique(),
        file: file,
        permissions: [
          Permission.read(Role.any()),
        ],
      );

      print('[APPWRITE] ✅ Fichier Web uploadé: ${result.$id}');
      
      for (int p = 0; p <= 100; p += 20) {
        await Future.delayed(const Duration(milliseconds: 50));
        onProgress(p);
      }
      onProgress(100);

      return result.$id;
    } catch (e) {
      print('❌ [APPWRITE] Erreur upload Web: $e');
      rethrow;
    }
  }

  /// ===================== URL DES FICHIERS - VERSION CORRIGÉE =====================

  /// URL directe pour afficher les images
  String getFileUrl(String fileId) {
    if (fileId.isEmpty) {
      print('[APPWRITE] ⚠️ FileID vide');
      return '';
    }

    // Format CORRECT pour Appwrite
    final url = '$appwriteEndpoint/storage/buckets/$bucketId/files/$fileId/view?project=$projectId';
    
    print('[APPWRITE] 🔗 URL view générée: $url');
    
    return url;
  }

  /// URL de prévisualisation (thumbnail) - CORRIGÉE
  String getFilePreviewUrl(String fileId, {int width = 200, int height = 200}) {
    if (fileId.isEmpty) {
      print('[APPWRITE] ⚠️ FileID vide pour preview');
      return '';
    }
    
    // Format CORRECT pour les previews Appwrite
    final url = '$appwriteEndpoint/storage/buckets/$bucketId/files/$fileId/preview?project=$projectId&width=$width&height=$height';
    
    print('[APPWRITE] 🖼️ URL preview générée: $url');
    
    return url;
  }

  /// Vérifie si une URL est accessible (pour debug)
  Future<bool> testUrl(String fileId) async {
    try {
      final url = getFileUrl(fileId);
      print('[APPWRITE] 🔍 Test URL: $url');
      
      final response = await http.head(Uri.parse(url));
      final isOk = response.statusCode == 200;
      
      print('[APPWRITE] 📊 Status: ${response.statusCode} - ${isOk ? '✅ OK' : '❌ ÉCHEC'}');
      
      return isOk;
    } catch (e) {
      print('[APPWRITE] ❌ Erreur test URL: $e');
      return false;
    }
  }

  /// Test la preview URL
  Future<bool> testPreviewUrl(String fileId) async {
    try {
      final url = getFilePreviewUrl(fileId);
      print('[APPWRITE] 🔍 Test Preview URL: $url');
      
      final response = await http.head(Uri.parse(url));
      final isOk = response.statusCode == 200;
      
      print('[APPWRITE] 📊 Preview Status: ${response.statusCode} - ${isOk ? '✅ OK' : '❌ ÉCHEC'}');
      
      return isOk;
    } catch (e) {
      print('[APPWRITE] ❌ Erreur test Preview URL: $e');
      return false;
    }
  }

  /// ===================== SUPPRESSION =====================

  Future<void> deleteFile(String fileId) async {
    try {
      print('[APPWRITE] 🗑️ Suppression: $fileId');
      
      await storage.deleteFile(
        bucketId: bucketId,
        fileId: fileId,
      );
      
      print('[APPWRITE] ✅ Fichier supprimé');
    } catch (e) {
      print('❌ [APPWRITE] Erreur suppression: $e');
      rethrow;
    }
  }

  /// ===================== UTILITAIRES =====================

  Future<bool> testConnection() async {
    try {
      print('[APPWRITE] 🔧 Test de connexion...');
      
      print('[APPWRITE] 🔧 Constantes:');
      print('[APPWRITE]   - Endpoint: $appwriteEndpoint');
      print('[APPWRITE]   - Project: $projectId');
      print('[APPWRITE]   - Bucket: $bucketId');
      
      final testUrl = getFileUrl('test123');
      print('[APPWRITE] 🔧 URL exemple: $testUrl');
      
      return true;
    } catch (e) {
      print('❌ [APPWRITE] Test connexion échoué: $e');
      return false;
    }
  }

  Future<bool> fileExists(String fileId) async {
    try {
      if (fileId.isEmpty) return false;
      
      await storage.getFile(
        bucketId: bucketId,
        fileId: fileId,
      );
      
      return true;
    } catch (e) {
      if (e.toString().contains('404') || e.toString().contains('not found')) {
        return false;
      }
      print('[APPWRITE] ⚠️ Erreur fileExists: $e');
      return false;
    }
  }

  void setJwtToken(String token) {
    client.setJWT(token);
  }

  void clearAuth() {
    client.setJWT(null);
  }
}