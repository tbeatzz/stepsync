import 'dart:async';
import 'dart:math';

import 'package:sensors_plus/sensors_plus.dart';
import 'package:scidart/numdart.dart';
import 'package:scidart/scidart.dart';

class StepServiceFFT {
  // callback que escucha la UI (SessionScreen / GameScreen)
  Function(int bpm, int steps) _onUpdate;

  // debug stream para mostrar logs en pantalla
  final StreamController<String> debugStream = StreamController.broadcast();

  // buffer crudo de magnitudes del acelerómetro
  final List<double> _magnitudes = [];

  // ventana de análisis FFT (corta = responde más rápido)
  final int _windowSize = 128;

  // timestamps recientes de pasos detectados
  // los usamos para estimar cadencia instantánea
  final List<DateTime> _recentStepTimes = [];

  // timers / subscripciones
  Timer? _fftTimer;
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;

  // estado interno
  int _currentBpm = 0;
  int _steps = 0;
  DateTime? _lastStepTime;

  bool _listening = false;
  bool _disposed = false;

  StepServiceFFT({
    required Function(int bpm, int steps) onUpdate,
  }) : _onUpdate = onUpdate;

  // nos permite redirigir el listener cuando cambiamos de pantalla
  void updateListener(Function(int bpm, int steps) listener) {
    _onUpdate = listener;
  }

  void startListening() {
    if (_disposed || _listening) return;
    _listening = true;

    // escuchamos acelerómetro crudo
    _accelerometerSubscription = accelerometerEvents.listen((event) {
      final magnitude = sqrt(
        event.x * event.x +
            event.y * event.y +
            event.z * event.z,
      );

      _magnitudes.add(magnitude);
      if (_magnitudes.length > _windowSize) {
        _magnitudes.removeAt(0);
      }

      // detección de paso
      if (_isStepDetected()) {
        final now = DateTime.now();

        // anti-doble-detección muy rápida
        if (_lastStepTime == null ||
            now.difference(_lastStepTime!).inMilliseconds > 300) {
          _steps++;
          _lastStepTime = now;

          // guardamos timestamp para cadencia instantánea
          _recentStepTimes.add(now);
          if (_recentStepTimes.length > 8) {
            _recentStepTimes.removeAt(0); // nos quedamos con los últimos 8 pasos
          }

          // actualizamos BPM usando cadencia por pasos
          _updateBpmFromRecentSteps();

          // notificamos UI
          _notifyUpdate();
          debugStream.add("👣 Paso detectado ($_steps)");
        }
      }
    });

    // análisis FFT cada ~700ms
    _fftTimer = Timer.periodic(const Duration(milliseconds: 700), (_) {
      _analyzeSignalFft();
    });
  }

  // calcula si el último pico es paso
  bool _isStepDetected() {
    if (_magnitudes.length < 10) return false;

    final avg = _magnitudes.reduce((a, b) => a + b) / _magnitudes.length;
    final std = sqrt(
      _magnitudes
          .map((m) => pow(m - avg, 2))
          .reduce((a, b) => a + b) /
          _magnitudes.length,
    );

    final latest = _magnitudes.last;

    // sensibilidad dinámica como tenías
    final sensitivity = _magnitudes.length < 150 ? 0.5 : 0.8;
    return latest > avg + std * sensitivity;
  }

  // NUEVO:
  // estimamos bpm a partir de los últimos pasos detectados
  // esto responde rápido cuando cambiás de ritmo
  void _updateBpmFromRecentSteps() {
    if (_recentStepTimes.length < 2) return;

    // calculamos los intervalos entre pasos consecutivos (en ms)
    final List<int> intervalsMs = [];
    for (int i = 1; i < _recentStepTimes.length; i++) {
      final dt = _recentStepTimes[i]
          .difference(_recentStepTimes[i - 1])
          .inMilliseconds;
      intervalsMs.add(dt);
    }

    if (intervalsMs.isEmpty) return;

    // promedio del período entre pasos
    final avgIntervalMs =
        intervalsMs.reduce((a, b) => a + b) / intervalsMs.length;

    if (avgIntervalMs <= 0) return;

    // cadencia instantánea = 60000ms / período promedio
    final instantBpm = (60000.0 / avgIntervalMs).round();

    // descartamos valores locos
    if (instantBpm < 30 || instantBpm > 240) return;

    // mezcla: si estamos cambiando fuerte, reaccioná rápido
    if (_currentBpm == 0) {
      _currentBpm = instantBpm;
    } else {
      final diff = (instantBpm - _currentBpm).abs();
      // si cambió MUCHO el ritmo, saltá rápido
      const fastFactor = 0.8;
      // si cambió poquito, no marees al usuario
      const normalFactor = 0.4;

      final factor = diff >= 10 ? fastFactor : normalFactor;
      _currentBpm =
          (_currentBpm * (1 - factor) + instantBpm * factor).round();
    }

    debugStream.add("⚡ Cadencia pasos => ${_currentBpm} BPM");
  }

  // FFT: sirve de estabilizador / validación
  // se ejecuta periódicamente en paralelo
  void _analyzeSignalFft() {
    // necesitamos al menos media ventana
    if (_magnitudes.length < _windowSize ~/ 2) return;

    // centramos la señal
    final mean = _magnitudes.reduce((a, b) => a + b) / _magnitudes.length;
    final centered = _magnitudes.map((m) => m - mean).toList();
    final signal = Array(centered);

    // 🔁 calculamos sample rate estimada en vez de asumir 50 Hz fijo
    // estimación: medimos la duración real del buffer actual
    // suposición: _magnitudes se llena en tiempo real 1:1 con eventos del acelerómetro
    // - agarramos _recentStepTimes para tener una idea de tiempo real transcurrido
    // fallback si no hay suficientes pasos: seguimos usando ~50 Hz
    double fsEstimate = 50.0;
    if (_recentStepTimes.length >= 2) {
      final msWindow = _recentStepTimes.last
          .difference(_recentStepTimes.first)
          .inMilliseconds;
      // si entre el primer y último paso pasaron X ms,
      // y en ese mismo lapso juntamos N muestras en _magnitudes,
      // podemos aproximar la frecuencia real.
      if (msWindow > 0) {
        final secondsWindow = msWindow / 1000.0;
        final samplesWindow = min(_magnitudes.length, _windowSize).toDouble();
        final est = samplesWindow / secondsWindow;
        if (est > 20 && est < 100) {
          fsEstimate = est;
        }
      }
    }

    final freq = _freqFromFft(signal, fsEstimate);

    final fftBpm = (freq * 60).round();
    if (fftBpm < 30 || fftBpm > 240) return;

    // combinamos la estimación FFT con lo que ya tenemos
    // pero FFT es más "lenta", así que la usamos como empujón suave
    final diff = (fftBpm - _currentBpm).abs();
    const slowFactor = 0.25;
    const catchupFactor = 0.5;
    final factor = diff >= 15 ? catchupFactor : slowFactor;

    _currentBpm =
        (_currentBpm * (1 - factor) + fftBpm * factor).round();

    debugStream.add("📊 FFT refine => $_currentBpm BPM (fft:$fftBpm)");

    _notifyUpdate();
  }

  double _freqFromFft(Array sig, double fs) {
    final windowed = sig * blackmanharris(sig.length);
    final f = rfft(windowed);
    final fAbs = arrayComplexAbs(f);
    if (fAbs.isEmpty) return 0;

    var i = arrayArgMax(fAbs);
    if (i <= 0 || i >= fAbs.length - 1) return 0;

    final result = parabolic(arrayLog(fAbs), i);
    if (result.isEmpty || result[0].isNaN) return 0;

    final true_i = result[0];
    if (true_i.isNaN) return 0;

    final freq = fs * true_i / windowed.length;
    if (freq < 0.5 || freq > 4.0) return 0; // ~30-240 bpm
    return freq;
  }

  void _notifyUpdate() {
    _onUpdate(_currentBpm, _steps);
  }

  // detener sensores y timers (pero no cerrar stream todavía)
  void stopListening() {
    if (!_listening) return;
    _listening = false;

    _fftTimer?.cancel();
    _accelerometerSubscription?.cancel();

    _magnitudes.clear();
    _recentStepTimes.clear();
  }

  // destruir el servicio completamente
  void disposeService() {
    if (_disposed) return;
    _disposed = true;

    stopListening();
    debugStream.close();
  }
}
