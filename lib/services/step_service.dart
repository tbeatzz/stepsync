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
  final int _maxIntervals = 6;
  final double _thresholdOffset = 0.7; // puede ajustar
  final int _minStepIntervalMs = 300; // mínimo tiempo entre pasos validos (ms)

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

    // Media móvil de magnitudes
    double sum = _recentMagnitudes.reduce((a, b) => a + b);
    double avg = sum / _recentMagnitudes.length;
    double latest = _recentMagnitudes.last;

    // Comparar si está lo suficientemente por encima del promedio local
    return latest > avg + _thresholdOffset;
  }

  void _calculateBpm() {
    final now = DateTime.now();
    if (_lastStepTime != null) {
      final diff = now.difference(_lastStepTime!).inMilliseconds;

      // Validar que el intervalo esté en rango aceptable
      if (diff > _minStepIntervalMs && diff < 3000) {
        _intervals.add(diff);
        if (_intervals.length > _maxIntervals) {
          _intervals.removeAt(0);
        }

        // Promediar intervalos
        double sum = _intervals.fold<int>(0, (a, b) => a + b).toDouble();
        double avg = sum / _intervals.length;

        int bpm = (60000 / avg).round();
        onBpmUpdated(bpm);

      }
    }
    _lastStepTime = now;
  }

  void stopListening() {

  }
}
