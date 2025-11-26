import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio/just_audio.dart';

import '../services/audio_loop_service.dart'; // walkingBuckets

class LoopsScreen extends StatefulWidget {
  const LoopsScreen({super.key});

  @override
  State<LoopsScreen> createState() => _LoopsScreenState();
}

class _LoopsScreenState extends State<LoopsScreen> {
  final AudioPlayer _previewPlayer = AudioPlayer();

  // null = nada sonando, valor = índice del bucket activo
  int? _currentIndex;

  @override
  void dispose() {
    _previewPlayer.dispose();
    super.dispose();
  }

  Future<void> _togglePlay(int index, String assetPath) async {
    // Caso 1: si ya está activo este mismo → parar
    if (_currentIndex == index) {
      await _previewPlayer.stop();
      if (!mounted) return;
      setState(() {
        _currentIndex = null;
      });
      return;
    }

    // Caso 2: si no hay nada o es otro → cambiar loop
    await _previewPlayer.stop();
    await _previewPlayer.setAsset(assetPath);
    await _previewPlayer.setLoopMode(LoopMode.one);
    await _previewPlayer.play();

    if (!mounted) return;
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final buckets = walkingBuckets;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0C14),
      appBar: AppBar(
        title: Text(
          'Loops de StepSync',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: ListView.separated(
          itemCount: buckets.length,
          separatorBuilder: (_, __) => const SizedBox(height: 14),
          itemBuilder: (context, index) {
            final bucket = buckets[index];
            final bpmLabel = _bpmLabelFromAsset(
              bucket.asset,
              bucket.min,
              bucket.max,
            );

            final isPlaying = _currentIndex == index;

            return _buildLoopTile(
              index: index,
              bpmLabel: bpmLabel,
              bucketMin: bucket.min,
              bucketMax: bucket.max,
              assetPath: bucket.asset,
              isPlaying: isPlaying,
              onPlayPause: () => _togglePlay(index, bucket.asset),
            );
          },
        ),
      ),
    );
  }

  String _bpmLabelFromAsset(String asset, int min, int max) {
    final reg = RegExp(r'(\d+)');
    final match = reg.firstMatch(asset);
    if (match != null) {
      final bpm = int.tryParse(match.group(1) ?? '');
      if (bpm != null) {
        return '$bpm BPM';
      }
    }
    return '$min–$max BPM';
  }

  Widget _buildLoopTile({
    required int index,
    required String bpmLabel,
    required int bucketMin,
    required int bucketMax,
    required String assetPath,
    required bool isPlaying,
    required VoidCallback onPlayPause,
  }) {
    final modeHint = _modeHintForRange(bucketMin, bucketMax);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF15151E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPlaying
              ? Colors.greenAccent.withOpacity(0.5)
              : Colors.white12,
          width: 1,
        ),
        boxShadow: [
          if (isPlaying)
            BoxShadow(
              color: Colors.greenAccent.withOpacity(0.25),
              blurRadius: 12,
              offset: const Offset(0, 8),
            ),
        ],
      ),
      child: Row(
        children: [
          // 👉 SOLO este botón es clickeable
          GestureDetector(
            onTap: onPlayPause,
            child: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFF42C86D), Color(0xFF2D978C)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Icon(
                isPlaying ? Icons.pause : Icons.play_arrow,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bpmLabel,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  modeHint,
                  style: GoogleFonts.nunito(
                    color: Colors.white60,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  assetPath,
                  style: GoogleFonts.nunito(
                    color: Colors.white30,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _modeHintForRange(int min, int max) {
    final mid = ((min + max) / 2).round();

    if (mid < 95) {
      return 'Ideal para caminar suave';
    } else if (mid < 120) {
      return 'Buen ritmo para trotar';
    } else {
      return 'Perfecto para correr intenso';
    }
  }
}
