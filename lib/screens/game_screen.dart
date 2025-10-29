import 'package:go_router/go_router.dart'; // arriba del file
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/step_service_fft.dart';

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
  bool _inRhythm = false;

  bool _navigatingOut = false; // evita doble tap al salir / pop en frame bloqueado
  bool _disposedOrExiting = false; // evita setState cuando ya nos vamos

  @override
  void initState() {
    super.initState();

    // Estado inicial heredado de la antesala
    _currentBpm = widget.initialBpm;
    _steps = widget.initialSteps;
    _updateRhythmState();

    // Redirigimos el listener del servicio a ESTA pantalla de juego
    widget.stepService.updateListener((bpm, steps) {
      if (!mounted || _disposedOrExiting) return;
      setState(() {
        _currentBpm = bpm;
        _steps = steps;
        _updateRhythmState();
      });
    });
  }

  void _updateRhythmState() {
    // Placeholder: en el futuro esto debería usar el "rango objetivo" según modo/tarea
    _inRhythm = _currentBpm >= 60;
  }

  Future<void> _finishSessionAndExit() async {
    if (_navigatingOut || !mounted) return;
    _navigatingOut = true;
    _disposedOrExiting = true;

    // Mata el servicio definitivamente
    widget.stepService.disposeService();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.go('/home'); // <- en vez de context.pop()
    });
  }


  @override
  void dispose() {
    // Si el usuario se fue de la pantalla con el botón "Finalizar sesión",
    // ya llamamos disposeService() ahí arriba.
    // Si se fue por otro motivo (ej. sistema hizo pop?), protegemos igual.
    _disposedOrExiting = true;
    if (!_navigatingOut) {
      // Salida "inesperada" -> igual cerramos la sesión
      widget.stepService.disposeService();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      // Interceptamos el back físico/flecha del AppBar igual que hicimos en SessionScreen
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
      duration: const Duration(milliseconds: 400),
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
            good ? '¡Combo activo!' : 'Busca el ritmo',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            good
                ? 'Mantén tu cadencia para sostener la música.'
                : 'Aumenta el paso hasta que detectemos tu compás objetivo.',
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
