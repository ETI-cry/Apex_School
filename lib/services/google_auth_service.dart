import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';

class GoogleAuthService {
  static Future<UserCredential> signInWithGoogle() async {
    final FirebaseAuth auth = FirebaseAuth.instance;

    if (kIsWeb) {
      final GoogleAuthProvider googleProvider = GoogleAuthProvider();
      return await auth.signInWithPopup(googleProvider);
    } else {
      final GoogleSignIn googleSignIn = GoogleSignIn();
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        throw FirebaseAuthException(
            code: 'ERROR_ABORTED_BY_USER', message: 'Connexion annulée');
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      return await auth.signInWithCredential(credential);
    }
  }

  static Future<void> signOut() async {
    if (!kIsWeb) await GoogleSignIn().signOut();
    await FirebaseAuth.instance.signOut();
  }
}
