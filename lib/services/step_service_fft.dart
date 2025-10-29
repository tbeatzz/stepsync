import 'dart:async';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:scidart/numdart.dart';
import 'package:scidart/scidart.dart';

class StepServiceFFT {
  Function(int bpm, int steps) _onUpdate;
  final StreamController<String> debugStream = StreamController.broadcast();

  final List<double> _magnitudes = [];
  final int _windowSize = 256;

  Timer? _fftTimer;
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;

  int _currentBpm = 0;
  int _steps = 0;
  DateTime? _lastStepTime;

  StepServiceFFT({required Function(int bpm, int steps) onUpdate})
      : _onUpdate = onUpdate;

  /// Llamar cuando empieza la sesión física (antesala o juego)
  void startListening() {
    // Escuchamos el acelerómetro y vamos registrando magnitud de movimiento
    _accelerometerSubscription = accelerometerEvents.listen((event) {
      final double magnitude = sqrt(
        event.x * event.x +
            event.y * event.y +
            event.z * event.z,
      );

      _magnitudes.add(magnitude);
      if (_magnitudes.length > _windowSize) {
        _magnitudes.removeAt(0);
      }

      // Detección de paso simple
      if (_isStepDetected()) {
        final now = DateTime.now();
        if (_lastStepTime == null ||
            now.difference(_lastStepTime!).inMilliseconds > 300) {
          _steps++;
          _lastStepTime = now;

          // avisamos al listener actual
          _onUpdate(_currentBpm, _steps);

          // debug visual
          debugStream.add("👣 Paso detectado ($_steps)");
        }
      }
    });

    // FFT periódica para estimar BPM
    _fftTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _analyzeSignal();
    });
  }

  /// Cambiar dinámicamente quién recibe los updates.
  /// Esto nos permite que SessionScreen "suelte" y GameScreen "agarre".
  void updateListener(Function(int bpm, int steps) listener) {
    _onUpdate = listener;
  }

  /// Heurística de detección de paso
  bool _isStepDetected() {
    if (_magnitudes.length < 10) return false;

    double avg = _magnitudes.reduce((a, b) => a + b) / _magnitudes.length;
    double std = sqrt(
      _magnitudes
          .map((m) => pow(m - avg, 2))
          .reduce((a, b) => a + b) /
          _magnitudes.length,
    );

    double latest = _magnitudes.last;

    // sensibilidad adaptativa: cuando hay pocas muestras toleramos más ruido
    double sensitivity = _magnitudes.length < 150 ? 0.5 : 0.8;

    return latest > avg + std * sensitivity;
  }

  /// FFT para estimar cadencia y convertirla a BPM
  void _analyzeSignal() {
    if (_magnitudes.length < _windowSize ~/ 2) return;

    double mean = _magnitudes.reduce((a, b) => a + b) / _magnitudes.length;
    var centered = _magnitudes.map((m) => m - mean).toList();
    var signal = Array(centered);

    // Frecuencia de muestreo aprox del acelerómetro (puede tunearse)
    const double fs = 50.0;
    double freq = _freqFromFft(signal, fs);

    int bpm = (freq * 60).round();
    if (bpm < 30 || bpm > 240) return; // filtro de valores locos

    // suavizado para que no parpadee
    _currentBpm = (_currentBpm * 0.7 + bpm * 0.3).round();

    // notificamos al listener activo
    _onUpdate(_currentBpm, _steps);

    // debug info
    debugStream.add("📊 FFT detectó ${_currentBpm} BPM");
  }

  /// Obtiene la frecuencia dominante del movimiento usando FFT + interpolación parabólica
  double _freqFromFft(Array sig, double fs) {
    var windowed = sig * blackmanharris(sig.length);
    var f = rfft(windowed);
    var fAbs = arrayComplexAbs(f);

    if (fAbs.isEmpty) return 0;
    var i = arrayArgMax(fAbs);
    if (i <= 0 || i >= fAbs.length - 1) return 0;

    var result = parabolic(arrayLog(fAbs), i);
    if (result.isEmpty || result[0].isNaN) return 0;

    var true_i = result[0];
    if (true_i.isNaN) return 0;

    double freq = fs * true_i / windowed.length;

    // descartamos frecuencias inhumanas para caminar/trotar
    if (freq < 0.5 || freq > 4.0) return 0;

    return freq;
  }

  /// Frenar la captura de datos.
  /// Importante: NO cerramos debugStream acá, para que la otra pantalla
  /// (o futuras pantallas) puedan seguir mostrándolo si reutilizamos el servicio.
  void stopListening() {
    _fftTimer?.cancel();
    _accelerometerSubscription?.cancel();
    _magnitudes.clear();
  }

  /// Si en algún momento querés destruir TODO el servicio (fin de sesión),
  /// llamar a esto.
  void disposeService() {
    stopListening();
    debugStream.close();
  }
}
