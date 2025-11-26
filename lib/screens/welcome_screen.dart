import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../services/auth_service.dart';
import '../services/user_repository.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const Color primaryGradientStart = Color(0xFF007BFF); // Azul
    const Color primaryGradientEnd = Color(0xFFB026FF); // Violeta

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 🟣 Logo principal
              Image.asset(
                'assets/images/stepsync_logo.png',
                height: 130,
              ),
              const SizedBox(height: 80),

              // 🔵 Botón "Entrar como invitado"
              GestureDetector(
                onTap: () {
                  print('[WELCOME] Entrar como invitado -> /home');
                  context.go('/home');
                },
                child: Container(
                  height: 55,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [primaryGradientStart, primaryGradientEnd],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'Entrar como invitado',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 🔴 Botón Google Sign-In (real)
              ElevatedButton.icon(
                onPressed: () async {
                  print('[WELCOME] Tap Google Sign-In');
                  final authService = AuthService();

                  final user = await authService.signInWithGoogle();


                  if (user != null) {
                    final userRepo = UserRepository();
                    await userRepo.ensureCurrentUserProfile();
                    context.go('/home');
                  }

                  print('[WELCOME] signInWithGoogle() -> $user');
                  print(
                      '[WELCOME] FirebaseAuth.currentUser -> ${authService.currentUser}');

                  if (!context.mounted) {
                    print('[WELCOME] context no mounted, no puedo navegar');
                    return;
                  }

                  if (user != null) {
                    print('[WELCOME] Login OK, navegando a /home ...');
                    context.go('/home');
                  } else {
                    print('[WELCOME] user == null, mostrando snackbar');
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content:
                        Text("Error al iniciar sesión con Google 😕"),
                      ),
                    );
                  }
                },
                icon: Image.asset(
                  'assets/images/google_icon.png',
                  height: 22,
                ),
                label: Text(
                  'Ingresar con Google',
                  style: GoogleFonts.poppins(
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 55),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 2,
                ),
              ),

              const SizedBox(height: 24),

              // Texto inferior explicando modos
              Text(
                'Podés jugar como invitado o usar tu cuenta de Google '
                    'para guardar tu progreso más adelante.',
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
