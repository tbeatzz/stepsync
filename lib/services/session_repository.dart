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

  // 👉 Estima longitud de zancada por modo
  double _estimateStrideMeters(String mode) {
    final m = mode.toLowerCase();

    if (m.contains('correr')) {
      return 1.10; // correr: zancada más larga
    } else if (m.contains('trotar')) {
      return 0.90; // trotar
    } else {
      return 0.75; // default: caminar
    }
  }

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
    // 1) Construimos la sesión base (sin distancia)
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

    // 2) Calculamos distancia estimada a partir de pasos + modo
    final strideMeters = _estimateStrideMeters(mode);
    final double distanceMeters = steps * strideMeters;

    // 3) Convertimos a mapa y le agregamos distanceMeters
    final Map<String, dynamic> data = session.toMap();
    data['distanceMeters'] = distanceMeters;

    // 4) Guardar sesión en Firestore
    await _db.collection('sessions').add(data);

    // 5) Recompensas de puntos / nivel (por ahora sin usar distancia)
    if (!_isGuest()) {
      final reward = await _userRepo.applySessionRewards(
        mode: mode,
        steps: steps,
        maxCombo: maxCombo,
        avgBpm: avgBpm,
        distanceMeters: distanceMeters, 
      );

      // Debug opcional
      // ignore: avoid_print
      print('[SessionRepository] Sesión guardada, reward = $reward puntos');
      // ignore: avoid_print
      print(
        '[SessionRepository] Distancia estimada: '
            '${distanceMeters.toStringAsFixed(1)} m '
            '(modo=$mode, pasos=$steps, zancada=${strideMeters.toStringAsFixed(2)} m)',
      );
    } else {
      // ignore: avoid_print
      print('[SessionRepository] Sesión de invitado, no se actualiza perfil');
      // ignore: avoid_print
      print(
        '[SessionRepository] Distancia estimada (invitado): '
            '${distanceMeters.toStringAsFixed(1)} m '
            '(modo=$mode, pasos=$steps, zancada=${strideMeters.toStringAsFixed(2)} m)',
      );
    }


    // 6) Chequear y desbloquear logros (usa la sesión base)
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
