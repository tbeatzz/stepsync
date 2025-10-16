import 'dart:async';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';

class StepService {
  final Function(int bpm) onBpmUpdated;

  int _stepCount = 0;
  DateTime? _lastStepTime;
  final List<int> _intervals = [];
  final List<double> _recentMagnitudes = [];

  final int _maxMagnitudes = 30;
  final int _maxIntervals = 10;
  final int _minStepIntervalMs = 300;
  final int _maxStepIntervalMs = 3000;

  double _thresholdOffset = 0.7;
  int _stableSteps = 0;
  int _currentBpm = 0;

  StepService({required this.onBpmUpdated});

  void startListening() {
    accelerometerEvents.listen((AccelerometerEvent event) {
      final double magnitude =
      sqrt(event.x * event.x + event.y * event.y + event.z * event.z);

      _recentMagnitudes.add(magnitude);
      if (_recentMagnitudes.length > _maxMagnitudes) {
        _recentMagnitudes.removeAt(0);
      }

      if (_isStepDetected()) {
        _stepCount++;
        _calculateBpm();
      }
    });
  }

  bool _isStepDetected() {
    if (_recentMagnitudes.length < 5) return false;

    final avg = _recentMagnitudes.reduce((a, b) => a + b) / _recentMagnitudes.length;
    final latest = _recentMagnitudes.last;

    // Umbral dinámico según estabilidad reciente
    final variance = _recentMagnitudes
        .map((v) => pow(v - avg, 2))
        .reduce((a, b) => a + b) / _recentMagnitudes.length;
    final stabilityFactor = variance < 1.0 ? 0.6 : 0.8;
    final dynamicThreshold = avg + _thresholdOffset * stabilityFactor;

    return latest > dynamicThreshold;
  }

  void _calculateBpm() {
    final now = DateTime.now();

    if (_lastStepTime != null) {
      final diff = now.difference(_lastStepTime!).inMilliseconds;

      if (diff > _minStepIntervalMs && diff < _maxStepIntervalMs) {
        _intervals.add(diff);
        if (_intervals.length > _maxIntervals) _intervals.removeAt(0);

        // Solo actualiza si hay pasos consistentes
        _stableSteps++;
        if (_stableSteps < 2) return;

        final avg = _intervals.fold<int>(0, (a, b) => a + b).toDouble() / _intervals.length;
        int newBpm = (60000 / avg).round();

        // 🔹 Filtro de salto abrupto (±25 %)
        if (_currentBpm != 0) {
          final diffBpm = (newBpm - _currentBpm).abs();
          if (diffBpm > _currentBpm * 0.25) {
            newBpm = _currentBpm +
                ((newBpm > _currentBpm)
                    ? (_currentBpm * 0.25).round()
                    : -(_currentBpm * 0.25).round());
          }
        }

        // 🔹 Suavizado exponencial
        _currentBpm = (_currentBpm * 0.7 + newBpm * 0.3).round();

        onBpmUpdated(_currentBpm);
      }
    }
    _lastStepTime = now;
  }

  void stopListening() {
    _recentMagnitudes.clear();
    _intervals.clear();
    _stableSteps = 0;
  }
}
