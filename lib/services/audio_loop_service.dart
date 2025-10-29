import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

class BpmBucket {
  final int min;
  final int max;
  final String asset;

  const BpmBucket({
    required this.min,
    required this.max,
    required this.asset,
  });

  bool contains(int bpm) => bpm >= min && bpm <= max;
}

// Tus buckets actuales
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

  // Loop que está sonando ahora mismo
  String? _activeBucketAsset;

  // Loop candidato (el que "queremos" tocar si el nuevo ritmo se mantiene)
  String? _candidateBucketAsset;
  int? _candidateSinceMs;

  // Estabilidad / histeresis
  static const int minStableMs = 1200; // ms que tengo que sostener el nuevo bpm
  static const int exitMarginBpm = 2;  // tolerancia para salir de un bucket

  Future<void> init() async {
    if (_disposed || _initialized) return;
    _initialized = true;
    await _player.setLoopMode(LoopMode.one);
  }

  BpmBucket _bucketForWalking(int bpm) {
    for (final b in walkingBuckets) {
      if (b.contains(bpm)) return b;
    }
    return walkingBuckets.last;
  }

  bool _isClearlyOutsideActiveBucket(int bpm, BpmBucket active) {
    if (bpm < active.min - exitMarginBpm) return true;
    if (bpm > active.max + exitMarginBpm) return true;
    return false;
  }

  Future<void> updateLoopForBpm(int bpm) async {
    if (_disposed) return;
    if (!_initialized) {
      await init();
    }

    final nowMs = DateTime.now().millisecondsSinceEpoch;

    final desiredBucket = _bucketForWalking(bpm);
    final desiredAsset = desiredBucket.asset;

    // Caso inicial: no hay loop activo todavía
    if (_activeBucketAsset == null) {
      debugPrint('[AudioLoopService] START -> $desiredAsset (bpm=$bpm)');

      final ok = await _safePlayAsset(desiredAsset);
      if (ok) {
        _activeBucketAsset = desiredAsset;
        _candidateBucketAsset = null;
        _candidateSinceMs = null;
      } else {
        debugPrint('[AudioLoopService][WARN] no pude iniciar con $desiredAsset');
      }
      return;
    }

    // Ya hay loop activo
    final currentBucket = walkingBuckets.firstWhere(
          (b) => b.asset == _activeBucketAsset,
      orElse: () => walkingBuckets.first,
    );

    // ¿Seguimos casi dentro del bucket actual?
    final stillInActive = currentBucket.contains(bpm) ||
        !_isClearlyOutsideActiveBucket(bpm, currentBucket);

    if (stillInActive) {
      // Seguimos cómodos, descartamos candidato
      _candidateBucketAsset = null;
      _candidateSinceMs = null;
      return;
    }

    // Estamos claramente fuera del rango activo => queremos cambiar
    if (_candidateBucketAsset != desiredAsset) {
      // Nuevo candidato → empezamos a contar estabilidad
      _candidateBucketAsset = desiredAsset;
      _candidateSinceMs = nowMs;
      debugPrint('[AudioLoopService] candidate -> $desiredAsset (bpm=$bpm)');
      return;
    }

    // Mismo candidato → ¿ya sostuvo el ritmo suficiente tiempo?
    final stableForMs = nowMs - (_candidateSinceMs ?? nowMs);
    if (stableForMs >= minStableMs) {
      debugPrint('[AudioLoopService] SWITCH -> $_candidateBucketAsset '
          '(bpm=$bpm, stableFor=${stableForMs}ms)');

      final ok = await _safePlayAsset(_candidateBucketAsset!);
      if (ok) {
        _activeBucketAsset = _candidateBucketAsset;
      } else {
        debugPrint('[AudioLoopService][WARN] no pude reproducir '
            '${_candidateBucketAsset!}, me quedo en $_activeBucketAsset');
      }

      // en cualquier caso, reseteamos candidato
      _candidateBucketAsset = null;
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
      debugPrint('[AudioLoopService][ERROR] fallo al cargar $assetPath: $e');
      debugPrint('$st');
      return false;
    }
  }

  Future<void> stop() async {
    if (_disposed) return;
    try {
      await _player.stop();
    } catch (_) {}
    _activeBucketAsset = null;
    _candidateBucketAsset = null;
    _candidateSinceMs = null;
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    try {
      await _player.dispose();
    } catch (_) {}
  }
}
