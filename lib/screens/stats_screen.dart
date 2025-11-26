import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/session_repository.dart';
import '../models/workout_session.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = SessionRepository();

    return Scaffold(
      backgroundColor: const Color(0xFF0D0C14),
      appBar: AppBar(
        title: Text(
          'Estadísticas',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<List<WorkoutSession>>(
        stream: repo.sessionsForCurrentUser(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.greenAccent),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error al cargar estadísticas',
                style: GoogleFonts.nunito(color: Colors.white70),
              ),
            );
          }

          final sessions = snapshot.data ?? [];

          if (sessions.isEmpty) {
            return Center(
              child: Text(
                'Todavía no tenés sesiones guardadas.\nCompletá una partida para ver tus stats.',
                style: GoogleFonts.nunito(
                  color: Colors.white70,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            );
          }

          final totalSteps = sessions.fold<int>(
              0, (prev, s) => prev + s.steps);
          final bestCombo = sessions.fold<int>(
              0, (prev, s) => s.maxCombo > prev ? s.maxCombo : prev);

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildSummaryCard(totalSteps, bestCombo, sessions.length),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.builder(
                    itemCount: sessions.length,
                    itemBuilder: (context, index) {
                      final s = sessions[index];
                      return _buildSessionTile(s);
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummaryCard(int totalSteps, int bestCombo, int sessionsCount) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF1F1F2E), Color(0xFF12121B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildSummaryItem('Sesiones', sessionsCount.toString()),
          _buildSummaryItem('Pasos totales', totalSteps.toString()),
          _buildSummaryItem('Mejor combo', 'x$bestCombo'),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.nunito(
            color: Colors.white60,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildSessionTile(WorkoutSession s) {
    final dateStr =
        '${s.startedAt.day.toString().padLeft(2, '0')}/'
        '${s.startedAt.month.toString().padLeft(2, '0')} '
        '${s.startedAt.hour.toString().padLeft(2, '0')}:'
        '${s.startedAt.minute.toString().padLeft(2, '0')}';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: const Color(0xFF15151E),
      ),
      child: Row(
        children: [
          Icon(
            Icons.directions_walk,
            color: Colors.greenAccent.shade200,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${s.mode} • ${s.avgBpm} BPM',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$dateStr • ${s.steps} pasos • combo máx x${s.maxCombo}',
                  style: GoogleFonts.nunito(
                    color: Colors.white60,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
