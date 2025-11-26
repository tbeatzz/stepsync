import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

class BpmBucket {
  final int min;
  final int max;
  final String asset; // asset base (pack "base")

  const BpmBucket({
    required this.min,
    required this.max,
    required this.asset,
  });

  bool contains(int bpm) => bpm >= min && bpm <= max;
}

// Buckets base (pack "base")
const walkingBuckets = [
  BpmBucket(min: 10,  max: 75,  asset: 'assets/audio/loop_70.wav'),
  BpmBucket(min: 76,  max: 85,  asset: 'assets/audio/loop_80.wav'),
  BpmBucket(min: 86,  max: 95,  asset: 'assets/audio/loop_90.wav'),
  BpmBucket(min: 96,  max: 105, asset: 'assets/audio/loop_100.wav'),
  BpmBucket(min: 106, max: 200, asset: 'assets/audio/loop_110.wav'),
];

class AudioLoopService {
  final AudioPlayer _player = AudioPlayer();

  bool _initialized = false;
  bool _disposed = false;

  // 🔹 Pack y loops desbloqueados
  //   selectedPack: "base" o "rap" (o lo que uses)
  //   unlockedLoopKeys: ej. ["loop_80_rap", "loop_90_rap"]
  String _selectedPack = 'base';
  Set<String> _unlockedLoopKeys = {};

  // 🔹 Estado de bucket activo/candidato (por índice en walkingBuckets)
  int? _activeBucketIndex;
  int? _candidateBucketIndex;
  int? _candidateSinceMs;

  // Solo para debug
  String? _currentAssetPath;

  // Estabilidad / histeresis
  static const int minStableMs = 1200; // ms que tengo que sostener el nuevo bpm
  static const int exitMarginBpm = 2;  // tolerancia para salir de un bucket

  /// Configuramos qué pack y qué loops tiene desbloqueados el jugador.
  /// Llamar ANTES de empezar a usar updateLoopForBpm en el GameScreen.
  void configurePack({
    required String selectedPack,
    required List<String> unlockedLoops,
  }) {
    _selectedPack = selectedPack;
    _unlockedLoopKeys = unlockedLoops.toSet();
    debugPrint(
      '[AudioLoopService] configurePack pack=$_selectedPack unlocked=$_unlockedLoopKeys',
    );
  }

  Future<void> init() async {
    if (_disposed || _initialized) return;
    _initialized = true;
    await _player.setLoopMode(LoopMode.one);
  }

  /// Devuelve el índice del bucket que corresponde a este BPM.
  int _indexForWalkingBucket(int bpm) {
    for (int i = 0; i < walkingBuckets.length; i++) {
      if (walkingBuckets[i].contains(bpm)) return i;
    }
    return walkingBuckets.length - 1;
  }

  BpmBucket _bucketForWalking(int bpm) {
    return walkingBuckets[_indexForWalkingBucket(bpm)];
  }

  bool _isClearlyOutsideActiveBucket(int bpm, BpmBucket active) {
    if (bpm < active.min - exitMarginBpm) return true;
    if (bpm > active.max + exitMarginBpm) return true;
    return false;
  }

  /// De "assets/audio/loop_80.wav" -> "loop_80"
  String _assetKeyFromAssetPath(String assetPath) {
    final reg = RegExp(r'([^/]+)\.wav$');
    final match = reg.firstMatch(assetPath);
    if (match != null) {
      return match.group(1)!;
    }
    return assetPath; // fallback bruto
  }

  /// Decide qué asset usar para un bucket, en función del pack.
  ///
  /// - Pack base → siempre loop_X base.
  /// - Otro pack (rap, etc.) → si está en unlockedLoopKeys usa loop_X_pack,
  ///   si no, fallback al base.
  String _resolveAssetForBucket(BpmBucket bucket) {
    final baseKey = _assetKeyFromAssetPath(bucket.asset); // ej "loop_80"

    // Pack base → siempre base
    if (_selectedPack == 'base') {
      return 'assets/audio/$baseKey.wav';
    }

    // Otro pack: ej. "rap" → "loop_80_rap"
    final altKey = '${baseKey}_$_selectedPack';
    if (_unlockedLoopKeys.contains(altKey)) {
      return 'assets/audio/$altKey.wav';
    }

    // Si el pack está seleccionado pero ese loop no está desbloqueado,
    // volvemos al base.
    return 'assets/audio/$baseKey.wav';
  }

  Future<void> updateLoopForBpm(int bpm) async {
    if (_disposed) return;
    if (!_initialized) {
      await init();
    }
    if (bpm <= 0) return;

    final nowMs = DateTime.now().millisecondsSinceEpoch;

    final desiredIndex = _indexForWalkingBucket(bpm);
    final desiredBucket = walkingBuckets[desiredIndex];
    final desiredAsset = _resolveAssetForBucket(desiredBucket);

    // Caso inicial: no hay loop activo todavía
    if (_activeBucketIndex == null) {
      debugPrint('[AudioLoopService] START -> $desiredAsset (bpm=$bpm)');
      final ok = await _safePlayAsset(desiredAsset);
      if (ok) {
        _activeBucketIndex = desiredIndex;
        _currentAssetPath = desiredAsset;
        _candidateBucketIndex = null;
        _candidateSinceMs = null;
      } else {
        debugPrint(
            '[AudioLoopService][WARN] no pude iniciar con $desiredAsset');
      }
      return;
    }

    // Ya hay loop activo
    final currentBucket = walkingBuckets[_activeBucketIndex!];

    // ¿Seguimos casi dentro del bucket actual?
    final stillInActive = currentBucket.contains(bpm) ||
        !_isClearlyOutsideActiveBucket(bpm, currentBucket);

    if (stillInActive) {
      // Seguimos cómodos, descartamos candidato
      _candidateBucketIndex = null;
      _candidateSinceMs = null;
      return;
    }

    // Estamos claramente fuera del rango activo => queremos cambiar
    if (_candidateBucketIndex != desiredIndex) {
      // Nuevo candidato → empezamos a contar estabilidad
      _candidateBucketIndex = desiredIndex;
      _candidateSinceMs = nowMs;
      debugPrint(
          '[AudioLoopService] candidate -> $desiredAsset (bpm=$bpm, bucketIndex=$desiredIndex)');
      return;
    }

    // Mismo candidato → ¿ya sostuvo el ritmo suficiente tiempo?
    final stableForMs = nowMs - (_candidateSinceMs ?? nowMs);
    if (stableForMs >= minStableMs) {
      final newBucket = walkingBuckets[_candidateBucketIndex!];
      final newAsset = _resolveAssetForBucket(newBucket);

      debugPrint(
          '[AudioLoopService] SWITCH -> $newAsset (bpm=$bpm, stableFor=${stableForMs}ms)');

      final ok = await _safePlayAsset(newAsset);
      if (ok) {
        _activeBucketIndex = _candidateBucketIndex;
        _currentAssetPath = newAsset;
      } else {
        debugPrint('[AudioLoopService][WARN] no pude reproducir $newAsset, '
            'me quedo en $_currentAssetPath');
      }

      // En cualquier caso, reseteamos candidato
      _candidateBucketIndex = null;
      _candidateSinceMs = null;
    } else {
      // Todavía no pasó el tiempo mínimo → seguimos esperando
    }
  }

  /// Intenta cargar y reproducir un asset.
  /// Devuelve true si salió bien, false si falló.
  Future<bool> _safePlayAsset(String assetPath) async {
    try {
      await _player.setAsset(assetPath);
      await _player.play();
      return true;
    } catch (e, st) {
      debugPrint(
          '[AudioLoopService][ERROR] fallo al cargar $assetPath: $e\n$st');
      return false;
    }
  }

  Future<void> stop() async {
    if (_disposed) return;
    try {
      await _player.stop();
    } catch (_) {}
    _activeBucketIndex = null;
    _candidateBucketIndex = null;
    _candidateSinceMs = null;
    _currentAssetPath = null;
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    try {
      await _player.dispose();
    } catch (_) {}
  }
}
