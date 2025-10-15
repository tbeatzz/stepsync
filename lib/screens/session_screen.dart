import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/step_service.dart';
import 'package:permission_handler/permission_handler.dart';

class SessionScreen extends StatefulWidget {
  final String mode; // “Caminar”, “Trotar” o “Correr”

  const SessionScreen({super.key, required this.mode});

  @override
  State<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends State<SessionScreen> {
  StepService? _stepService;
  int currentBpm = 0;
  int _steps = 0; // contador visible

  double distanceGoal = 2.0; // km
  int durationGoal = 0; // minutos (calculado automáticamente)

  final Map<String, List<int>> bpmRanges = {
    "Caminar": [90, 115],
    "Trotar": [115, 135],
    "Correr": [135, 160],
  };

  final Map<String, double> averageSpeeds = {
    "Caminar": 5.0,
    "Trotar": 8.0,
    "Correr": 11.0,
  };

  @override
  void initState() {
    super.initState();
    _initSession();
  }

  Future<void> _initSession() async {
    await _requestPermissions();
    _calculateDuration();

    _stepService = StepService(onBpmUpdated: (bpm) {
      setState(() {
        currentBpm = bpm;
        _steps++;
      });
    });

    _stepService!.startListening();
  }

  /// verifica y solicita permisos solo si faltan
  Future<void> _requestPermissions() async {
    //  Pide permisos de actividad primero
    final activityStatus = await Permission.activityRecognition.status;
    if (!activityStatus.isGranted) {
      final result = await Permission.activityRecognition.request();
      if (result.isPermanentlyDenied) {
        _showPermissionWarning("Reconocimiento de actividad");
        return;
      }
    }

    //  Luego permisos de ubicación
    final locationStatus = await Permission.location.status;
    if (!locationStatus.isGranted) {
      final result = await Permission.location.request();
      if (result.isPermanentlyDenied) {
        _showPermissionWarning("Ubicación");
        return;
      }
    }

    //  Confirmación visual (solo la primera vez)
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Permisos concedidos correctamente."),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  /// Muestra alerta para ir a ajustes si se deniega permanentemente
  void _showPermissionWarning(String permiso) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          " El permiso de $permiso fue denegado permanentemente.\nActiválo desde Ajustes > Aplicaciones > StepSync.",
        ),
        backgroundColor: Colors.redAccent,
        action: SnackBarAction(
          label: "Abrir ajustes",
          textColor: Colors.white,
          onPressed: openAppSettings,
        ),
      ),
    );
  }

  Future<bool> _checkPermissions() async {
    bool activityGranted = await Permission.activityRecognition.isGranted;
    bool locationGranted = await Permission.location.isGranted;
    return activityGranted && locationGranted;
  }

  void _calculateDuration() {
    double speed = averageSpeeds[widget.mode]!;
    setState(() {
      durationGoal = (distanceGoal / speed * 60).round();
    });
  }

  @override
  void dispose() {
    _stepService?.stopListening();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bpmRange = bpmRanges[widget.mode]!;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0C14),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(
          "Modo: ${widget.mode}",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 20),
            _buildBpmCard(bpmRange),
            const SizedBox(height: 30),
            _buildSessionSettings(),
            const Spacer(),
            _buildStartButton(context),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildBpmCard(List<int> bpmRange) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF1B174B), Color(0xFF1C0B2D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          Text("BPM actual",
              style: GoogleFonts.poppins(color: Colors.white70, fontSize: 16)),
          const SizedBox(height: 8),
          Text("$currentBpm",
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 54,
                fontWeight: FontWeight.w700,
              )),
          Text(
            "Rango óptimo: ${bpmRange[0]} - ${bpmRange[1]} BPM",
            style: GoogleFonts.poppins(
              color: Colors.greenAccent,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            "Pasos detectados: $_steps",
            style: GoogleFonts.nunito(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionSettings() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: const Color(0xFF1B174B),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Configurar sesión",
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.route, color: Colors.white70),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Distancia objetivo (km): ${distanceGoal.toStringAsFixed(1)}",
                  style: GoogleFonts.nunito(color: Colors.white, fontSize: 14),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.remove, color: Colors.white70),
                onPressed: () {
                  setState(() {
                    distanceGoal = (distanceGoal - 0.5).clamp(0.5, 10);
                    _calculateDuration();
                  });
                },
              ),
              IconButton(
                icon: const Icon(Icons.add, color: Colors.white70),
                onPressed: () {
                  setState(() {
                    distanceGoal = (distanceGoal + 0.5).clamp(0.5, 10);
                    _calculateDuration();
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.timer, color: Colors.white70),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Duración estimada: $durationGoal min",
                  style: GoogleFonts.nunito(color: Colors.white, fontSize: 14),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStartButton(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        bool hasPermissions = await _checkPermissions();
        if (!hasPermissions) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(" Otorgá los permisos para comenzar la sesión"),
              backgroundColor: Colors.orangeAccent,
            ),
          );
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("🏃‍♂️ Iniciando sesión..."),
            backgroundColor: Colors.greenAccent,
          ),
        );
      },
      child: Container(
        height: 55,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          gradient: const LinearGradient(
            colors: [Color(0xFF42C86D), Color(0xFF2D978C)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          "Iniciar sesión",
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
