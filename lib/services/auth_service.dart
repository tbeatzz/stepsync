import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  /// 🔹 Inicia sesión con Google
  Future<User?> signInWithGoogle() async {
    try {
      // Desconecta cualquier sesión previa (evita errores en Android)
      await _googleSignIn.signOut();

      // Inicia el flujo de autenticación
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        // El usuario canceló el login
        return null;
      }

      // Obtiene los detalles de autenticación
      final GoogleSignInAuthentication googleAuth =
      await googleUser.authentication;

      // Crea las credenciales para Firebase
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Inicia sesión en Firebase con las credenciales de Google
      final UserCredential userCredential =
      await _auth.signInWithCredential(credential);

      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      print('🔥 Error de FirebaseAuth: ${e.message}');
      return null;
    } catch (e) {
      print('❌ Error general en Google Sign-In: $e');
      return null;
    }
  }

  /// 🔹 Cierra la sesión
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
    } catch (e) {
      print('⚠️ Error al cerrar sesión: $e');
    }
  }

  /// 🔹 Obtiene el usuario actual (si hay sesión iniciada)
  User? get currentUser => _auth.currentUser;
}
