import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/step_service.dart';

class SessionScreen extends StatefulWidget {
  final String mode; // “Caminar”, “Trotar” o “Correr”

  const SessionScreen({super.key, required this.mode});

  @override
  State<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends State<SessionScreen> {
  StepService? _stepService;
  int currentBpm = 0;

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

    _calculateDuration(); // 🔹 calcula duración inicial

    _stepService = StepService(onBpmUpdated: (bpm) {
      setState(() {
        currentBpm = bpm;
      });
    });

    _stepService!.startListening();
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

            // BPM actual
            _buildBpmCard(bpmRange),

            const SizedBox(height: 30),

            // Configuración de sesión
            _buildSessionSettings(),

            const Spacer(),

            // Botón de inicio
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

          // Distancia
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

          // Duración automática
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
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("🚧 Iniciando sesión de prueba..."),
            backgroundColor: Colors.deepPurpleAccent,
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
