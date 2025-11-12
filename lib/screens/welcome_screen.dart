import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../services/auth_service.dart';

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

              // 🔵 Botón principal "Ingresar"
              GestureDetector(
                onTap: () => context.go('/login'),
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
                    'Ingresar',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 🔴 Botón Google Sign-In
              ElevatedButton.icon(
                onPressed: () async {
                  print('[LOGIN] Tap Google');
                  final authService = AuthService();
                  final user = await authService.signInWithGoogle();
                  print('[LOGIN] signInWithGoogle() -> $user');
                  print('[LOGIN] FirebaseAuth.currentUser -> ${authService.currentUser}');

                  if (!context.mounted) {
                    print('[LOGIN] context no mounted');
                    return;
                  }

                  if (user != null) {
                    print('[LOGIN] Navegando a /home ...');
                    context.go('/home');
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Error al iniciar sesión con Google')),
                    );
                  }
                },
                icon: Image.asset('assets/images/google_icon.png', height: 22),
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  elevation: 2,
                ),
              )
              ,

              const SizedBox(height: 24),

              // 🟢 Texto inferior "No tenés una cuenta?"
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '¿No tenés una cuenta? ',
                    style: GoogleFonts.nunito(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => context.go('/register'),
                    child: Text(
                      'Regístrate',
                      style: GoogleFonts.poppins(
                        color: primaryGradientStart,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
