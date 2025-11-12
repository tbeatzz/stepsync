// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/theme.dart';
import '../widgets/custom_button.dart';
import '../services/auth_service.dart';
import '../data/user_repository.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final User? user = AuthService().currentUser;

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // HEADER (evita overflow: nombre+foto arriba; nivel+pts abajo)
              _Header(user: user),

              const SizedBox(height: 32),

              // PARTIDA RÁPIDA
              _buildQuickMatchSection(context),

              const SizedBox(height: 28),

              // MENÚ PRINCIPAL
              _buildMainMenu(context),
            ],
          ),
        ),
      ),
    );
  }

  // 🔹 Sección de partida rápida
  Widget _buildQuickMatchSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [AppColors.gradientBlue1, AppColors.gradientBlue2],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          Text(
            "Partida rápida",
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 22),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildModeButton(
                context,
                "Caminar",
                Icons.directions_walk,
                [AppColors.walkStart, AppColors.walkEnd],
              ),
              _buildModeButton(
                context,
                "Trotar",
                Icons.directions_run,
                [AppColors.jogStart, AppColors.jogEnd],
              ),
              _buildModeButton(
                context,
                "Correr",
                Icons.directions_run,
                [AppColors.run, AppColors.run],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 🔹 Sección de botones del menú principal
  Widget _buildMainMenu(BuildContext context) {

    void showWipMessage(String section) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$section está en desarrollo 🚧'),
          backgroundColor: Colors.deepPurpleAccent,
          duration: const Duration(seconds: 2),
        ),
      );


    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [AppColors.gradientBlue1, AppColors.gradientBlue2],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: GradientButton(
                  label: "Canciones",
                  icon: Icons.music_note,
                  colors: [AppColors.purpleStart, AppColors.purpleEnd],
                  height: 90,
                  onTap: () => showWipMessage("Canciones"),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: GradientButton(
                  label: "Logros",
                  icon: Icons.emoji_events,
                  colors: [AppColors.purpleStart, AppColors.purpleEnd],
                  height: 90,
                  onTap: () => showWipMessage("Logros"),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          GradientButton(
            label: "Estadísticas",
            icon: Icons.bar_chart,
            colors: [AppColors.purpleStart, AppColors.purpleEnd],
            height: 110,
            onTap: () => showWipMessage("Estadísticas"),
          ),
          const SizedBox(height: 18),
          GradientButton(
            label: "Perfil",
            icon: Icons.person_outline,
            colors: [AppColors.purpleStart, AppColors.purpleEnd],
            height: 90,
            onTap: () => showWipMessage("Perfil"),
          ),
        ],
      ),
    );
  }

  // 🔹 Botón rectangular para modos de juego
  Widget _buildModeButton(
      BuildContext context,
      String label,
      IconData icon,
      List<Color> colors,
      ) {
    return GestureDetector(
      onTap: () => context.push('/session', extra: label),
      child: Container(
        width: 90,
        height: 130,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            colors: colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: colors.last.withOpacity(0.5),
              blurRadius: 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 42),
            const SizedBox(height: 12),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// =======================
/// Header compacto y reactivo
/// =======================
class _Header extends StatelessWidget {
  final User? user;
  const _Header({required this.user});

  @override
  Widget build(BuildContext context) {
    final uid = user?.uid;

    // Placeholder si todavía no hay user
    if (uid == null) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            "stepsync",
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w800,
            ),
          ),
          const CircleAvatar(
            radius: 18,
            backgroundColor: Colors.white24,
            child: Icon(Icons.person, color: Colors.white),
          ),
        ],
      );
    }

    return StreamBuilder<Map<String, dynamic>?>(
      stream: UserRepository().watchUserProfile(uid),
      builder: (context, snap) {
        final data = snap.data ?? {};
        final displayName = user?.displayName ?? 'Usuario';
        final photoURL = user?.photoURL;
        final level = (data['level'] ?? 1).toString();
        final points = (data['points'] ?? 0).toString();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1) Fila: título + avatar + nombre (protegido con elipsis)
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    "stepsync",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                CircleAvatar(
                  radius: 18,
                  backgroundImage: (photoURL != null && photoURL.isNotEmpty)
                      ? NetworkImage(photoURL)
                      : null,
                  backgroundColor: Colors.white24,
                  child: (photoURL == null || photoURL.isEmpty)
                      ? const Icon(Icons.person, color: Colors.white)
                      : null,
                ),
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 150),
                  child: Text(
                    displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // 2) Debajo: nivel y puntos (en Wrap para evitar overflow)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10),
              ),
              child: Wrap(
                spacing: 16,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.stacked_bar_chart,
                          size: 18, color: Colors.white70),
                      const SizedBox(width: 6),
                      Text(
                        "Nivel $level",
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star, size: 18, color: Colors.amber),
                      const SizedBox(width: 6),
                      Text(
                        "$points pts",
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
