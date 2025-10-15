import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const Color bgDark = Color(0xFF0D0C14);

    return Scaffold(
      backgroundColor: bgDark,
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
                        "Usuario",
                        style: GoogleFonts.poppins(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.white24,
                        child: Icon(Icons.person, color: Colors.white),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // CONTENEDOR PARTIDA RÁPIDA
              Container(
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1B174B), Color(0xFF1C0B2D)],
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
                        _buildRectModeButton(
                          label: "Caminar",
                          icon: Icons.directions_walk,
                          colors: [Color(0xFF42C86D), Color(0xFF2D978C)],
                        ),
                        _buildRectModeButton(
                          label: "Trotar",
                          icon: Icons.directions_run,
                          colors: [Color(0xFF117DE7), Color(0xFF2A41CE)],
                        ),
                        _buildRectModeButton(
                          label: "Correr",
                          icon: Icons.directions_run,
                          colors: [Color(0xFFBF3091), Color(0xFFBF3091)],
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // CONTENEDOR MENÚ PRINCIPAL
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1B174B), Color(0xFF1C0B2D)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // CANCIONES Y LOGROS
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: _buildMenuButton(
                            label: "Canciones",
                            icon: Icons.music_note,
                            colors: [Color(0xFF8837F6), Color(0xFF481A9D)],
                            height: 90,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildMenuButton(
                            label: "Logros",
                            icon: Icons.emoji_events,
                            colors: [Color(0xFF8837F6), Color(0xFF481A9D)],
                            height: 90,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // ESTADÍSTICAS
                    _buildMenuButton(
                      label: "Estadísticas",
                      icon: Icons.bar_chart,
                      colors: [Color(0xFF8837F6), Color(0xFF481A9D)],
                      height: 110,
                    ),
                    const SizedBox(height: 18),

                    // PERFIL
                    _buildMenuButton(
                      label: "Perfil",
                      icon: Icons.person_outline,
                      colors: [Color(0xFF8837F6), Color(0xFF481A9D)],
                      height: 90,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 🔹 BOTÓN RECTANGULAR DE PARTIDA RÁPIDA
  Widget _buildRectModeButton({
    required String label,
    required IconData icon,
    required List<Color> colors,
  }) {
    return GestureDetector(
      onTap: () => debugPrint("Modo $label seleccionado"),
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

  // 🔹 BOTÓN DE MENÚ PRINCIPAL
  Widget _buildMenuButton({
    required String label,
    required IconData icon,
    required List<Color> colors,
    double height = 80,
  }) {
    return GestureDetector(
      onTap: () => debugPrint("$label presionado"),
      child: Container(
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: colors.last.withOpacity(0.4),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Text(
              label,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
