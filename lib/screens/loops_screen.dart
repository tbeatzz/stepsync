import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

  // ---- Perfil / packs ----
  String _selectedPack = 'base'; // "base" o "rap"
  List<String> _unlockedLoops = [];
  bool _loadingProfile = true;
  bool _isGuest = false;

  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _loadProfileAndPacks();
  }

  @override
  void dispose() {
    _previewPlayer.dispose();
    super.dispose();
  }

  // --------------------------------------------------
  // CARGA DE PERFIL: selectedPack + unlockedLoops
  // --------------------------------------------------
  Future<void> _loadProfileAndPacks() async {
    try {
      final user = _auth.currentUser;

      if (user == null) {
        // Invitado → solo pack base local, sin Firestore
        setState(() {
          _isGuest = true;
          _selectedPack = 'base';
          // loops base siempre disponibles para invitado (solo pre-escucha)
          _unlockedLoops = <String>[
            'loop_70',
            'loop_80',
            'loop_90',
            'loop_100',
            'loop_110',
          ];
          _loadingProfile = false;
        });
        return;
      }

      final doc =
      await _db.collection('users').doc(user.uid).get();

      if (!doc.exists) {
        // Perfil todavía no creado → fallback seguro
        setState(() {
          _isGuest = false;
          _selectedPack = 'base';
          _unlockedLoops = <String>[
            'loop_70',
            'loop_80',
            'loop_90',
            'loop_100',
            'loop_110',
          ];
          _loadingProfile = false;
        });
        return;
      }

      final data = doc.data() as Map<String, dynamic>;

      final selectedPack = (data['selectedPack'] as String?) ?? 'base';
      final unlocked = (data['unlockedLoops'] as List?)
          ?.map((e) => e.toString())
          .toList() ??
          <String>[
            'loop_70',
            'loop_80',
            'loop_90',
            'loop_100',
            'loop_110',
          ];

      setState(() {
        _isGuest = false;
        _selectedPack = (selectedPack == 'rap') ? 'rap' : 'base';
        _unlockedLoops = unlocked;
        _loadingProfile = false;
      });
    } catch (e) {
      // En caso de error, no rompemos la pantalla
      // ignore: avoid_print
      print('[LoopsScreen] Error cargando perfil: $e');
      setState(() {
        _isGuest = _auth.currentUser == null;
        _selectedPack = 'base';
        _unlockedLoops = <String>[
          'loop_70',
          'loop_80',
          'loop_90',
          'loop_100',
          'loop_110',
        ];
        _loadingProfile = false;
      });
    }
  }

  bool get _rapPackUnlocked {
    // si hay al menos un loop *_rap desbloqueado, consideramos el pack activo
    return _unlockedLoops.any((id) => id.endsWith('_rap'));
  }

  // --------------------------------------------------
  // CAMBIO DE PACK
  // --------------------------------------------------
  Future<void> _onSelectPack(String pack) async {
    if (_selectedPack == pack) return;

    if (pack == 'rap' && !_rapPackUnlocked) {
      // no está desbloqueado todavía
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pack Rap aún no desbloqueado 💿'),
        ),
      );
      return;
    }

    setState(() {
      _selectedPack = pack;
    });

    // Si es invitado, no intentamos guardar en Firestore
    if (_isGuest) return;

    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _db.collection('users').doc(user.uid).update({
        'selectedPack': pack,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // ignore: avoid_print
      print('[LoopsScreen] Error guardando selectedPack: $e');
    }
  }

  // --------------------------------------------------
  // PREVIEW: PLAY / PAUSE
  // --------------------------------------------------
  Future<void> _togglePlay(int index, String assetPathBase) async {
    // Caso 1: si ya está activo este mismo → parar
    if (_currentIndex == index) {
      await _previewPlayer.stop();
      if (!mounted) return;
      setState(() {
        _currentIndex = null;
      });
      return;
    }

    // Determinar qué asset usar según pack:
    // - Tomamos el ID del loop (loop_XX) a partir del asset base.
    final loopIdBase = _loopIdFromAsset(assetPathBase); // ej: "loop_80"
    String assetToPlay = assetPathBase;

    if (_selectedPack == 'rap' && _rapPackUnlocked) {
      final rapId = '${loopIdBase}_rap'; // ej: loop_80_rap
      if (_unlockedLoops.contains(rapId)) {
        assetToPlay = 'assets/audio/$rapId.wav';
      }
    }

    // Caso 2: cambiar loop
    await _previewPlayer.stop();
    await _previewPlayer.setAsset(assetToPlay);
    await _previewPlayer.setLoopMode(LoopMode.one);
    await _previewPlayer.play();

    if (!mounted) return;
    setState(() {
      _currentIndex = index;
    });
  }

  // extrae "loop_80" de "assets/audio/loop_80.wav"
  String _loopIdFromAsset(String asset) {
    // asumimos path tipo assets/audio/loop_80.wav
    final name = asset.split('/').last;     // loop_80.wav
    final withoutExt = name.split('.').first; // loop_80
    return withoutExt;
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
      body: _loadingProfile
          ? const Center(
        child: CircularProgressIndicator(
          color: Colors.greenAccent,
        ),
      )
          : Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildPackSelector(),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.separated(
                itemCount: buckets.length,
                separatorBuilder: (_, __) =>
                const SizedBox(height: 14),
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
                    assetPathBase: bucket.asset,
                    isPlaying: isPlaying,
                    onPlayPause: () =>
                        _togglePlay(index, bucket.asset),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------
  // UI: Selector de Pack (Base / Rap)
  // --------------------------------------------------
  Widget _buildPackSelector() {
    final rapUnlocked = _rapPackUnlocked;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF15151E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildPackChip(
              label: 'Base',
              subtitle: 'Loops estándar',
              selected: _selectedPack == 'base',
              onTap: () => _onSelectPack('base'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildPackChip(
              label: 'Rap',
              subtitle: rapUnlocked
                  ? 'Loops Rap desbloqueados'
                  : 'Desbloqueá caminando',
              selected: _selectedPack == 'rap',
              locked: !rapUnlocked,
              onTap: rapUnlocked ? () => _onSelectPack('rap') : () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                        'Caminá al menos 5 km para desbloquear el pack Rap 💿'),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPackChip({
    required String label,
    required String subtitle,
    required bool selected,
    required VoidCallback onTap,
    bool locked = false,
  }) {
    final Color baseColor = locked
        ? Colors.grey
        : (selected ? const Color(0xFF42C86D) : Colors.white70);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
        const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? const Color(0xFF42C86D)
                : Colors.white24,
            width: selected ? 2 : 1,
          ),
          color: selected
              ? const Color(0xFF1C2A24)
              : const Color(0xFF191923),
        ),
        child: Row(
          children: [
            Icon(
              locked
                  ? Icons.lock_outline
                  : (selected ? Icons.radio_button_checked : Icons.radio_button_unchecked),
              size: 18,
              color: baseColor,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.poppins(
                      color: baseColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.nunito(
                      color: Colors.white54,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------
  // UI: Lista de loops
  // --------------------------------------------------
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
    required String assetPathBase,
    required bool isPlaying,
    required VoidCallback onPlayPause,
  }) {
    final modeHint = _modeHintForRange(bucketMin, bucketMax);

    // Mostramos qué pack se está pre-escuchando en este momento
    final currentPackLabel =
    _selectedPack == 'rap' && _rapPackUnlocked ? 'Pack Rap' : 'Pack Base';

    // Nombre "lógico" del loop que se ve en UI (ID)
    final loopId = _loopIdFromAsset(assetPathBase);
    final displayId = (_selectedPack == 'rap' && _rapPackUnlocked)
        ? '${loopId}_rap'
        : loopId;

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
                  '$displayId  ·  $currentPackLabel',
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
