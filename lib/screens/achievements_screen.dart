import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/achievements_repository.dart';
import '../models/achievement_def.dart';
import '../models/user_achievement.dart';

class AchievementsScreen extends StatelessWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = AchievementsRepository();

    return Scaffold(
      backgroundColor: const Color(0xFF0D0C14),
      appBar: AppBar(
        title: Text(
          'Logros',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: StreamBuilder<List<UserAchievement>>(
          stream: repo.watchForCurrentUser(),
          builder: (context, snapshot) {
            final unlockedList = snapshot.data ?? [];
            final unlockedCodes =
            unlockedList.map((a) => a.code).toSet();

            // Mezclamos catálogo (definiciones) con estado del usuario
            final all = achievementDefs;

            return ListView.separated(
              itemCount: all.length,
              separatorBuilder: (_, __) =>
              const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final def = all[index];
                final unlocked =
                unlockedCodes.contains(def.code);

                UserAchievement? unlockedAch;
                if (unlocked) {
                  unlockedAch = unlockedList.firstWhere(
                          (a) => a.code == def.code,
                      orElse: () => unlockedList.first);
                }

                return _buildAchievementTile(
                  context,
                  def: def,
                  unlocked: unlocked,
                  unlockedAt: unlockedAch?.unlockedAt,
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildAchievementTile(
      BuildContext context, {
        required AchievementDef def,
        required bool unlocked,
        DateTime? unlockedAt,
      }) {
    final Color bg = unlocked
        ? const Color(0xFF1E2A3B)
        : const Color(0xFF14141D);
    final Color iconBg = unlocked
        ? const Color(0xFFFFD54F)
        : Colors.grey.shade700;
    final Color titleColor =
    unlocked ? Colors.white : Colors.white54;
    final Color descColor =
    unlocked ? Colors.white70 : Colors.white38;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: unlocked
              ? Colors.amberAccent.withOpacity(0.5)
              : Colors.white10,
          width: 1,
        ),
        boxShadow: [
          if (unlocked)
            BoxShadow(
              color: Colors.amberAccent.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 6),
            ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconBg,
              shape: BoxShape.circle,
            ),
            child: Icon(
              unlocked ? Icons.emoji_events : Icons.lock_outline,
              color: unlocked ? Colors.black : Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  def.title,
                  style: GoogleFonts.poppins(
                    color: titleColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  def.description,
                  style: GoogleFonts.nunito(
                    color: descColor,
                    fontSize: 13,
                  ),
                ),
                if (unlockedAt != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Desbloqueado: ${_formatDate(unlockedAt)}',
                    style: GoogleFonts.nunito(
                      color: Colors.white54,
                      fontSize: 11,
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 6),
                  Text(
                    'Bloqueado',
                    style: GoogleFonts.nunito(
                      color: Colors.white38,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    // formato simple dd/mm, hh:mm
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$d/$m $h:$min';
  }
}
