import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/audio_loop_service.dart'; // walkingBuckets (local)

import '../services/content_repository.dart';
import '../models/app_config.dart';
import '../models/pack_def.dart';
import '../models/loop_def.dart';
import '../config/app_flags.dart';
import '../config/app_version.dart';

class LoopsScreen extends StatefulWidget {
  const LoopsScreen({super.key});

  @override
  State<LoopsScreen> createState() => _LoopsScreenState();
}

class _LoopsScreenState extends State<LoopsScreen> {
  final AudioPlayer _previewPlayer = AudioPlayer();

  // null = nada sonando, valor = índice activo
  int? _currentIndex;

  // ---- Perfil / packs ----
  String _selectedPack = 'base'; // "base" o "rap"
  List<String> _unlockedLoops = [];
  bool _loadingProfile = true;
  bool _isGuest = false;

  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  late final ContentRepository _contentRepo;

  @override
  void initState() {
    super.initState();
    _contentRepo = ContentRepository(_db);
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

      final doc = await _db.collection('users').doc(user.uid).get();

      if (!doc.exists) {
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

  bool get _rapPackUnlocked => _unlockedLoops.any((id) => id.endsWith('_rap'));

  // --------------------------------------------------
  // CAMBIO DE PACK (local y remoto usan el mismo selector por ahora)
  // --------------------------------------------------
  Future<void> _onSelectPack(String pack) async {
    if (_selectedPack == pack) return;

    if (pack == 'rap' && !_rapPackUnlocked) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pack Rap aún no desbloqueado 💿')),
      );
      return;
    }

    setState(() {
      _selectedPack = pack;
      _currentIndex = null; // corta “selección” en UI
    });
    await _previewPlayer.stop();

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
  // PREVIEW LOCAL (assets)
  // --------------------------------------------------
  Future<void> _togglePlayLocal(int index, String assetPathBase) async {
    if (_currentIndex == index) {
      await _previewPlayer.stop();
      if (!mounted) return;
      setState(() => _currentIndex = null);
      return;
    }

    final loopIdBase = _loopIdFromAsset(assetPathBase); // "loop_80"
    String assetToPlay = assetPathBase;

    if (_selectedPack == 'rap' && _rapPackUnlocked) {
      final rapId = '${loopIdBase}_rap';
      if (_unlockedLoops.contains(rapId)) {
        assetToPlay = 'assets/audio/$rapId.wav';
      }
    }

    await _previewPlayer.stop();
    await _previewPlayer.setAsset(assetToPlay);
    await _previewPlayer.setLoopMode(LoopMode.one);
    await _previewPlayer.play();

    if (!mounted) return;
    setState(() => _currentIndex = index);
  }

  // --------------------------------------------------
  // PREVIEW REMOTO (url o assets)
  // --------------------------------------------------
  Future<void> _togglePlayRemote({
    required int index,
    required LoopDef loop,
    required String displayKey,
    required bool locked,
  }) async {
    if (locked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Loop bloqueado 🔒')),
      );
      return;
    }

    if (_currentIndex == index) {
      await _previewPlayer.stop();
      if (!mounted) return;
      setState(() => _currentIndex = null);
      return;
    }

    await _previewPlayer.stop();

    final url = loop.previewUrl.isNotEmpty ? loop.previewUrl : loop.url;

    try {
      if (url.startsWith('assets/')) {
        await _previewPlayer.setAsset(url);
      } else if (url.startsWith('http')) {
        await _previewPlayer.setUrl(url);
      } else {
        // fallback: si todavía no hay URLs, intentamos mapear a assets por key
        await _previewPlayer.setAsset('assets/audio/$displayKey.wav');
      }

      await _previewPlayer.setLoopMode(LoopMode.one);
      await _previewPlayer.play();

      if (!mounted) return;
      setState(() => _currentIndex = index);
    } catch (e) {
      // ignore: avoid_print
      print('[LoopsScreen] Error preview remoto: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo reproducir el preview ❌')),
      );
      setState(() => _currentIndex = null);
    }
  }

  // "assets/audio/loop_80.wav" -> "loop_80"
  String _loopIdFromAsset(String asset) {
    final name = asset.split('/').last;
    final withoutExt = name.split('.').first;
    return withoutExt;
  }

  // Para remoto: clave de desbloqueo por pack (base = loopId, rap = loopId_rap)
  String _unlockKeyFor(String baseLoopId, String packId) {
    if (packId == 'base') return baseLoopId;
    return '${baseLoopId}_$packId';
  }

  bool _isRemoteEnabledFrom(AppConfig? cfg) {
    final minOk = (cfg?.minAppVersionCode ?? 0) <= AppVersion.versionCode;
    final useRemote = cfg?.flagBool(
      'useRemoteContent',
      fallback: AppFlags.useRemoteContent,
    ) ??
        AppFlags.useRemoteContent;
    return useRemote && minOk;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppConfig>(
      stream: _contentRepo.watchAppConfig(),
      builder: (context, snapCfg) {
        final remoteEnabled = _isRemoteEnabledFrom(snapCfg.data);

        return Scaffold(
          backgroundColor: const Color(0xFF0D0C14),
          appBar: AppBar(
            title: Text(
              remoteEnabled ? 'Loops de StepSync (Remote)' : 'Loops de StepSync',
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
            child: CircularProgressIndicator(color: Colors.greenAccent),
          )
              : Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildPackSelector(),
                const SizedBox(height: 20),
                Expanded(
                  child: remoteEnabled
                      ? _buildRemoteLoopsList()
                      : _buildLocalLoopsList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // --------------------------------------------------
  // LOCAL LIST (tu lógica actual)
  // --------------------------------------------------
  Widget _buildLocalLoopsList() {
    final buckets = walkingBuckets;

    return ListView.separated(
      itemCount: buckets.length,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        final bucket = buckets[index];
        final bpmLabel = _bpmLabelFromAsset(bucket.asset, bucket.min, bucket.max);
        final isPlaying = _currentIndex == index;

        return _buildLoopTile(
          index: index,
          bpmLabel: bpmLabel,
          bucketMin: bucket.min,
          bucketMax: bucket.max,
          isPlaying: isPlaying,
          // info UI
          displayId: _displayIdForLocal(bucket.asset),
          currentPackLabel: _selectedPack == 'rap' && _rapPackUnlocked ? 'Pack Rap' : 'Pack Base',
          locked: _isLocalLocked(bucket.asset),
          // action
          onPlayPause: () => _togglePlayLocal(index, bucket.asset),
        );
      },
    );
  }

  String _displayIdForLocal(String assetPathBase) {
    final loopId = _loopIdFromAsset(assetPathBase);
    if (_selectedPack == 'rap' && _rapPackUnlocked) return '${loopId}_rap';
    return loopId;
  }

  bool _isLocalLocked(String assetPathBase) {
    if (_selectedPack != 'rap') return false;
    if (!_rapPackUnlocked) return true;
    final loopId = _loopIdFromAsset(assetPathBase);
    final rapId = '${loopId}_rap';
    return !_unlockedLoops.contains(rapId);
  }

  // --------------------------------------------------
  // REMOTE LIST (desde Firestore packs/{packId}/loops)
  // --------------------------------------------------
  Widget _buildRemoteLoopsList() {
    // Invitado: forzamos base
    final packId = _isGuest ? 'base' : _selectedPack;

    return StreamBuilder<List<PackDef>>(
      stream: _contentRepo.watchPacks(),
      builder: (context, snapPacks) {
        if (snapPacks.hasError) {
          return Center(child: Text('Error packs: ${snapPacks.error}', style: const TextStyle(color: Colors.white70)));
        }

        final packs = (snapPacks.data ?? const <PackDef>[])
            .where((p) => p.active)
            .toList();

        if (packs.isEmpty) {
          return const Center(
            child: Text('No hay packs remotos activos.', style: TextStyle(color: Colors.white70)),
          );
        }

        // Si el packId seleccionado no existe en remoto, caemos al primero activo
        final effectivePackId = packs.any((p) => p.id == packId) ? packId : packs.first.id;

        return StreamBuilder<List<LoopDef>>(
          stream: _contentRepo.watchLoops(effectivePackId),
          builder: (context, snapLoops) {
            if (snapLoops.hasError) {
              return Center(child: Text('Error loops: ${snapLoops.error}', style: const TextStyle(color: Colors.white70)));
            }

            final loops = (snapLoops.data ?? const <LoopDef>[])
                .where((l) => l.active)
                .toList();

            if (loops.isEmpty) {
              return const Center(
                child: Text('Este pack no tiene loops activos.', style: TextStyle(color: Colors.white70)),
              );
            }

            return ListView.separated(
              itemCount: loops.length,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                final loop = loops[index];
                final isPlaying = _currentIndex == index;

                // displayKey: si pack != base -> loopId_pack
                final displayKey = (effectivePackId == 'base')
                    ? loop.id
                    : '${loop.id}_$effectivePackId';

                final locked = effectivePackId == 'base'
                    ? false
                    : !_unlockedLoops.contains(_unlockKeyFor(loop.id, effectivePackId));

                final bpmLabel = '${loop.bpmMin}–${loop.bpmMax} BPM';
                final currentPackLabel = effectivePackId == 'base' ? 'Pack Base' : 'Pack ${effectivePackId.toUpperCase()}';

                return _buildLoopTile(
                  index: index,
                  bpmLabel: bpmLabel,
                  bucketMin: loop.bpmMin,
                  bucketMax: loop.bpmMax,
                  isPlaying: isPlaying,
                  displayId: displayKey,
                  currentPackLabel: currentPackLabel,
                  locked: locked,
                  onPlayPause: () => _togglePlayRemote(
                    index: index,
                    loop: loop,
                    displayKey: displayKey,
                    locked: locked,
                  ),
                );
              },
            );
          },
        );
      },
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
              subtitle: rapUnlocked ? 'Loops Rap desbloqueados' : 'Desbloqueá caminando',
              selected: _selectedPack == 'rap',
              locked: !rapUnlocked,
              onTap: rapUnlocked
                  ? () => _onSelectPack('rap')
                  : () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Caminá al menos 5 km para desbloquear el pack Rap 💿'),
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
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? const Color(0xFF42C86D) : Colors.white24,
            width: selected ? 2 : 1,
          ),
          color: selected ? const Color(0xFF1C2A24) : const Color(0xFF191923),
        ),
        child: Row(
          children: [
            Icon(
              locked ? Icons.lock_outline : (selected ? Icons.radio_button_checked : Icons.radio_button_unchecked),
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
  // UI helpers
  // --------------------------------------------------
  String _bpmLabelFromAsset(String asset, int min, int max) {
    final reg = RegExp(r'(\d+)');
    final match = reg.firstMatch(asset);
    if (match != null) {
      final bpm = int.tryParse(match.group(1) ?? '');
      if (bpm != null) return '$bpm BPM';
    }
    return '$min–$max BPM';
  }

  Widget _buildLoopTile({
    required int index,
    required String bpmLabel,
    required int bucketMin,
    required int bucketMax,
    required bool isPlaying,
    required String displayId,
    required String currentPackLabel,
    required bool locked,
    required VoidCallback onPlayPause,
  }) {
    final modeHint = _modeHintForRange(bucketMin, bucketMax);

    return Opacity(
      opacity: locked ? 0.55 : 1.0,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF15151E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isPlaying ? Colors.greenAccent.withOpacity(0.5) : Colors.white12,
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
                  locked
                      ? Icons.lock
                      : (isPlaying ? Icons.pause : Icons.play_arrow),
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
      ),
    );
  }

  String _modeHintForRange(int min, int max) {
    final mid = ((min + max) / 2).round();
    if (mid < 95) return 'Ideal para caminar suave';
    if (mid < 120) return 'Buen ritmo para trotar';
    return 'Perfecto para correr intenso';
  }
}
