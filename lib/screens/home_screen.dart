import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../services/auth_service.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final User? user = AuthService().currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          "StepSync",
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 22,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () async {
              await AuthService().signOut();
              context.go('/welcome');
            },
          ),
        ],
      ),
      body: user == null
          ? const Center(
        child: Text(
          "No hay usuario autenticado 😅",
          style: TextStyle(color: Colors.white70, fontSize: 16),
        ),
      )
          : Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 🧑‍💼 Imagen del usuario
            CircleAvatar(
              radius: 60,
              backgroundImage: user.photoURL != null
                  ? NetworkImage(user.photoURL!)
                  : const AssetImage('assets/images/default_avatar.png')
              as ImageProvider,
            ),
            const SizedBox(height: 20),

            // 🪪 Nombre del usuario
            Text(
              user.displayName ?? "Usuario sin nombre",
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: 8),

            // 📧 Correo electrónico
            Text(
              user.email ?? "Sin correo asociado",
              style: GoogleFonts.nunito(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),

            const SizedBox(height: 30),

            // 🏃 Botón para comenzar el juego
            ElevatedButton(
              onPressed: () {
                // acá luego va la lógica del juego principal
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('🚧 Próximamente: modo entrenamiento'),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6A00F4),
                minimumSize: const Size(double.infinity, 55),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: Text(
                "Comenzar",
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
