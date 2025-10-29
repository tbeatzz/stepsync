import 'dart:ui';
import 'package:go_router/go_router.dart'; // asegurate de tener esto arriba del file

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/step_service_fft.dart';
import 'game_screen.dart';




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

  /// Este flag sirve para:
  /// - bloquear futuros setState() cuando ya nos estamos yendo de la pantalla
  /// - evitar que el listener del servicio dispare actualizaciones visuales
  ///   durante la navegación (soluciona _debugLocked)
  bool _disposedOrNavigating = false;

  @override
  void initState() {
    super.initState();
    _initSession();
  }

  Future<void> _initSession() async {
    // Pedimos permisos requeridos para detectar movimiento
    final activityStatus = await Permission.activityRecognition.request();
    final locationStatus = await Permission.location.request();

    if (!mounted) return;

    if (activityStatus.isGranted && locationStatus.isGranted) {
      setState(() {
        permissionsGranted = true;
        checkingPermissions = false;
      });

      _stepService = StepServiceFFT(onUpdate: (bpm, stepCount) {
        // ⚠️ Protegemos contra setState() mientras salimos o ya estamos desmontados
        if (!mounted || _disposedOrNavigating) return;
        setState(() {
          currentBpm = bpm;
          steps = stepCount;
          measuring = true;
        });
      });

      _stepService!.startListening();
    } else {
      setState(() {
        permissionsGranted = false;
        checkingPermissions = false;
      });
    }
  }

  @override
  void dispose() {
    // Marcamos que esta pantalla ya no debería recibir más updates
    _disposedOrNavigating = true;

    // Si no estamos entregando el servicio al juego,
    // cortamos la captura de sensores acá.
    if (!_keepServiceAlive) {
      _stepService?.stopListening();
    }

    super.dispose();
  }

  /// Llamado cuando el usuario toca "Entrar al juego"
  void _goToGame() {
    // Evitamos spam / condiciones inválidas
    if (_navigating ||
        !mounted ||
        currentBpm <= 0 ||
        !permissionsGranted ||
        _stepService == null) {
      return;
    }

    _navigating = true;
    _disposedOrNavigating = true; // esta pantalla deja de hacer setState()
    _keepServiceAlive = true;     // no apagamos el servicio en dispose()

    // cinturón extra: que SessionScreen ya no reciba updates del servicio
    _stepService?.updateListener((_, __) {});

    // navegamos usando GoRouter, no Navigator
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      context.push(
        '/game',
        extra: {
          'initialBpm': currentBpm,
          'initialSteps': steps,
          'stepService': _stepService!,
        },
      ).then((_) {
        // Cuando volvemos del juego (pop), volvemos a estar en SessionScreen.
        // Esta SessionScreen está "medio congelada", pero sigue en el árbol.

        _navigating = false;
        _keepServiceAlive = false;
        _stepService = null;

        // IMPORTANTÍSIMO:
        // No hacemos setState acá.
        // Esta pantalla ya está en modo "no actualizar UI" (_disposedOrNavigating = true)
        // y además ya no tenemos listener real.
      });
    });
  }
  /// Intercepta "atrás" (flecha AppBar o botón sistema)
  /// para que tampoco dispare navegación en medio de un frame.
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

    // Devolvemos false porque nosotros nos hacemos cargo del pop.
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

          // Mensaje de calibración / feedback al jugador
          Text(
            measuring
                ? '¡Gran ritmo! Mantente en movimiento para afinar la sesión.'
                : 'Comienza a caminar para que podamos calibrar tu ritmo.',
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
                      // Volvemos al estado de "revisando" para mostrar spinner si tarda
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
    return AnimatedContainer(
      duration: const Duration(milliseconds: 800),
      width: measuring ? 32 : 22,
      height: measuring ? 32 : 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: measuring
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
        boxShadow: measuring
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
    final bool enabled =
        currentBpm > 0 && permissionsGranted && !_navigating;

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
            'Entrar al juego',
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
