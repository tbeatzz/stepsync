import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class RemoteLoopEntry {
  final String id; // ej: loop_80_rock
  final int bpmMin;
  final int bpmMax;
  final String url;

  RemoteLoopEntry({
    required this.id,
    required this.bpmMin,
    required this.bpmMax,
    required this.url,
  });
}

class AudioLoopService {


  // ========== PLAYERS (para smooth switch) ==========
  final AudioPlayer _a = AudioPlayer();
  final AudioPlayer _b = AudioPlayer();
  AudioPlayer _active = AudioPlayer();   // se setea en init()
  AudioPlayer _inactive = AudioPlayer(); // se setea en init()

  bool _inited = false;

  // ========== CONFIG ==========
  String _selectedPack = 'base';
  Set<String> _unlockedLoops = <String>{};

  bool _remoteEnabled = false;
  Map<String, List<RemoteLoopEntry>> _remoteByPack = {}; // packId -> loops

  // ========== (1) THROTTLE / BUCKET / DEDUPE ==========
  static const Duration _switchCooldown = Duration(milliseconds: 700);
  static const Duration _debounceDelay = Duration(milliseconds: 250);
  static const int _bpmBucket = 10; // 👈 10bpm (podés poner 5)

  Timer? _debounceTimer;
  DateTime _lastSwitchAt = DateTime.fromMillisecondsSinceEpoch(0);

  String? _currentKey; // clave lógica del loop actual (ej: "pack:rock|id:loop_80_rock")
  int _switchGen = 0;

  // ========== (2) CACHE REMOTO A DISCO ==========
  Directory? _cacheDir;
  final Map<String, String> _urlToFilePath = {}; // url -> filePath
  final Set<String> _downloading = <String>{};

  // ==================================================
  Future<void> init() async {
    if (_inited) return;
    _inited = true;

    _active = _a;
    _inactive = _b;

    _cacheDir = await _ensureCacheDir();

    // setup players base
    await _a.setLoopMode(LoopMode.one);
    await _b.setLoopMode(LoopMode.one);
  }

  Future<void> dispose() async {
    _debounceTimer?.cancel();
    await _a.dispose();
    await _b.dispose();
  }

  Future<void> stop() async {
    try { await _a.stop(); } catch (_) {}
    try { await _b.stop(); } catch (_) {}
  }

  void configurePack({
    required String selectedPack,
    required List<String> unlockedLoops,
  }) {
    _selectedPack = selectedPack.trim().isEmpty ? 'base' : selectedPack.trim();
    _unlockedLoops = unlockedLoops.toSet();
  }

  void configureRemote({
    required bool enabled,
    required Map<String, List<RemoteLoopEntry>> loopsByPack,
  }) {
    _remoteEnabled = enabled;
    _remoteByPack = loopsByPack;

    // debug
    final counts = <String, int>{};
    loopsByPack.forEach((k, v) => counts[k] = v.length);
    // ignore: avoid_print
    print('[AudioLoopService] remoteEnabled=$_remoteEnabled counts=$counts');
  }

  // ==================================================
  // (2) Warmup: baja los loops del pack a disco (5 archivos)
  // Llamalo al entrar al GameScreen (base + pack actual).
  // ==================================================
  Future<void> warmupRemoteCache({
    required String packId,
    bool includeBase = true,
  }) async {
    if (!_remoteEnabled) return;

    final toWarm = <String>{};
    if (includeBase) toWarm.add('base');
    toWarm.add(packId);

    for (final p in toWarm) {
      final list = _remoteByPack[p] ?? const <RemoteLoopEntry>[];
      for (final e in list) {
        // Best-effort: descarga y guarda si no está
        await _ensureDownloaded(e.url);
      }
    }
  }

  // ==================================================
  // API principal: se llama cuando cambia el BPM
  // ==================================================
  void updateLoopForBpm(int bpm) {
    if (!_inited) return;

    final int quantBpm = _quantizeBpm(bpm);              // (1) bucket
    final desired = _pickDesiredLoopKey(quantBpm);       // pack+id o local asset

    // dedupe (si no cambia, no hacemos nada)
    if (desired == _currentKey) return;

    // debounce (evita spam si BPM tiembla)
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceDelay, () {
      _trySwitch(desired, quantBpm);
    });
  }

  // ==================================================
  // (1) bucket BPM
  // ==================================================
  int _quantizeBpm(int bpm) {
    if (bpm <= 0) return 0;
    return (bpm / _bpmBucket).round() * _bpmBucket;
  }

  // ==================================================
  // Lógica de selección:
  // - Si remoto enabled y hay loops del pack unlocked -> usa ese pack
  // - sino base
  // - si remoto no -> local asset base (tu fallback)
  // ==================================================
  String _pickDesiredLoopKey(int bpm) {
    // si bpm inválido, fallback
    if (bpm <= 0) return 'local:assets/audio/loop_80.wav';

    final pack = _effectivePackForPlayback();

    if (_remoteEnabled) {
      final list = _remoteByPack[pack] ?? const <RemoteLoopEntry>[];
      if (list.isNotEmpty) {
        final e = _pickRemoteEntry(list, bpm);
        return 'remote:pack=$pack|url=${e.url}|id=${e.id}|min=${e.bpmMin}|max=${e.bpmMax}';
      }
      // si pack está vacío -> probamos base
      final base = _remoteByPack['base'] ?? const <RemoteLoopEntry>[];
      if (base.isNotEmpty) {
        final e = _pickRemoteEntry(base, bpm);
        return 'remote:pack=base|url=${e.url}|id=${e.id}|min=${e.bpmMin}|max=${e.bpmMax}';
      }
    }

    // fallback local base (como ya venías)
    final localAsset = _localAssetForBpm(bpm);
    return 'local:$localAsset';
  }

  String _effectivePackForPlayback() {
    if (_selectedPack == 'base') return 'base';

    // criterio: si tenés alguna key que termina en _pack => pack “habilitado”
    final ok = _unlockedLoops.any((k) => k.endsWith('_$_selectedPack'));
    if (!ok) return 'base';

    // y además debe existir remoteByPack (si no, igual cae a base)
    return _selectedPack;
  }

  RemoteLoopEntry _pickRemoteEntry(List<RemoteLoopEntry> list, int bpm) {
    // 1) el que contiene bpm
    for (final e in list) {
      if (bpm >= e.bpmMin && bpm <= e.bpmMax) return e;
    }
    // 2) si ninguno contiene -> el más cercano por centro
    RemoteLoopEntry best = list.first;
    int bestDist = 1 << 30;
    for (final e in list) {
      final center = ((e.bpmMin + e.bpmMax) / 2).round();
      final d = (center - bpm).abs();
      if (d < bestDist) {
        bestDist = d;
        best = e;
      }
    }
    return best;
  }

  String _localAssetForBpm(int bpm) {
    // map simple: 70/80/90/100/110 por cercanía
    final buckets = [70, 80, 90, 100, 110];
    int best = buckets.first;
    int dist = 1 << 30;
    for (final b in buckets) {
      final d = (b - bpm).abs();
      if (d < dist) { dist = d; best = b; }
    }
    return 'assets/audio/loop_$best.wav';
  }

  // ==================================================
  // (1) cooldown + (3) smooth switch + (2) cache
  // ==================================================
  Future<void> _trySwitch(String desiredKey, int bpm) async {
    // cooldown: si se switcheó hace poco, reprograma al final del cooldown
    final now = DateTime.now();
    final since = now.difference(_lastSwitchAt);
    if (since < _switchCooldown) {
      final wait = _switchCooldown - since;
      _debounceTimer?.cancel();
      _debounceTimer = Timer(wait, () => _trySwitch(desiredKey, bpm));
      return;
    }

    _lastSwitchAt = now;

    // subimos generación: todo lo viejo queda “cancelado”
    final int gen = ++_switchGen;

    // Si ahora ya coincide, no hacemos nada
    if (desiredKey == _currentKey) return;

    // Ejecuta switch “suave”: carga en el player inactivo, y swap cuando esté listo
    await _smoothSwitch(gen, desiredKey, bpm);
  }

  Future<void> _smoothSwitch(int gen, String desiredKey, int bpm) async {
    try {
      // 1) armar source
      final AudioSource source = await _buildSourceForKey(gen, desiredKey);

      // si fue cancelado por otro switch
      if (gen != _switchGen) return;

      // 2) preload en player inactivo SIN cortar el activo
      await _inactive.setAudioSource(source, preload: true);

      if (gen != _switchGen) return;

      // 3) empezar inactivo con volumen 0, luego crossfade
      await _inactive.setVolume(0.0);
      await _inactive.play();

      if (gen != _switchGen) return;

      await _crossFade(from: _active, to: _inactive, ms: 260);

      if (gen != _switchGen) return;

      // 4) parar el viejo y swap active/inactive
      try { await _active.stop(); } catch (_) {}

      final tmp = _active;
      _active = _inactive;
      _inactive = tmp;

      _currentKey = desiredKey;

      // debug
      // ignore: avoid_print
      print('[AudioLoopService] SWITCH OK -> $desiredKey (bpm=$bpm)');
    } catch (e) {
      // “Loading interrupted / abort” suele pasar cuando hubo otro switch encima.
      // Si esta gen ya no es la actual, ignoramos.
      if (gen != _switchGen) return;

      // ignore: avoid_print
      print('[AudioLoopService][ERROR] smoothSwitch failed: $e');
    }
  }

  Future<void> _crossFade({
    required AudioPlayer from,
    required AudioPlayer to,
    int ms = 250,
  }) async {
    const steps = 10;
    final stepMs = max(10, (ms / steps).round());
    for (int i = 0; i <= steps; i++) {
      final t = i / steps;
      final vTo = t;
      final vFrom = 1.0 - t;
      try { await to.setVolume(vTo); } catch (_) {}
      try { await from.setVolume(vFrom); } catch (_) {}
      await Future.delayed(Duration(milliseconds: stepMs));
    }
    try { await from.setVolume(1.0); } catch (_) {}
    try { await to.setVolume(1.0); } catch (_) {}
  }

  // ==================================================
  // Construye AudioSource:
  // - remote: intenta file cache, sino URL
  // - local: asset
  // ==================================================
  Future<AudioSource> _buildSourceForKey(int gen, String key) async {
    if (key.startsWith('local:')) {
      final asset = key.substring('local:'.length);
      // debug
      // ignore: avoid_print
      print('[AudioLoopService] START -> LOCAL $asset');
      return AudioSource.uri(Uri.parse('asset:///$asset'));
    }

    if (key.startsWith('remote:')) {
      // parse url
      final urlPart = key.split('|').firstWhere((p) => p.startsWith('url='), orElse: () => '');
      final url = urlPart.replaceFirst('url=', '').trim();

      // debug
      // ignore: avoid_print
      print('[AudioLoopService] START -> REMOTE $key');

      // (2) cache a file si se puede
      final filePath = await _ensureDownloaded(url);

      if (gen != _switchGen) {
        // si fue cancelado
        throw Exception('cancelled');
      }

      if (filePath != null) {
        return AudioSource.file(filePath);
      }

      // si no se pudo cachear, reproducimos por URL directo
      return AudioSource.uri(Uri.parse(url));
    }

    // fallback
    return AudioSource.uri(Uri.parse('asset:///assets/audio/loop_80.wav'));
  }

  // ==================================================
  // Cache helpers
  // ==================================================
  Future<Directory> _ensureCacheDir() async {
    final base = await getTemporaryDirectory();
    final dir = Directory('${base.path}/stepsync_audio_cache');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<String?> _ensureDownloaded(String url) async {
    if (url.isEmpty) return null;
    if (_cacheDir == null) return null;

    // ya está
    final cached = _urlToFilePath[url];
    if (cached != null && await File(cached).exists()) return cached;

    // evita duplicar downloads simultáneos
    if (_downloading.contains(url)) {
      // espera un poco y reintenta (best-effort)
      await Future.delayed(const Duration(milliseconds: 120));
      final again = _urlToFilePath[url];
      if (again != null && await File(again).exists()) return again;
      return null;
    }

    _downloading.add(url);
    try {
      final name = _safeFileName(url);
      final path = '${_cacheDir!.path}/$name';

      final f = File(path);
      if (await f.exists() && (await f.length()) > 0) {
        _urlToFilePath[url] = path;
        return path;
      }

      final resp = await http.get(Uri.parse(url));
      if (resp.statusCode >= 200 && resp.statusCode < 300 && resp.bodyBytes.isNotEmpty) {
        await f.writeAsBytes(resp.bodyBytes, flush: true);
        _urlToFilePath[url] = path;
        return path;
      }

      return null;
    } catch (_) {
      return null;
    } finally {
      _downloading.remove(url);
    }
  }

  String _safeFileName(String url) {
    // nombre estable sin chars raros (hash simple)
    final h = url.hashCode.abs();
    return 'loop_$h.bin';
  }
}
