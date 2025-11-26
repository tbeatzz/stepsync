import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/theme.dart';
import '../widgets/custom_button.dart';
import '../services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

import '../services/user_repository.dart';
import '../models/user_profile.dart';



class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: SafeArea(
        child: StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, snapshot) {
            final user = snapshot.data; // 🔁 se actualiza solo

            return SingleChildScrollView(
              padding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // HEADER
                  _buildHeader(context),


                  const SizedBox(height: 32),

                  // PARTIDA RÁPIDA
                  _buildQuickMatchSection(context),

                  const SizedBox(height: 28),

                  // MENÚ PRINCIPAL
                  _buildMainMenu(context),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // 🔹 Sheet con opciones de cuenta (logout o login)
  void _showAccountSheet(BuildContext context, User? user) {
    final authService = AuthService();
    final rootContext = context; // para navegar desde el sheet

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        if (user != null) {
          // ✅ Usuario logeado → opción cerrar sesión
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cuenta',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: CircleAvatar(
                    backgroundImage: user.photoURL != null
                        ? NetworkImage(user.photoURL!)
                        : null,
                    backgroundColor: Colors.white24,
                    child: user.photoURL == null
                        ? const Icon(Icons.person, color: Colors.white)
                        : null,
                  ),
                  title: Text(
                    user.displayName ?? 'Usuario',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: Text(
                    user.email ?? '',
                    style: GoogleFonts.nunito(
                      color: Colors.white60,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () async {
                    await authService.signOut();
                    Navigator.of(sheetContext).pop(); // cerrar sheet
                    if (!rootContext.mounted) return;
                    rootContext.go('/welcome');
                  },
                  icon: const Icon(Icons.logout, color: Colors.redAccent),
                  label: Text(
                    'Cerrar sesión',
                    style: GoogleFonts.poppins(
                      color: Colors.redAccent,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          );
        } else {
          // 👤 Invitado → opción iniciar sesión con Google
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Modo invitado',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Estás jugando sin cuenta. Podés iniciar sesión con Google '
                      'para guardar tu progreso más adelante.',
                  style: GoogleFonts.nunito(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () async {
                    final user = await authService.signInWithGoogle();

                    if (user != null) {
                      Navigator.of(sheetContext).pop(); // cerrar sheet
                      // 🔁 No hace falta go('/home'): el StreamBuilder se entera solo
                      if (!rootContext.mounted) return;
                      // rootContext.go('/home'); // opcional
                    } else {
                      ScaffoldMessenger.of(rootContext).showSnackBar(
                        const SnackBar(
                          content:
                          Text('No se pudo iniciar sesión con Google 😕'),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.login, color: Colors.black87),
                  label: Text(
                    'Iniciar sesión con Google',
                    style: GoogleFonts.poppins(
                      color: Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                ),
              ],
            ),
          );
        }
      },
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
                  onTap: () => context.push('/achievements'),
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
            onTap: () => context.push('/stats'),
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

  Widget _buildHeader(BuildContext context) {
    final authService = AuthService();
    final firebaseUser = authService.currentUser;
    final userRepo = UserRepository();

    return StreamBuilder<UserProfile?>(
      stream: userRepo.watchCurrentUserProfile(),
      builder: (context, snapshot) {
        final profile = snapshot.data;

        final bool isGuest = firebaseUser == null || profile == null;

        final String displayName = isGuest
            ? 'Invitado'
            : (profile.displayName.isNotEmpty
            ? profile.displayName
            : 'Usuario');

        final String? photoURL = isGuest ? null : profile.photoURL;
        final String? email = firebaseUser?.email;

        const int levelStep = 1000;
        int level = 1;
        int points = 0;
        double progress = 0.0;
        int currentLevelPoints = 0;

        if (!isGuest) {
          level = profile!.level;
          points = profile.points;
          currentLevelPoints = points % levelStep;
          progress = currentLevelPoints / levelStep;
        }

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Título de la app
            Text(
              "stepsync",
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.w800,
              ),
            ),

            // Bloque tocable: nombre + nivel + avatar
            GestureDetector(
              onTap: () =>
                  _showAccountBottomSheet(context, isGuest, displayName, email),
              child: Row(
                children: [
                  // Info de nombre + nivel
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        displayName,
                        style: GoogleFonts.poppins(
                          color: Colors.white70,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (isGuest)
                        Text(
                          'Modo invitado',
                          style: GoogleFonts.nunito(
                            color: Colors.white38,
                            fontSize: 12,
                          ),
                        )
                      else
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Nivel $level · $points pts',
                              style: GoogleFonts.nunito(
                                color: Colors.white60,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              width: 120,
                              height: 6,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                color: Colors.white12,
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: LinearProgressIndicator(
                                  value: progress.clamp(0.0, 1.0),
                                  backgroundColor: Colors.transparent,
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(width: 8),

                  // Avatar
                  CircleAvatar(
                    radius: 18,
                    backgroundImage:
                    photoURL != null ? NetworkImage(photoURL) : null,
                    backgroundColor: Colors.white24,
                    child: photoURL == null
                        ? const Icon(Icons.person, color: Colors.white)
                        : null,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  void _showAccountBottomSheet(
      BuildContext context,
      bool isGuest,
      String displayName,
      String? email,
      ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF15151E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header de la sheet
              Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: Colors.white24,
                    child: const Icon(Icons.person, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (email != null && !isGuest)
                          Text(
                            email,
                            style: GoogleFonts.nunito(
                              color: Colors.white54,
                              fontSize: 13,
                            ),
                          )
                        else
                          Text(
                            'Modo invitado',
                            style: GoogleFonts.nunito(
                              color: Colors.white54,
                              fontSize: 13,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),
              const Divider(color: Colors.white12),

              if (isGuest) ...[
                Text(
                  'Estás usando StepSync como invitado.\nIniciá sesión para guardar tu progreso en la nube.',
                  style: GoogleFonts.nunito(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      // Te llevo al flujo de bienvenida/login
                      context.go('/welcome');
                    },
                    icon: const Icon(Icons.login),
                    label: const Text('Iniciar sesión con Google'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.greenAccent.shade400,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ),
              ] else ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      Navigator.of(sheetContext).pop();
                      final auth = AuthService();
                      await auth.signOut();
                      if (!context.mounted) return;
                      context.go('/welcome');
                    },
                    icon: const Icon(Icons.logout),
                    label: const Text('Cerrar sesión'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent.shade200,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }


  // 🔹 Botón rectangular para modos de juego
  Widget _buildModeButton(
      BuildContext context, String label, IconData icon, List<Color> colors) {
    return GestureDetector(
      onTap: () {
        context.push('/session', extra: label); // navega con el modo
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
