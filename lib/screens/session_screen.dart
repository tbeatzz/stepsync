import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/step_service_fft.dart';
import 'package:permission_handler/permission_handler.dart';

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

  @override
  void initState() {
    super.initState();
    _initSession();
  }

  Future<void> _initSession() async {
    await Permission.activityRecognition.request();
    await Permission.location.request();

    _stepService = StepServiceFFT(onUpdate: (bpm, stepCount) {
      setState(() {
        currentBpm = bpm;
        steps = stepCount;
        measuring = true;
      });
    });

    _stepService!.startListening();
  }

  @override
  void dispose() {
    _stepService?.stopListening();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0C14),
      appBar: AppBar(
        title: const Text('Sesión en curso'),
        backgroundColor: Colors.transparent,
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 30),
            _buildPulseIndicator(),
            const SizedBox(height: 30),
            Text(
              "BPM: $currentBpm",
              style: GoogleFonts.poppins(
                  fontSize: 48, color: Colors.white, fontWeight: FontWeight.bold),
            ),
            Text("Pasos: $steps",
                style: GoogleFonts.nunito(
                    color: Colors.white70, fontSize: 16, height: 2)),
            const SizedBox(height: 30),
            Expanded(
              child: StreamBuilder<String>(
                stream: _stepService?.debugStream.stream,
                builder: (context, snapshot) {
                  final data = snapshot.data ?? "Esperando datos del sensor...";
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: SingleChildScrollView(
                      reverse: true,
                      child: Text(
                        data,
                        style: const TextStyle(
                            color: Colors.greenAccent, fontSize: 14),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/game'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.greenAccent,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                padding:
                const EdgeInsets.symmetric(horizontal: 50, vertical: 14),
              ),
              child: const Text("🎮 Entrar al juego"),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildPulseIndicator() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 800),
      width: measuring ? 30 : 20,
      height: measuring ? 30 : 20,
      decoration: BoxDecoration(
        color: measuring ? Colors.greenAccent : Colors.grey,
        shape: BoxShape.circle,
        boxShadow: measuring
            ? [
          BoxShadow(
              color: Colors.greenAccent.withOpacity(0.6),
              blurRadius: 20,
              spreadRadius: 4)
        ]
            : [],
      ),
    );
  }
}
