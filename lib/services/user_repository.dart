import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/user_profile.dart';
import '../services/unlock_service.dart';
import '../services/cache_service.dart';

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
  /// Además: inicializa campos para unlocks y corre un sync inicial (best-effort).
  Future<UserProfile?> ensureCurrentUserProfile() async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) return null;

    final uid = user.uid;
    final docRef = _usersCol.doc(uid);
    final docSnap = await docRef.get();

    if (docSnap.exists) {
      return UserProfile.fromDoc(docSnap as DocumentSnapshot<Map<String, dynamic>>);
    }

    // Crear perfil inicial
    final profile = UserProfile.initialFromFirebaseUser(
      uid: uid,
      email: user.email!,
      displayName: user.displayName,
      photoURL: user.photoURL,
    );

    await docRef.set(profile.toMapForCreate());

    // Campos base para el sistema de contenido/unlocks
    await docRef.set({
      'selectedPack': 'base',
      'totalDistanceMeters': 0.0,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // Sync inicial de unlocks (packs/loops) desde Firestore (best-effort)
    try {
      final unlock = UnlockService(_db, cache: CacheService());
      await unlock.syncForUser(uid: uid, totalDistanceMeters: 0.0);
    } catch (e) {
      // ignore: avoid_print
      print('[UserRepository] Unlock initial sync error: $e');
    }

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
    if (uid == null) return const Stream<UserProfile?>.empty();

    return _usersCol.doc(uid).snapshots().map((snap) {
      if (!snap.exists) return null;
      return UserProfile.fromDoc(snap as DocumentSnapshot<Map<String, dynamic>>);
    });
  }

  /// Actualiza parcialmente el perfil actual.
  Future<void> updateCurrentUserProfile(UserProfile profile) async {
    final uid = currentUid;
    if (uid == null) return;

    await _usersCol.doc(uid).update(profile.toMapForUpdate());
  }

  /// Helper básico para sumar puntos (sin lógica de nivel).
  Future<void> addPointsToCurrentUser(int deltaPoints) async {
    final uid = currentUid;
    if (uid == null) return;

    final docRef = _usersCol.doc(uid);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(docRef);
      if (!snap.exists) return;

      final data = snap.data() as Map<String, dynamic>;
      final currentPoints = (data['points'] as int?) ?? 0;
      var newPoints = currentPoints + deltaPoints;

      // defensa simple
      if (newPoints < 0) newPoints = 0;

      tx.update(docRef, {
        'points': newPoints,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Fuerza un sync de unlocks para el usuario actual (best-effort).
  Future<void> syncUnlocksNow({double? totalDistanceMeters}) async {
    final uid = currentUid;
    if (uid == null) return;
    final unlock = UnlockService(_db, cache: CacheService());
    await unlock.syncForUser(uid: uid, totalDistanceMeters: totalDistanceMeters);
  }

  /// Aplica recompensas al usuario actual en base a una sesión.
  /// Devuelve la cantidad de puntos ganados en esa sesión.
  ///
  /// Ahora:
  /// - actualiza puntos/nivel/distancia en TX
  /// - luego corre UnlockService (post-TX) para recalcular unlockedPacks/unlockedLoops/selectedPack
  Future<int> applySessionRewards({
    required String mode, // "Caminar", "Trotar", "Correr"
    required int steps,
    required int maxCombo,
    required int avgBpm,
    double distanceMeters = 0,
  }) async {
    final uid = currentUid;
    if (uid == null) return 0;

    // sesión vacía → no sumar nada
    if (steps <= 0 || avgBpm <= 0) return 0;

    final docRef = _usersCol.doc(uid);
    double? _postTxNewTotalDistance;

    final reward = await _db.runTransaction<int>((tx) async {
      final snap = await tx.get(docRef);
      if (!snap.exists) return 0;

      final data = snap.data() as Map<String, dynamic>;

      final currentPoints = (data['points'] as int?) ?? 0;
      final currentLevel = (data['level'] as int?) ?? 1;

      // Distancia total acumulada
      double totalDistanceMeters = 0;
      final rawDist = data['totalDistanceMeters'];
      if (rawDist is int) totalDistanceMeters = rawDist.toDouble();
      if (rawDist is double) totalDistanceMeters = rawDist;

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

      final baseFromSteps = steps / 20.0; // 1 punto cada ~20 pasos
      final comboBonus = maxCombo * 1.5;
      final intensityBonus = (avgBpm - 80) / 10;
      final distanceBonus = (distanceMeters / 250.0); // 1 punto cada ~250m

      double raw = (baseFromSteps + comboBonus + intensityBonus + distanceBonus) *
          modeMultiplier;

      int reward = raw.round();
      if (reward < 0) reward = 0;
      if (reward > 500) reward = 500; // 🛡️ delta points <= 500

      final newPoints = currentPoints + reward;

      // ---- Nivel ----
      const int levelStep = 1000; // cada 1000 puntos → +1 nivel
      int computedLevel = 1 + (newPoints ~/ levelStep);

      // Defensa extra: level solo puede aumentar de a 1
      if (computedLevel > currentLevel + 1) computedLevel = currentLevel + 1;
      if (computedLevel < currentLevel) computedLevel = currentLevel;

      // ---- Distancia acumulada ----
      final newTotalDistance = totalDistanceMeters + distanceMeters;
      _postTxNewTotalDistance = newTotalDistance;

      tx.update(docRef, {
        'points': newPoints,
        'level': computedLevel,
        'totalDistanceMeters': newTotalDistance,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return reward;
    });

    // Post-TX: recalcular unlocks desde /app_config/current + /packs + /packs/{id}/loops
    try {
      if (_postTxNewTotalDistance != null) {
        final unlock = UnlockService(_db, cache: CacheService());
        await unlock.syncForUser(uid: uid, totalDistanceMeters: _postTxNewTotalDistance);
      }
    } catch (e) {
      // ignore: avoid_print
      print('[UserRepository] Unlock sync error: $e');
    }

    return reward;
  }
}
