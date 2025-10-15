import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/theme.dart';
import '../widgets/custom_button.dart';
import '../services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

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
              // HEADER
              Row(
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
                  Row(
                    children: [
                      Text(
                        user?.displayName ?? "Usuario",
                        style: GoogleFonts.poppins(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 8),
                      CircleAvatar(
                        radius: 18,
                        backgroundImage: user?.photoURL != null
                            ? NetworkImage(user!.photoURL!)
                            : null,
                        backgroundColor: Colors.white24,
                        child: user?.photoURL == null
                            ? const Icon(Icons.person, color: Colors.white)
                            : null,
                      ),
                    ],
                  ),
                ],
              ),

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
              _buildModeButton(context, "Caminar", Icons.directions_walk,
                  [AppColors.walkStart, AppColors.walkEnd]),
              _buildModeButton(context, "Trotar", Icons.directions_run,
                  [AppColors.jogStart, AppColors.jogEnd]),
              _buildModeButton(context, "Correr", Icons.directions_run,
                  [AppColors.run, AppColors.run]),
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
      BuildContext context, String label, IconData icon, List<Color> colors) {
    return GestureDetector(
      onTap: () {
        context.push('/session', extra: label); // ✅ ahora navega con el modo
      },
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
