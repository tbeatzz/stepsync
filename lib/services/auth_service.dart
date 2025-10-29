import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  /// 🔹 Inicia sesión con Google
  Future<User?> signInWithGoogle() async {
    try {
      print('[AUTH] inicio signInWithGoogle');

      // 1. Elegir cuenta
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      print('[AUTH] _googleSignIn.signIn() -> $googleUser');

      if (googleUser == null) {
        print('[AUTH] El usuario canceló el login de Google');
        return null;
      }

      // 2. Tokens de Google
      final GoogleSignInAuthentication googleAuth =
      await googleUser.authentication;
      print('[AUTH] googleUser.authentication OK '
          'accessToken=${googleAuth.accessToken != null} '
          'idToken=${googleAuth.idToken != null}');

      // 3. Credencial de Firebase
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      print('[AUTH] credential creada (${credential.runtimeType})');

      // 4. Loguear en Firebase
      final UserCredential userCredential =
      await _auth.signInWithCredential(credential);
      print('[AUTH] signInWithCredential OK user=${userCredential.user}');

      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      print('[AUTH][FirebaseAuthException] code=${e.code} message=${e.message}');
      return null;
    } catch (e) {
      print('[AUTH][Exception] $e');
      return null;
    }
  }

  /// 🔹 Cierra la sesión
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
    } catch (e) {
      print('Error al cerrar sesión: $e');
    }
  }

  /// 🔹 Obtiene el usuario actual (si hay sesión iniciada)
  User? get currentUser => _auth.currentUser;
}
