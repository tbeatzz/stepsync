import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:stepsync/data/user_repository.dart'; // ajustá el import

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final UserRepository _userRepo = UserRepository();

  Future<User?> signInWithGoogle() async {
    try {
      print('[AUTH] inicio signInWithGoogle');

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      print('[AUTH] _googleSignIn.signIn() -> $googleUser');
      if (googleUser == null) return null;

      final googleAuth = await googleUser.authentication;
      print('[AUTH] googleUser.authentication OK '
          'accessToken=${googleAuth.accessToken != null} '
          'idToken=${googleAuth.idToken != null}');

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      print('[AUTH] credential creada (${credential.runtimeType})');

      final userCred = await _auth.signInWithCredential(credential);
      final user = userCred.user;
      print('[AUTH] signInWithCredential OK user=$user');

      if (user != null) {
        // 🔹el upsert del perfil
        await _userRepo.upsertUserProfile(user);
        print('[AUTH] upsertUserProfile OK (${user.uid})');
      }

      return user;
    } on FirebaseAuthException catch (e) {
      print('[AUTH][FirebaseAuthException] code=${e.code} message=${e.message}');
      return null;
    } catch (e) {
      print('[AUTH][Exception] $e');
      return null;
    }
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
    } catch (e) {
      print('Error al cerrar sesión: $e');
    }
  }

  User? get currentUser => _auth.currentUser;
}
