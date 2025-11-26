import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/step_service_fft.dart';
import '../services/audio_loop_service.dart';

import '../services/session_repository.dart';


class GameScreen extends StatefulWidget {
  final int initialBpm;
  final int initialSteps;
  final StepServiceFFT stepService;
  final String mode; // "Caminar", "Trotar" o "Correr"

  const GameScreen({
    super.key,
    required this.initialBpm,
    required this.initialSteps,
    required this.stepService,
    required this.mode,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {


  // ----- estado crudo que viene del sensor -----
  int _rawBpm = 0;
  int _steps = 0;

  // ----- estado filtrado / estable -----
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
  bool _cleanedUp = false; // 👈 nuevo

  late final AudioLoopService _audioLoopService;

  // 🔹 Nuevo: repo y tiempos de sesión
  final SessionRepository _sessionRepo = SessionRepository();
  late final DateTime _startTime;

  // 🔹 Nuevo: acumuladores para BPM promedio
  int _bpmSum = 0;
  int _bpmSamples = 0;

  // --------------- RANGOS POR MODO ---------------

  int get _targetMin {
    switch (widget.mode) {
      case 'Caminar':
        return 80;
      case 'Trotar':
        return 110;
      case 'Correr':
        return 130;
      default:
        return 80;
    }
  }

  int get _targetMax {
    switch (widget.mode) {
      case 'Caminar':
        return 115;
      case 'Trotar':
        return 135;
      case 'Correr':
        return 170;
      default:
        return 115;
    }
  }

  String get _modeLower =>
      widget.mode.toLowerCase(); // "caminar", "trotar", "correr"

  bool _isInTargetRange(int bpm) {
    if (bpm <= 0) return false;
    return bpm >= _targetMin && bpm <= _targetMax;
  }

  String get _tempoLabel {
    if (_stableBpm <= 0) {
      return 'Esperando ritmo...';
    }

    const margin = 5;

    if (_stableBpm < _targetMin - margin) {
      return 'Vas más lento que el objetivo de $_modeLower';
    }

    if (_stableBpm > _targetMax + margin) {
      return 'Vas más rápido que el objetivo de $_modeLower';
    }

    return '¡Estás en ritmo para $_modeLower!';
  }

  double get _tempoPosition {
    // valor normalizado para una barra 0..1
    if (_stableBpm <= 0) return 0;

    const globalMin = 60.0;
    const globalMax = 190.0;
    final clamped =
    _stableBpm.clamp(globalMin.toInt(), globalMax.toInt()).toDouble();
    return (clamped - globalMin) / (globalMax - globalMin);
  }

  @override
  void initState() {
    super.initState();

    _startTime = DateTime.now(); // 👈 inicio de sesión

    _rawBpm = widget.initialBpm;
    _stableBpm = widget.initialBpm;
    _steps = widget.initialSteps;

    if (_stableBpm > 0) {
      _bpmSum += _stableBpm;
      _bpmSamples++;
    }

    _audioLoopService = AudioLoopService();
    _audioLoopService.init().then((_) {
      _audioLoopService.updateLoopForBpm(_stableBpm);
    });

    _recalcRhythmAndCombo();

    widget.stepService.updateListener((bpmCrudo, stepsNow) {
      if (!mounted || _disposedOrExiting) return;

      setState(() {
        _rawBpm = bpmCrudo;
        _steps = stepsNow;

        _pushBpmSample(bpmCrudo);
        _stableBpm = _computeStableBpm();

        if (_stableBpm > 0) {
          _bpmSum += _stableBpm;
          _bpmSamples++;
        }

        _recalcRhythmAndCombo();
      });

      _audioLoopService.updateLoopForBpm(_stableBpm);
    });
  }


  // guarda un nuevo bpm en la ventana y controla tamaño
  void _pushBpmSample(int val) {
    if (val < 30 || val > 240) return;

    _bpmWindow.add(val);
    if (_bpmWindow.length > _bpmWinSize) {
      _bpmWindow.removeAt(0);
    }
  }

  int _computeStableBpm() {
    if (_bpmWindow.isEmpty) {
      return _rawBpm;
    }

    final samples = List<int>.from(_bpmWindow);

    samples.sort();
    final medianPre = samples[samples.length ~/ 2];

    final cleaned = samples.where((b) {
      final diff = (b - medianPre).abs();
      return diff <= 20;
    }).toList();

    if (cleaned.isEmpty) {
      return _quantizeBpm(medianPre);
    }

    cleaned.sort();
    final median = cleaned[cleaned.length ~/ 2];

    return _quantizeBpm(median);
  }

  int _quantizeBpm(int bpm) {
    final quantized = (bpm / 2).round() * 2;
    return quantized;
  }

  void _recalcRhythmAndCombo() {
    final inside = _isInTargetRange(_stableBpm);

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

  Future<void> _saveSessionIfNeeded() async {
    // Evitamos guardar 2 veces o guardar algo vacío
    if (_bpmSamples == 0 && _steps == 0) return;

    final endTime = DateTime.now();
    final avgBpm =
    _bpmSamples > 0 ? (_bpmSum / _bpmSamples).round() : _stableBpm;

    try {
      await _sessionRepo.saveSession(
        mode: widget.mode,
        steps: _steps,
        maxCombo: _maxCombo,
        avgBpm: avgBpm,
        startedAt: _startTime,
        endedAt: endTime,
      );
    } catch (e) {
      // Por ahora solo log, en el futuro podríamos mostrar snackbar
      // ignore: avoid_print
      print('[GameScreen] Error guardando sesión: $e');
    }
  }


  Future<void> _finishSessionAndExit() async {
    if (_navigatingOut || !mounted) return;

    _navigatingOut = true;
    _disposedOrExiting = true;

    // Guardamos sesión antes de salir
    await _saveSessionIfNeeded();

    // Navegamos a Home
    if (!mounted) return;
    context.go('/home');
  }



  @override
  void dispose() {
    _disposedOrExiting = true;

    // Limpiar servicios sólo una vez
    if (!_cleanedUp) {
      _cleanedUp = true;
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
            'StepSync – ${widget.mode}',
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
    final targetText = 'Objetivo: $_targetMin–$_targetMax BPM';

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
            'Modo: ${widget.mode}',
            style: GoogleFonts.nunito(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            targetText,
            style: GoogleFonts.nunito(
              color: Colors.white54,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),

          // BPM principal
          Text(
            _stableBpm > 0 ? '$_stableBpm BPM' : '-- BPM',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 44,
              fontWeight: FontWeight.w700,
            ),
          ),

          const SizedBox(height: 8),
          Text(
            'Pasos: $_steps',
            style: GoogleFonts.nunito(
              color: Colors.white60,
              fontSize: 18,
            ),
          ),

          const SizedBox(height: 16),

          // Texto de feedback de ritmo
          Text(
            _tempoLabel,
            style: GoogleFonts.nunito(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),

          const SizedBox(height: 12),

          // Pequeña barra que muestra posición del BPM en el rango global
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Container(
              height: 10,
              decoration: BoxDecoration(
                color: Colors.white12,
              ),
              child: Stack(
                children: [
                  // Zona objetivo
                  Positioned.fill(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        const globalMin = 60.0;
                        const globalMax = 190.0;
                        final width = constraints.maxWidth;

                        double start =
                            (_targetMin - globalMin) / (globalMax - globalMin);
                        double end =
                            (_targetMax - globalMin) / (globalMax - globalMin);

                        start = start.clamp(0.0, 1.0);
                        end = end.clamp(0.0, 1.0);

                        final leftPx = width * start;
                        final rightPx = width * end;

                        return Stack(
                          children: [
                            Positioned(
                              left: leftPx,
                              right: width - rightPx,
                              top: 0,
                              bottom: 0,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF42C86D),
                                      Color(0xFF2D978C)
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  // Marca de BPM actual
                  Positioned.fill(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final pos = _tempoPosition;
                        final x = constraints.maxWidth * pos;

                        return Align(
                          alignment: Alignment.centerLeft,
                          child: Transform.translate(
                            offset: Offset(x - 4, 0),
                            child: Container(
                              width: 8,
                              height: 10,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
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
                ? 'Mantené el ritmo de $_modeLower para subir el combo.\nMáx: x$_maxCombo'
                : 'Volvé al rango objetivo de $_modeLower para reactivar el combo.',
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
