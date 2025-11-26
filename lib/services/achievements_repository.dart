import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/achievement_def.dart';
import '../models/user_achievement.dart';
import '../models/workout_session.dart';

class AchievementsRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('user_achievements');

  String? get _currentUid => _auth.currentUser?.uid;

  /// Stream de logros del usuario actual
  Stream<List<UserAchievement>> watchForCurrentUser() {
    final uid = _currentUid;
    if (uid == null) {
      return const Stream<List<UserAchievement>>.empty();
    }

    return _col
        .where('userId', isEqualTo: uid)
        .snapshots()
        .map((snap) {
      final list = snap.docs
          .map((d) => UserAchievement.fromDoc(
          d as DocumentSnapshot<Map<String, dynamic>>))
          .toList();

      // Ordenamos por fecha de desbloqueo
      list.sort((a, b) => b.unlockedAt.compareTo(a.unlockedAt));
      return list;
    });
  }

  /// Devuelve códigos de logros ya desbloqueados por este user.
  Future<Set<String>> _getUnlockedCodes(String userId) async {
    final snap = await _col.where('userId', isEqualTo: userId).get();
    return snap.docs
        .map((d) => d.data()['code'] as String)
        .toSet();
  }

  AchievementDef? _defForCode(String code) {
    try {
      return achievementDefs.firstWhere((d) => d.code == code);
    } catch (_) {
      return null;
    }
  }

  Future<void> _unlock(String userId, String code) async {
    final def = _defForCode(code);
    if (def == null) return;

    await _col.add({
      'userId': userId,
      'code': def.code,
      'title': def.title,
      'description': def.description,
      'unlockedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Chequea logros que se pueden desbloquear en base a una sesión recién guardada
  Future<void> checkAndUnlockForSession(WorkoutSession session) async {
    // Invitados: no guardamos logros por ahora
    if (session.isGuest) return;

    final userId = session.userId;
    if (userId.isEmpty) return;

    // Logros ya desbloqueados
    final unlocked = await _getUnlockedCodes(userId);

    // 1) Primera sesión → si todavía no tiene 'first_session', se lo damos ahora.
    if (!unlocked.contains('first_session')) {
      await _unlock(userId, 'first_session');
    }

    // 2) 10 sesiones → contamos sesiones del usuario (hasta 10)
    if (!unlocked.contains('ten_sessions')) {
      final snap = await _db
          .collection('sessions')
          .where('userId', isEqualTo: userId)
          .limit(10)
          .get();

      if (snap.docs.length >= 10) {
        await _unlock(userId, 'ten_sessions');
      }
    }

    // 3) Combo x20 en una sesión
    if (!unlocked.contains('combo_20') && session.maxCombo >= 20) {
      await _unlock(userId, 'combo_20');
    }

    // 4) Primer sesión en modo Correr
    if (!unlocked.contains('first_run') && session.mode == 'Correr') {
      await _unlock(userId, 'first_run');
    }
  }
}
