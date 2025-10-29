import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/step_service_fft.dart';
import '../services/audio_loop_service.dart';

class GameScreen extends StatefulWidget {
  final int initialBpm;
  final int initialSteps;
  final StepServiceFFT stepService;

  const GameScreen({
    super.key,
    required this.initialBpm,
    required this.initialSteps,
    required this.stepService,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  // ----- estado crudo que viene del sensor -----
  int _rawBpm = 0;
  int _steps = 0;

  // ----- estado filtrado / estable -----
  // lo que mostramos, lo que usamos para audio y combo
  int _stableBpm = 0;

  // ventana de bpm recientes para filtrar ruido
  final List<int> _bpmWindow = [];
  static const int _bpmWinSize = 7; // ~últimos ticks (~1s aprox)

  // combo / feedback
  bool _inRhythm = false;
  int _syncTicks = 0;
  int _maxCombo = 0;

  // ciclo de vida / navegación
  bool _navigatingOut = false;
  bool _disposedOrExiting = false;

  late final AudioLoopService _audioLoopService;

  @override
  void initState() {
    super.initState();

    _rawBpm = widget.initialBpm;
    _stableBpm = widget.initialBpm;
    _steps = widget.initialSteps;

    _audioLoopService = AudioLoopService();
    _audioLoopService.init().then((_) {
      // arrancamos el loop con el bpm ya estabilizado
      _audioLoopService.updateLoopForBpm(_stableBpm);
    });

    // primer cálculo de estado de ritmo / combo
    _recalcRhythmAndCombo();

    // redirigimos el listener del servicio de pasos
    widget.stepService.updateListener((bpmCrudo, stepsNow) {
      if (!mounted || _disposedOrExiting) return;

      setState(() {
        _rawBpm = bpmCrudo;
        _steps = stepsNow;

        // 1. acumulamos ventana
        _pushBpmSample(bpmCrudo);

        // 2. recalculamos el bpm filtrado estable
        _stableBpm = _computeStableBpm();

        // 3. actualizamos combo/ritmo con ese bpm estable
        _recalcRhythmAndCombo();
      });

      // 4. también usamos el bpm estable para decidir loop musical
      _audioLoopService.updateLoopForBpm(_stableBpm);
    });
  }

  // guarda un nuevo bpm en la ventana y controla tamaño
  void _pushBpmSample(int val) {
    // ignorar bpm totalmente ridículos que a veces mete ruido inicial
    if (val < 30 || val > 240) return;

    _bpmWindow.add(val);
    if (_bpmWindow.length > _bpmWinSize) {
      _bpmWindow.removeAt(0);
    }
  }

  // calcula bpm estable
  //
  // pasos:
  // 1. si hay pocos datos, devolvemos el último crudo.
  // 2. tiramos outliers fuertes dentro de la ventana (saltos locos).
  // 3. sacamos la mediana.
  // 4. cuantizamos para que el número no parpadee: lo llevamos de a 2 bpm.
  //
  int _computeStableBpm() {
    if (_bpmWindow.isEmpty) {
      return _rawBpm;
    }

    // copia local
    final samples = List<int>.from(_bpmWindow);

    // limpiamos outliers groseros basados en la mediana preliminar
    samples.sort();
    final medianPre = samples[samples.length ~/ 2];

    final cleaned = samples.where((b) {
      final diff = (b - medianPre).abs();
      // si un valor se va MUCHO (ej 20 bpm lejos) lo ignoramos
      return diff <= 20;
    }).toList();

    if (cleaned.isEmpty) {
      // si limpiamos demasiado agresivo, fallback a medianPre
      return _quantizeBpm(medianPre);
    }

    cleaned.sort();
    final median = cleaned[cleaned.length ~/ 2];

    return _quantizeBpm(median);
  }

  // hace que el número no cambie 1-1-1 cada frame
  // podés cambiar a /5 *5 si querés bloques de a 5 BPM
  int _quantizeBpm(int bpm) {
    final quantized = (bpm / 2).round() * 2;
    return quantized;
  }

  // checkea si un bpm cae en algún bucket válido de caminar
  bool _isInWalkingRange(int bpm) {
    for (final bucket in walkingBuckets) {
      if (bucket.contains(bpm)) {
        return true;
      }
    }
    return false;
  }

  // actualiza _inRhythm, el combo y registra el combo máximo
  void _recalcRhythmAndCombo() {
    final inside = _isInWalkingRange(_stableBpm);

    if (inside) {
      _syncTicks++;
      if (_syncTicks > _maxCombo) {
        _maxCombo = _syncTicks;
      }
    } else {
      _syncTicks = 0;
    }

    _inRhythm = inside;
  }

  Future<void> _finishSessionAndExit() async {
    if (_navigatingOut || !mounted) return;
    _navigatingOut = true;
    _disposedOrExiting = true;

    // apagamos sensores
    widget.stepService.disposeService();

    // apagamos audio
    await _audioLoopService.stop();
    await _audioLoopService.dispose();

    // en el futuro acá podríamos guardar:
    // _steps, _maxCombo, duración, bpm medio, etc.

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.go('/home');
    });
  }

  @override
  void dispose() {
    _disposedOrExiting = true;

    if (!_navigatingOut) {
      widget.stepService.disposeService();
      _audioLoopService.stop();
      _audioLoopService.dispose();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        await _finishSessionAndExit();
        return false;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF05050A),
        appBar: AppBar(
          title: Text(
            'StepSync',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
          automaticallyImplyLeading: true,
        ),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 30),
              _buildBpmCard(),
              const SizedBox(height: 24),
              _buildComboHint(),
              const Spacer(),
              _buildEndSessionButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBpmCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF1F1F2E), Color(0xFF12121B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ritmo detectado',
            style: GoogleFonts.nunito(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),

          // mostramos el BPM estable, no el crudo
          Text(
            '$_stableBpm BPM',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 44,
              fontWeight: FontWeight.w700,
            ),
          ),

          const SizedBox(height: 12),
          Text(
            'Pasos: $_steps',
            style: GoogleFonts.nunito(
              color: Colors.white60,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComboHint() {
    final bool good = _inRhythm;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: good
              ? const [Color(0xFF42C86D), Color(0xFF2D978C)]
              : const [Color(0xFFFF6464), Color(0xFFB23A48)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: (good
                ? const Color(0xFF42C86D)
                : const Color(0xFFFF6464))
                .withOpacity(0.35),
            blurRadius: 18,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // combo en vivo usando ritmo estable
          Text(
            good ? '¡Combo x$_syncTicks!' : 'Fuera de ritmo',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            good
                ? 'Mantené la cadencia para subir el combo.\nMáx: x$_maxCombo'
                : 'Volvé al rango objetivo para reactivar el combo.',
            style: GoogleFonts.nunito(
              color: Colors.white,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEndSessionButton() {
    return GestureDetector(
      onTap: _finishSessionAndExit,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            colors: [Color(0xFF42C86D), Color(0xFF2D978C)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF42C86D).withOpacity(0.4),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Center(
          child: Text(
            'Finalizar sesión',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
