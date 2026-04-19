import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  static final _auth = FirebaseAuth.instance;
  static final _googleSignIn = GoogleSignIn();

  static Stream<User?> get userStream => _auth.authStateChanges();

  static User? get currentUser => _auth.currentUser;

  static Future<UserCredential?> signInWithGoogle() async {
    if (kIsWeb) {
      // Web: Use Firebase Auth popup
      try {
        final provider = GoogleAuthProvider();
        return await _auth.signInWithPopup(provider);
      } catch (e) {
        return null;
      }
    } else {
      // Mobile: Use google_sign_in package
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      return _auth.signInWithCredential(credential);
    }
  }

  static Future<void> signOut() async {
    if (kIsWeb) {
      await _auth.signOut();
    } else {
      await Future.wait([
        _auth.signOut(),
        _googleSignIn.signOut(),
      ]);
    }
  }
}
