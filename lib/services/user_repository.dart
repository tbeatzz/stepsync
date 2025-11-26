import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/user_profile.dart';

class UserRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _usersCol =>
      _db.collection('users').withConverter<Map<String, dynamic>>(
        fromFirestore: (snap, _) => snap.data()!,
        toFirestore: (data, _) => data,
      );

  /// Devuelve el UID actual o null si no hay sesión
  String? get currentUid => _auth.currentUser?.uid;

  /// Asegura que exista el perfil del usuario actual en /users/{uid}.
  /// - Si ya existe → lo devuelve.
  /// - Si no existe → lo crea con valores iniciales.
  Future<UserProfile?> ensureCurrentUserProfile() async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      // No hay usuario logueado, no hay perfil
      return null;
    }

    final uid = user.uid;
    final docRef = _usersCol.doc(uid);
    final docSnap = await docRef.get();

    if (docSnap.exists) {
      return UserProfile.fromDoc(
          docSnap as DocumentSnapshot<Map<String, dynamic>>);
    }

    // Crear perfil inicial
    final profile = UserProfile.initialFromFirebaseUser(
      uid: uid,
      email: user.email!,
      displayName: user.displayName,
      photoURL: user.photoURL,
    );

    await docRef.set(profile.toMapForCreate());
    return profile;
  }

  /// Obtiene el perfil actual (si existe). No crea nada.
  Future<UserProfile?> getCurrentUserProfile() async {
    final uid = currentUid;
    if (uid == null) return null;

    final docSnap =
    await _usersCol.doc(uid).get() as DocumentSnapshot<Map<String, dynamic>>;

    if (!docSnap.exists) return null;
    return UserProfile.fromDoc(docSnap);
  }

  /// Stream en tiempo real del perfil actual.
  Stream<UserProfile?> watchCurrentUserProfile() {
    final uid = currentUid;
    if (uid == null) {
      // No hay usuario logueado → stream vacío
      return const Stream<UserProfile?>.empty();
    }

    return _usersCol.doc(uid).snapshots().map((snap) {
      if (!snap.exists) return null;
      return UserProfile.fromDoc(
          snap as DocumentSnapshot<Map<String, dynamic>>);
    });
  }

  /// Actualiza parcialmente el perfil actual.
  Future<void> updateCurrentUserProfile(UserProfile profile) async {
    final uid = currentUid;
    if (uid == null) return;

    await _usersCol.doc(uid).update(profile.toMapForUpdate());
  }

  /// Helper básico para sumar puntos (sin lógica de nivel todavía).
  Future<void> addPointsToCurrentUser(int deltaPoints) async {
    final uid = currentUid;
    if (uid == null) return;

    final docRef = _usersCol.doc(uid);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(docRef);
      if (!snap.exists) return;

      final data = snap.data() as Map<String, dynamic>;
      final currentPoints = (data['points'] as int?) ?? 0;
      final newPoints = currentPoints + deltaPoints;

      tx.update(docRef, {
        'points': newPoints,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Aplica recompensas al usuario actual en base a una sesión.
  /// Devuelve la cantidad de puntos ganados en esa sesión.
  ///
  /// Ahora tiene en cuenta también la distancia recorrida.
  Future<int> applySessionRewards({
    required String mode,      // "Caminar", "Trotar", "Correr"
    required int steps,
    required int maxCombo,
    required int avgBpm,
    double distanceMeters = 0, // 👈 NUEVO (lo pasamos desde SessionRepository)
  }) async {
    final uid = currentUid;
    if (uid == null) {
      // invitado → no hay perfil que actualizar
      return 0;
    }

    // Si la sesión es prácticamente vacía, no sumamos nada
    if (steps <= 0 || avgBpm <= 0) {
      return 0;
    }

    final docRef = _usersCol.doc(uid);

    return await _db.runTransaction<int>((tx) async {
      final snap = await tx.get(docRef);
      if (!snap.exists) {
        // Perfil inconsistente: no debería pasar si usás ensureCurrentUserProfile en el login
        return 0;
      }

      final data = snap.data() as Map<String, dynamic>;

      final currentPoints = (data['points'] as int?) ?? 0;
      final currentLevel = (data['level'] as int?) ?? 1;

      // Distancia total acumulada hasta ahora
      double totalDistanceMeters = 0;
      final rawDist = data['totalDistanceMeters'];
      if (rawDist is int) {
        totalDistanceMeters = rawDist.toDouble();
      } else if (rawDist is double) {
        totalDistanceMeters = rawDist;
      }

      // Loops desbloqueados actuales (si no hay, por defecto solo loop base)
      List<String> unlockedLoops = ['loop_70'];
      final rawLoops = data['unlockedLoops'];
      if (rawLoops is List) {
        unlockedLoops = rawLoops.map((e) => e.toString()).toSet().toList();
      }

      // ---- Fórmula de puntos ----
      double modeMultiplier;
      switch (mode) {
        case 'Correr':
          modeMultiplier = 1.4;
          break;
        case 'Trotar':
          modeMultiplier = 1.2;
          break;
        case 'Caminar':
        default:
          modeMultiplier = 1.0;
          break;
      }

      final baseFromSteps = steps / 20.0;        // 1 punto cada ~20 pasos
      final comboBonus = maxCombo * 1.5;         // combo aporta bastante
      final intensityBonus = (avgBpm - 80) / 10; // premio leve por intensidad

      // 👉 NUEVO: bonus por distancia (1 punto cada ~250 m)
      final distanceBonus = (distanceMeters / 250.0);

      double raw = (baseFromSteps + comboBonus + intensityBonus + distanceBonus) *
          modeMultiplier;

      int reward = raw.round();
      if (reward < 0) reward = 0;
      if (reward > 500) reward = 500; // 🛡️ respetar reglas: delta points <= 500

      final newPoints = currentPoints + reward;

      // ---- Lógica de nivel ----
      const int levelStep = 1000; // cada 1000 puntos → +1 nivel
      int computedLevel = 1 + (newPoints ~/ levelStep);

      // Defensa extra para respetar regla: level solo puede aumentar de a 1
      if (computedLevel > currentLevel + 1) {
        computedLevel = currentLevel + 1;
      }
      if (computedLevel < currentLevel) {
        computedLevel = currentLevel;
      }

      // ---- Distancia acumulada + loops desbloqueados ----
      final newTotalDistance = totalDistanceMeters + distanceMeters;
      final newUnlockedLoops = _computeUnlockedLoops(newTotalDistance);

      tx.update(docRef, {
        'points': newPoints,
        'level': computedLevel,
        'totalDistanceMeters': newTotalDistance,
        'unlockedLoops': newUnlockedLoops,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return reward;
    });
  }

  /// Calcula los loops desbloqueados según la distancia total recorrida.
  ///
  /// - 0 km        → loop_70
  /// - 2 km        → loop_80
  /// - 5 km        → loop_90
  /// - 10 km       → loop_100
  /// - 20 km       → loop_110
  List<String> _computeUnlockedLoops(double totalDistanceMeters) {
    final km = totalDistanceMeters / 1000.0;
    final loops = <String>[];

    // base siempre
    loops.add('loop_70');

    if (km >= 2) loops.add('loop_80');
    if (km >= 5) loops.add('loop_90');
    if (km >= 10) loops.add('loop_100');
    if (km >= 20) loops.add('loop_110');

    // sin duplicados
    return loops.toSet().toList();
  }
}
