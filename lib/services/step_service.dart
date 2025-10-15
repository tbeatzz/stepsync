import 'dart:async';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';

class StepService {
  // Control del stream
  StreamSubscription? _subscription;

  // Valor actual del BPM calculado
  int currentBpm = 0;

  // Último timestamp en que se detectó un "paso"
  double _lastStepTime = 0;

  // Callback que notifica al UI cuando hay nuevo BPM
  final Function(int bpm)? onBpmUpdated;

  StepService({this.onBpmUpdated});

  /// Inicia la escucha del acelerómetro
  void startListening() {
    const double threshold = 1.2; // Sensibilidad: cuanto más bajo, más sensible
    final List<double> magnitudes = [];

    _subscription = userAccelerometerEvents.listen((event) {
      // Magnitud total del vector de aceleración
      double magnitude =
      sqrt(event.x * event.x + event.y * event.y + event.z * event.z);

      magnitudes.add(magnitude);

      // Si hay suficientes datos, procesamos
      if (magnitudes.length > 10) {
        // Detectar picos (movimientos bruscos)
        double avg = magnitudes.reduce((a, b) => a + b) / magnitudes.length;
        double peak = magnitudes.last;

        if (peak > avg + threshold) {
          double now = DateTime.now().millisecondsSinceEpoch / 1000.0;

          // Calculamos intervalo desde el último paso
          if (_lastStepTime != 0) {
            double diff = now - _lastStepTime;
            double bpm = 60.0 / diff;

            // Limitamos valores razonables
            if (bpm > 60 && bpm < 200) {
              currentBpm = bpm.round();
              onBpmUpdated?.call(currentBpm);
            }
          }

          _lastStepTime = now;
        }

        magnitudes.clear();
      }
    });
  }

  /// Detiene la escucha del sensor
  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
  }
}
