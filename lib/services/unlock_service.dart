import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_config.dart';
import '../models/pack_def.dart';
import 'cache_service.dart';
import 'content_repository.dart';

class UnlockService {
  final FirebaseFirestore _db;
  final CacheService? _cache;

  UnlockService(this._db, {CacheService? cache}) : _cache = cache;

  static const List<String> _baseLoopKeys = <String>[
    'loop_70',
    'loop_80',
    'loop_90',
    'loop_100',
    'loop_110',
  ];

  Future<void> syncForUser({
    required String uid,
    double? totalDistanceMeters,
  }) async {
    final userRef = _db.collection('users').doc(uid);

    // 1) AppConfig (cache best-effort)
    final repo = ContentRepository(_db, cache: _cache);
    final AppConfig cfg = await repo.getAppConfigOnce();
    final client = cfg.clientConfig;
    final enabledPackIds = client.enabledPackIdsSorted();

    // 2) Packs activos del CMS
    List<PackDef> packs = const [];
    try {
      final q = await _db.collection('packs').where('active', isEqualTo: true).get();
      packs = q.docs.map((d) => PackDef.fromFirestore(d.id, d.data())).toList();
    } catch (e) {
      // ignore: avoid_print
      print('[UnlockService] WARN: no pude leer /packs: $e');
    }

    final Map<String, PackDef> packById = {for (final p in packs) p.id: p};

    await _db.runTransaction((tx) async {
      final snap = await tx.get(userRef);
      if (!snap.exists) return;

      final data = (snap.data() as Map<String, dynamic>?) ?? {};

      // totalDistanceMeters actual
      double currentTotalMeters = 0.0;
      final raw = data['totalDistanceMeters'];
      if (raw is int) currentTotalMeters = raw.toDouble();
      if (raw is double) currentTotalMeters = raw;

      final double meters = totalDistanceMeters ?? currentTotalMeters;
      final double km = meters / 1000.0;

      // selectedPack actual
      String selectedPack = (data['selectedPack'] as String?) ?? client.defaultPackId;
      if (selectedPack.trim().isEmpty) selectedPack = client.defaultPackId;
      if (selectedPack.trim().isEmpty) selectedPack = 'base';

      // ---- packs desbloqueados (solo para calcular loops; NO lo guardamos) ----
      final unlockedPackIds = <String>{'base'};

      final idsToConsider = enabledPackIds.isNotEmpty ? enabledPackIds : const <String>['base'];

      for (final packId in idsToConsider) {
        if (packId == 'base') continue;
        if (!client.isPackEnabled(packId)) continue;

        final p = packById[packId];
        if (p == null) continue; // enabled en config pero no existe/activo en CMS

        final t = p.unlock.type.toLowerCase().trim();

        if (t == 'free') {
          unlockedPackIds.add(packId);
          continue;
        }

        // Si en el futuro usás "distance", tu rules de packs hoy NO lo permite (ahora solo free/level/purchase).
        if (t == 'distance') {
          final thr = p.unlock.thresholdKm;
          if (thr != null && km >= thr) unlockedPackIds.add(packId);
          continue;
        }
      }

      // ---- unlockedLoops (esto es lo que usa tu app) ----
      final unlockedLoops = <String>{..._baseLoopKeys};

      for (final packId in unlockedPackIds) {
        if (packId == 'base') continue;
        for (final baseKey in _baseLoopKeys) {
          unlockedLoops.add('${baseKey}_$packId');
        }
      }

      // ---- normalizar selectedPack (y cumplir rule exists(/packs/{id})) ----
      String fallbackDefault = client.defaultPackId;
      if (!client.isPackEnabled(fallbackDefault) || (fallbackDefault != 'base' && !packById.containsKey(fallbackDefault))) {
        fallbackDefault = 'base';
      }

      // si el pack no existe/activo -> fallback
      if (selectedPack != 'base' && !packById.containsKey(selectedPack)) {
        selectedPack = fallbackDefault;
      }

      // si no está enabled -> fallback
      if (selectedPack != 'base' && !client.isPackEnabled(selectedPack)) {
        selectedPack = fallbackDefault;
      }

      // si no está desbloqueado -> fallback/base
      if (selectedPack != 'base' && !unlockedPackIds.contains(selectedPack)) {
        selectedPack = unlockedPackIds.contains(fallbackDefault) ? fallbackDefault : 'base';
      }

      tx.update(userRef, {
        'unlockedLoops': unlockedLoops.toList(),
        'selectedPack': selectedPack,
        'totalDistanceMeters': meters,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }
}
