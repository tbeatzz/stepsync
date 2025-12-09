import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class CacheService {
  static const _kContentVersion = 'content_version';
  static const _kPacks = 'packs_json';

  Future<int?> getContentVersion() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getInt(_kContentVersion);
  }

  Future<void> setContentVersion(int version) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setInt(_kContentVersion, version);
  }

  Future<void> setPacksRaw(List<Map<String, dynamic>> packs) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kPacks, jsonEncode(packs));
  }

  Future<List<Map<String, dynamic>>?> getPacksRaw() async {
    final sp = await SharedPreferences.getInstance();
    final s = sp.getString(_kPacks);
    if (s == null) return null;
    final decoded = jsonDecode(s);
    if (decoded is! List) return null;
    return decoded.map((e) => (e as Map).cast<String, dynamic>()).toList();
  }
}
