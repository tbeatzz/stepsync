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
  late int _currentBpm;
  late int _steps;

  // estado de ritmo y combo
  bool _inRhythm = false;
  int _syncTicks = 0; // sube mientras mantenés el ritmo, se resetea si lo perdés

  bool _navigatingOut = false;
  bool _disposedOrExiting = false;

  late final AudioLoopService _audioLoopService;

  @override
  void initState() {
    super.initState();

    // Estado inicial heredado de la antesala
    _currentBpm = widget.initialBpm;
    _steps = widget.initialSteps;

    _audioLoopService = AudioLoopService();
    _audioLoopService.init().then((_) {
      // Apenas entramos al juego: disparar el loop correspondiente al BPM inicial
      _audioLoopService.updateLoopForBpm(_currentBpm);
    });

    // Calculamos inRhythm / combo inicial
    _updateRhythmState();

    // Redirigimos el listener del servicio de pasos a ESTA pantalla
    widget.stepService.updateListener((bpm, steps) {
      if (!mounted || _disposedOrExiting) return;

      setState(() {
        _currentBpm = bpm;
        _steps = steps;
        _updateRhythmState(); // también actualiza combo
      });

      // cada update de BPM también actualiza el loop musical
      _audioLoopService.updateLoopForBpm(bpm);
    });
  }

  /// Chequea si el bpm actual cae dentro de alguno de los buckets de caminar.
  /// Si sí, estás "en ritmo" para este modo.
  bool _isInWalkingRange(int bpm) {
    for (final bucket in walkingBuckets) {
      if (bucket.contains(bpm)) {
        return true;
      }
    }
    return false;
  }

  /// Actualiza:
  /// - _inRhythm (estás dentro de un rango válido o no)
  /// - _syncTicks (contador estilo combo)
  void _updateRhythmState() {
    final bool nowInRhythm = _isInWalkingRange(_currentBpm);

    if (nowInRhythm) {
      // seguimos dentro del rango -> sumamos combo
      _syncTicks++;
    } else {
      // nos fuimos de rango -> reseteamos combo
      _syncTicks = 0;
    }

    _inRhythm = nowInRhythm;
  }

  Future<void> _finishSessionAndExit() async {
    if (_navigatingOut || !mounted) return;
    _navigatingOut = true;
    _disposedOrExiting = true;

    // cortamos sensores
    widget.stepService.disposeService();

    // cortamos audio
    await _audioLoopService.stop();
    await _audioLoopService.dispose();

    // Volvemos al home
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.go('/home');
    });
  }

  @override
  void dispose() {
    _disposedOrExiting = true;

    // si el usuario se fue sin pasar por "Finalizar sesión", igual limpiamos
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
      // Interceptamos el back físico/flecha
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
          Text(
            '$_currentBpm BPM',
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
          // título dinámico: ya no es fijo "Combo activo!",
          // ahora mostramos el multiplicador real.
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
                ? 'Mantené la cadencia para subir el combo.'
                : 'Volvé al rango objetivo para reactivar la música.',
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
