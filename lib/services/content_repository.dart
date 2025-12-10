import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_config.dart';
import '../models/pack_def.dart';
import '../models/loop_def.dart';
import 'cache_service.dart';

class ContentRepository {
  final FirebaseFirestore _db;
  final CacheService? _cache;

  ContentRepository(this._db, {CacheService? cache}) : _cache = cache;

  // ---------------- STREAMS ----------------

  Stream<AppConfig> watchAppConfig() {
    return _db.doc('app_config/current').snapshots().map((snap) {
      final cfg = AppConfig.fromMap(snap.data());
      _cache?.setAppConfigRaw(cfg.toMap()); // esto también sincroniza contentVersion (si usás el CacheService que te pasé)
      return cfg;
    });
  }

  Stream<List<PackDef>> watchPacks() {
    return _db.collection('packs').orderBy('order').snapshots().map((q) {
      final packs = q.docs.map((d) => PackDef.fromFirestore(d.id, d.data())).toList();
      _cache?.setPacksRaw(q.docs.map((d) => {'id': d.id, ...d.data()}).toList());
      return packs;
    });
  }

  Stream<List<LoopDef>> watchLoops(String packId) {
    return _db.collection('packs').doc(packId).collection('loops').snapshots().map((q) {
      final loops = q.docs.map((d) => LoopDef.fromFirestore(d.id, d.data())).toList();
      _cache?.setLoopsRaw(packId, q.docs.map((d) => {'id': d.id, ...d.data()}).toList());
      return loops;
    });
  }

  // ---------------- GET ONCE ----------------

  Future<AppConfig> getAppConfigOnce() async {
    try {
      final snap = await _db.doc('app_config/current').get();
      final cfg = AppConfig.fromMap(snap.data());
      await _cache?.setAppConfigRaw(cfg.toMap());
      return cfg;
    } catch (_) {
      final cached = await _cache?.getAppConfigRaw();
      return AppConfig.fromMap(cached);
    }
  }

  Future<List<PackDef>> getPacksOnce() async {
    try {
      final q = await _db.collection('packs').orderBy('order').get();
      final packs = q.docs.map((d) => PackDef.fromFirestore(d.id, d.data())).toList();
      await _cache?.setPacksRaw(q.docs.map((d) => {'id': d.id, ...d.data()}).toList());
      return packs;
    } catch (_) {
      final cached = await _cache?.getPacksRaw();
      if (cached == null) return const [];
      return cached.map((m) {
        final id = (m['id'] ?? '') as String;
        final data = Map<String, dynamic>.from(m)..remove('id');
        return PackDef.fromFirestore(id, data);
      }).toList();
    }
  }

  Future<List<LoopDef>> getLoopsOnce(String packId) async {
    try {
      final q = await _db.collection('packs').doc(packId).collection('loops').get();
      final loops = q.docs.map((d) => LoopDef.fromFirestore(d.id, d.data())).toList();
      await _cache?.setLoopsRaw(packId, q.docs.map((d) => {'id': d.id, ...d.data()}).toList());
      return loops;
    } catch (_) {
      final cached = await _cache?.getLoopsRaw(packId);
      if (cached == null) return const [];
      return cached.map((m) {
        final id = (m['id'] ?? '') as String;
        final data = Map<String, dynamic>.from(m)..remove('id');
        return LoopDef.fromFirestore(id, data);
      }).toList();
    }
  }
}
