import 'dart:ui';
import 'package:go_router/go_router.dart';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/step_service_fft.dart';
import 'game_screen.dart';

/// Estados de la sesión
enum SessionState {
  checkingPermissions,
  waitingMovement,
  collectingData,
  readyToPlay,
  error,
}

class SessionScreen extends StatefulWidget {
  final String mode;

  const SessionScreen({super.key, required this.mode});

  @override
  State<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends State<SessionScreen> {
  StepServiceFFT? _stepService;

  int currentBpm = 0;
  int steps = 0;

  bool measuring = false;

  bool permissionsGranted = false;
  bool checkingPermissions = true;

  bool _navigating = false;
  bool _keepServiceAlive = false;

  bool _disposedOrNavigating = false;

  // 🔹 Nuevo: estado de la sesión (Fase 2)
  SessionState _sessionState = SessionState.checkingPermissions;

  // 🔹 Nuevo: para decidir cuándo el BPM está “estable”
  int _nonZeroBpmCount = 0;
  static const int _minNonZeroBpmSamples = 3;

  @override
  void initState() {
    super.initState();
    _initSession();
  }

  Future<void> _initSession() async {
    if (!mounted) return;

    setState(() {
      checkingPermissions = true;
      _sessionState = SessionState.checkingPermissions;
      permissionsGranted = false;
      _nonZeroBpmCount = 0;
      measuring = false;
      currentBpm = 0;
      steps = 0;
    });

    // Pedimos permisos requeridos para detectar movimiento
    final activityStatus = await Permission.activityRecognition.request();
    final locationStatus = await Permission.location.request();

    if (!mounted) return;

    if (activityStatus.isGranted && locationStatus.isGranted) {
      setState(() {
        permissionsGranted = true;
        checkingPermissions = false;
        _sessionState = SessionState.waitingMovement;
      });

      _stepService = StepServiceFFT(onUpdate: (bpm, stepCount) {
        if (!mounted || _disposedOrNavigating) return;

        setState(() {
          currentBpm = bpm;
          steps = stepCount;
          measuring = bpm > 0;
        });

        _handleBpmUpdate(bpm);
      });

      _stepService!.startListening();
    } else {
      setState(() {
        permissionsGranted = false;
        checkingPermissions = false;
        _sessionState = SessionState.error;
      });
    }
  }

  // 🔹 Nuevo: función para manejar transición de estados según BPM
  void _handleBpmUpdate(int bpm) {
    if (bpm <= 0) return;

    // Si recién empezamos a recibir movimiento
    if (_sessionState == SessionState.waitingMovement) {
      setState(() {
        _sessionState = SessionState.collectingData;
      });
    }

    _nonZeroBpmCount++;

    // Cuando tenemos suficientes samples no-cero, consideramos listo
    if (_nonZeroBpmCount >= _minNonZeroBpmSamples &&
        _sessionState != SessionState.readyToPlay) {
      setState(() {
        _sessionState = SessionState.readyToPlay;
      });
    }
  }

  bool get _canEnterGame =>
      permissionsGranted &&
          _sessionState == SessionState.readyToPlay &&
          currentBpm > 0 &&
          !_navigating &&
          _stepService != null;

  @override
  void dispose() {
    _disposedOrNavigating = true;

    if (!_keepServiceAlive) {
      _stepService?.stopListening();
    }

    super.dispose();
  }

  void _goToGame() {
    if (!_canEnterGame || !mounted) {
      return;
    }

    _navigating = true;
    _disposedOrNavigating = true;
    _keepServiceAlive = true;

    // cinturón extra: que SessionScreen ya no reciba updates del servicio
    _stepService?.updateListener((_, __) {});

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      context
          .push(
        '/game',
        extra: {
          'initialBpm': currentBpm,
          'initialSteps': steps,
          'stepService': _stepService!,
          'mode': widget.mode, // 👈 mandamos el modo ("Caminar"/"Trotar"/"Correr")
        },
      )
          .then((_) {
        _navigating = false;
        _keepServiceAlive = false;
        _stepService = null;
        // No hacemos setState: esta pantalla queda “congelada”
      });
    });
  }

  Future<bool> _handleWillPop() async {
    if (_navigating || !mounted) return false;

    _disposedOrNavigating = true;
    _keepServiceAlive = false;
    _navigating = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
      _navigating = false;
    });

    return false;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _handleWillPop,
      child: Scaffold(
        backgroundColor: const Color(0xFF0D0C14),
        appBar: AppBar(
          title: Text(
            'Sesión en curso',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: Stack(
          children: [
            if (checkingPermissions)
              const Center(
                child: CircularProgressIndicator(
                  color: Colors.greenAccent,
                ),
              )
            else
              _buildSessionContent(),

            // Overlay blur si faltan permisos
            if (!checkingPermissions && !permissionsGranted)
              _buildPermissionPopup(),
          ],
        ),
      ),
    );
  }

  // ---------------------------------
  // CONTENIDO PRINCIPAL DE LA ANTESALA
  // ---------------------------------
  Widget _buildSessionContent() {
    // Texto según estado
    String helperText;
    switch (_sessionState) {
      case SessionState.checkingPermissions:
        helperText =
        'Revisando permisos para poder medir tu ritmo...';
        break;
      case SessionState.waitingMovement:
        helperText =
        'Comienza a caminar para que podamos calibrar tu ritmo.';
        break;
      case SessionState.collectingData:
        helperText =
        'Seguimos midiendo tu movimiento para estabilizar el BPM.';
        break;
      case SessionState.readyToPlay:
        helperText =
        '¡Gran ritmo! Mantente en movimiento para afinar la sesión.';
        break;
      case SessionState.error:
        helperText =
        'No pudimos obtener los permisos necesarios. Reintenta concederlos.';
        break;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        children: [
          const SizedBox(height: 30),
          _buildPulseIndicator(),
          const SizedBox(height: 40),

          // BPM actual
          Text(
            'BPM: $currentBpm',
            style: GoogleFonts.poppins(
              fontSize: 48,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 8),

          // Pasos actuales
          Text(
            'Pasos: $steps',
            style: GoogleFonts.nunito(
              color: Colors.white70,
              fontSize: 18,
            ),
          ),

          const SizedBox(height: 16),

          // Mensaje de calibración / feedback al jugador (usando state)
          Text(
            helperText,
            style: GoogleFonts.nunito(
              color: Colors.white60,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 40),

          // Panel de debug del sensor
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF15151E),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: StreamBuilder<String>(
                stream: _stepService?.debugStream.stream,
                builder: (context, snapshot) {
                  final data =
                      snapshot.data ?? 'Esperando datos del sensor...';
                  return SingleChildScrollView(
                    reverse: true,
                    child: Text(
                      data,
                      style: GoogleFonts.nunito(
                        color: const Color(0xFF42C86D),
                        fontSize: 14,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          const SizedBox(height: 40),

          _buildStartButton(),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // --------------------
  // POPUP DE PERMISOS
  // --------------------
  Widget _buildPermissionPopup() {
    return Positioned.fill(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          color: Colors.black.withOpacity(0.6),
          child: Center(
            child: Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
              margin: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A25),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.white.withOpacity(0.1),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.lock_outline,
                    size: 80,
                    color: Colors.redAccent,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Permisos necesarios',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Para que StepSync pueda detectar tus pasos y calcular tu ritmo, '
                        'necesita acceso a los sensores de movimiento y ubicación.',
                    style: GoogleFonts.nunito(
                      color: Colors.white70,
                      fontSize: 15,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 25),

                  // Botón "Conceder permisos"
                  GestureDetector(
                    onTap: () async {
                      if (!mounted) return;
                      setState(() {
                        checkingPermissions = true;
                      });
                      await _initSession();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                        horizontal: 50,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(30),
                        gradient: const LinearGradient(
                          colors: [Color(0xFF42C86D), Color(0xFF2D978C)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color:
                            const Color(0xFF42C86D).withOpacity(0.4),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Text(
                        'Conceder permisos',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --------------------
  // INDICADOR DE PULSO
  // --------------------
  Widget _buildPulseIndicator() {
    final active = _sessionState == SessionState.collectingData ||
        _sessionState == SessionState.readyToPlay;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 800),
      width: active ? 32 : 22,
      height: active ? 32 : 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: active
            ? const LinearGradient(
          colors: [Color(0xFF42C86D), Color(0xFF2D978C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        )
            : const LinearGradient(
          colors: [Colors.grey, Colors.black45],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: active
            ? [
          BoxShadow(
            color: const Color(0xFF42C86D).withOpacity(0.5),
            blurRadius: 15,
            spreadRadius: 4,
          ),
        ]
            : [],
      ),
    );
  }

  // --------------------
  // BOTÓN "ENTRAR AL JUEGO"
  // --------------------
  Widget _buildStartButton() {
    final bool enabled = _canEnterGame;

    String label;
    if (!permissionsGranted) {
      label = 'Esperando permisos...';
    } else if (_sessionState == SessionState.waitingMovement) {
      label = 'Comenzá a moverte';
    } else if (_sessionState == SessionState.collectingData) {
      label = 'Calibrando ritmo...';
    } else if (_sessionState == SessionState.readyToPlay) {
      label = 'Entrar al juego';
    } else {
      label = 'Entrar al juego';
    }

    return GestureDetector(
      onTap: enabled ? _goToGame : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding:
        const EdgeInsets.symmetric(vertical: 16, horizontal: 60),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          gradient: enabled
              ? const LinearGradient(
            colors: [Color(0xFF42C86D), Color(0xFF2D978C)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
              : const LinearGradient(
            colors: [Colors.grey, Colors.black38],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: enabled
              ? [
            BoxShadow(
              color: const Color(0xFF42C86D).withOpacity(0.4),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ]
              : [],
        ),
        child: Center(
          child: Text(
            label,
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
