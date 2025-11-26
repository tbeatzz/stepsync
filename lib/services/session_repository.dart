import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/workout_session.dart';
import 'user_repository.dart';

import 'achievements_repository.dart';


class SessionRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final UserRepository _userRepo = UserRepository();
  final AchievementsRepository _achievementsRepo = AchievementsRepository();

  String _resolveUserId() {
    final user = _auth.currentUser;
    if (user == null) return 'guest';
    return user.uid;
  }

  bool _isGuest() {
    return _auth.currentUser == null;
  }

  Future<void> saveSession({
    required String mode,
    required int steps,
    required int maxCombo,
    required int avgBpm,
    required DateTime startedAt,
    required DateTime endedAt,
  }) async {
    final session = WorkoutSession(
      userId: _resolveUserId(),
      isGuest: _isGuest(),
      mode: mode,
      steps: steps,
      maxCombo: maxCombo,
      avgBpm: avgBpm,
      startedAt: startedAt,
      endedAt: endedAt,
    );

    // 1) Guardar sesión en Firestore
    await _db.collection('sessions').add(session.toMap());

    // 2) Recompensas de puntos / nivel
    if (!_isGuest()) {
      final reward = await _userRepo.applySessionRewards(
        mode: mode,
        steps: steps,
        maxCombo: maxCombo,
        avgBpm: avgBpm,
      );

      // Debug opcional
      print('[SessionRepository] Sesión guardada, reward = $reward puntos');
    } else {
      print('[SessionRepository] Sesión de invitado, no se actualiza perfil');
    }

    // 3) Chequear y desbloquear logros
    await _achievementsRepo.checkAndUnlockForSession(session);

  }

  Stream<List<WorkoutSession>> sessionsForCurrentUser() {
    final user = _auth.currentUser;

    Query query = _db.collection('sessions');

    // Filtramos por usuario o invitado, pero SIN orderBy en Firestore
    if (user != null) {
      query = query.where('userId', isEqualTo: user.uid);
    } else {
      query = query.where('isGuest', isEqualTo: true);
    }

    return query.snapshots().map((snap) {
      final sessions =
      snap.docs.map((doc) => WorkoutSession.fromDoc(doc)).toList();

      // Ordenamos en memoria por fecha descendente
      sessions.sort((a, b) => b.startedAt.compareTo(a.startedAt));

      return sessions;
    });
  }
}
