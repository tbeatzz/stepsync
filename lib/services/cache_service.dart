import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class CacheService {
  static const _kContentVersion = 'content_version';

  static const _kAppConfig = 'app_config_json';
  static const _kPacks = 'packs_json';
  static const _kLoopsPrefix = 'loops_json_'; // + packId

  // opcional: timestamps
  static const _kAppConfigAt = 'app_config_cached_at';
  static const _kPacksAt = 'packs_cached_at';
  static const _kLoopsAtPrefix = 'loops_cached_at_'; // + packId

  // -------------------------
  // content version
  // -------------------------
  Future<int?> getContentVersion() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getInt(_kContentVersion);
  }

  Future<void> setContentVersion(int version) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setInt(_kContentVersion, version);
  }

  /// Si cambia el contentVersion -> borra packs/loops cacheados
  Future<void> syncContentVersion(int newVersion) async {
    final sp = await SharedPreferences.getInstance();
    final old = sp.getInt(_kContentVersion);

    if (old == null) {
      await sp.setInt(_kContentVersion, newVersion);
      return;
    }

    if (old != newVersion) {
      // invalidate pesado
      await _clearAllLoopsInternal(sp);
      await sp.remove(_kPacks);
      await sp.remove(_kPacksAt);

      // guardamos versión nueva
      await sp.setInt(_kContentVersion, newVersion);
    }
  }

  // -------------------------
  // app_config/current cache
  // -------------------------
  Future<void> setAppConfigRaw(Map<String, dynamic> cfg) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kAppConfig, jsonEncode(cfg));
    await sp.setInt(_kAppConfigAt, DateTime.now().millisecondsSinceEpoch);

    // si viene contentVersion dentro del map, intentamos sync automático
    final cv = cfg['contentVersion'];
    if (cv is int) {
      await syncContentVersion(cv);
    } else if (cv is num) {
      await syncContentVersion(cv.toInt());
    }
  }

  Future<Map<String, dynamic>?> getAppConfigRaw() async {
    final sp = await SharedPreferences.getInstance();
    final s = sp.getString(_kAppConfig);
    if (s == null) return null;

    final decoded = jsonDecode(s);
    if (decoded is! Map) return null;

    return (decoded as Map).cast<String, dynamic>();
  }

  // -------------------------
  // packs cache
  // -------------------------
  Future<void> setPacksRaw(List<Map<String, dynamic>> packs) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kPacks, jsonEncode(packs));
    await sp.setInt(_kPacksAt, DateTime.now().millisecondsSinceEpoch);
  }

  Future<List<Map<String, dynamic>>?> getPacksRaw() async {
    final sp = await SharedPreferences.getInstance();
    final s = sp.getString(_kPacks);
    if (s == null) return null;

    final decoded = jsonDecode(s);
    if (decoded is! List) return null;

    return decoded.map((e) => (e as Map).cast<String, dynamic>()).toList();
  }

  // -------------------------
  // loops cache por packId
  // -------------------------
  String _loopsKey(String packId) => '$_kLoopsPrefix$packId';
  String _loopsAtKey(String packId) => '$_kLoopsAtPrefix$packId';

  Future<void> setLoopsRaw(String packId, List<Map<String, dynamic>> loops) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_loopsKey(packId), jsonEncode(loops));
    await sp.setInt(_loopsAtKey(packId), DateTime.now().millisecondsSinceEpoch);
  }

  Future<List<Map<String, dynamic>>?> getLoopsRaw(String packId) async {
    final sp = await SharedPreferences.getInstance();
    final s = sp.getString(_loopsKey(packId));
    if (s == null) return null;

    final decoded = jsonDecode(s);
    if (decoded is! List) return null;

    return decoded.map((e) => (e as Map).cast<String, dynamic>()).toList();
  }

  // -------------------------
  // clear helpers
  // -------------------------
  Future<void> clearAll() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_kContentVersion);
    await sp.remove(_kAppConfig);
    await sp.remove(_kAppConfigAt);
    await sp.remove(_kPacks);
    await sp.remove(_kPacksAt);
    await _clearAllLoopsInternal(sp);
  }

  Future<void> clearLoopsForPack(String packId) async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_loopsKey(packId));
    await sp.remove(_loopsAtKey(packId));
  }

  Future<void> _clearAllLoopsInternal(SharedPreferences sp) async {
    final keys = sp.getKeys();
    final loopKeys = keys.where((k) => k.startsWith(_kLoopsPrefix)).toList();
    final atKeys = keys.where((k) => k.startsWith(_kLoopsAtPrefix)).toList();

    for (final k in loopKeys) {
      await sp.remove(k);
    }
    for (final k in atKeys) {
      await sp.remove(k);
    }
  }
}
