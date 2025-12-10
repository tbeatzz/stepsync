import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/audio_loop_service.dart'; // walkingBuckets (local)

import '../services/content_repository.dart';
import '../models/app_config.dart';
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
  StreamSubscription<User?>? _authSub;

  int? _currentIndex;

  // Perfil
  String _selectedPack = 'base';
  List<String> _unlockedLoops = [];

  // ✅ Nuevo (más robusto)
  Set<String> _unlockedPacks = {'base'};

  bool _loadingProfile = true;
  bool _isGuest = false;

  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  late final ContentRepository _contentRepo;

  @override
  void initState() {
    super.initState();
    _contentRepo = ContentRepository(_db);

    // primera carga
    _loadProfile();

    // ✅ FIX: recargar cuando FirebaseAuth termina de restaurar sesión
    _authSub = _auth.authStateChanges().listen((_) {
      if (!mounted) return;
      _loadProfile();
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _previewPlayer.dispose();
    super.dispose();
  }

  // --------------------------------------------------
  // PERFIL: selectedPack + unlockedLoops (+ unlockedPacks)
  // --------------------------------------------------
  Future<void> _loadProfile() async {
    try {
      final user = _auth.currentUser;

      // DEBUG (dejalo un rato hasta que lo confirmes)
      // ignore: avoid_print
      print('[LoopsScreen] currentUser=${user?.uid}');

      if (user == null) {
        setState(() {
          _isGuest = true;
          _selectedPack = 'base';
          _unlockedPacks = {'base'};
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
      final data = doc.data() ?? <String, dynamic>{};

      final selectedPack = (data['selectedPack'] as String?) ?? 'base';

      // unlockedLoops (siempre como string)
      final rawUnlocked = data['unlockedLoops'];
      final unlockedLoops = (rawUnlocked is List)
          ? rawUnlocked.map((e) => e.toString()).toList()
          : <String>[
        'loop_70',
        'loop_80',
        'loop_90',
        'loop_100',
        'loop_110',
      ];

      // unlockedPacks (opcional, si existe)
      final rawPacks = data['unlockedPacks'];
      final unlockedPacks = <String>{'base'};

      if (rawPacks is List) {
        unlockedPacks.addAll(rawPacks.map((e) => e.toString()));
      } else {
        // ✅ FIX: derivarlo de unlockedLoops SOLO si tiene formato loop_XX_pack (no números)
        final re = RegExp(r'^loop_\d+_([a-zA-Z0-9]+)$');
        for (final k in unlockedLoops) {
          final m = re.firstMatch(k);
          if (m != null) {
            unlockedPacks.add(m.group(1)!); // rock/rap/edm...
          }
        }
      }

      setState(() {
        _isGuest = false;
        _selectedPack = selectedPack.isNotEmpty ? selectedPack : 'base';
        _unlockedLoops = unlockedLoops;
        _unlockedPacks = unlockedPacks;
        _loadingProfile = false;
      });

      // ignore: avoid_print
      print('[LoopsScreen] isGuest=$_isGuest selectedPack=$_selectedPack '
          'unlockedLoops=${_unlockedLoops.length} unlockedPacks=$_unlockedPacks');
    } catch (e) {
      // ignore: avoid_print
      print('[LoopsScreen] Error cargando perfil: $e');
      setState(() {
        _isGuest = _auth.currentUser == null;
        _selectedPack = 'base';
        _unlockedPacks = {'base'};
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

  // --------------------------------------------------
  // Remote enabled?
  // --------------------------------------------------
  bool _isRemoteEnabledFrom(AppConfig? cfg) {
    final minOk = (cfg?.minAppVersionCode ?? 0) <= AppVersion.versionCode;
    final useRemote = cfg?.flagBool(
      'useRemoteContent',
      fallback: AppFlags.useRemoteContent,
    ) ??
        AppFlags.useRemoteContent;
    return useRemote && minOk;
  }

  // --------------------------------------------------
  // Packs desde clientConfig
  // --------------------------------------------------
  List<String> _packsFromClientConfig(AppConfig? cfg) {
    final client = cfg?.clientConfig;
    final ids = client?.enabledPackIdsSorted() ?? const <String>[];

    if (ids.isEmpty) return <String>['base', 'rap'];

    if (!ids.contains('base')) return <String>['base', ...ids];
    return ids;
  }

  String _packTitle(AppConfig? cfg, String packId) {
    final t = cfg?.clientConfig.packs[packId]?.title;
    if (t != null && t.trim().isNotEmpty) return t;
    if (packId == 'base') return 'Base';
    return packId.toUpperCase();
  }

  // ✅ Pack desbloqueado: primero por unlockedPacks, fallback por sufijo de unlockedLoops
  bool _isPackUnlocked(String packId) {
    if (packId == 'base') return true;
    if (_unlockedPacks.contains(packId)) return true;
    return _unlockedLoops.any((k) => k.endsWith('_$packId'));
  }

  // --------------------------------------------------
  // Cambiar pack
  // --------------------------------------------------
  Future<void> _onSelectPack(AppConfig cfg, String packId, {required bool remoteEnabled}) async {
    if (!remoteEnabled && packId != 'base' && packId != 'rap') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Este pack requiere Remote Content activado.')),
      );
      return;
    }

    if (_isGuest && packId != 'base') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Iniciá sesión para desbloquear packs 🔒')),
      );
      return;
    }

    if (packId != 'base' && !_isPackUnlocked(packId)) {
      final title = _packTitle(cfg, packId);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Pack $title aún no desbloqueado 🔒')),
      );
      return;
    }

    if (_selectedPack == packId) return;

    setState(() {
      _selectedPack = packId;
      _currentIndex = null;
    });
    await _previewPlayer.stop();

    if (_isGuest) return;

    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _db.collection('users').doc(user.uid).update({
        'selectedPack': packId,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // ignore: avoid_print
      print('[LoopsScreen] Error guardando selectedPack: $e');
    }
  }

  // --------------------------------------------------
  // Preview LOCAL (assets)
  // --------------------------------------------------
  Future<void> _togglePlayLocal(int index, String assetPathBase) async {
    if (_currentIndex == index) {
      await _previewPlayer.stop();
      if (!mounted) return;
      setState(() => _currentIndex = null);
      return;
    }

    final baseLoopId = _loopIdFromAsset(assetPathBase);
    String assetToPlay = assetPathBase;

    if (_selectedPack == 'rap') {
      final rapId = '${baseLoopId}_rap';
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
  // Preview REMOTO (url / previewUrl)
  // --------------------------------------------------
  Future<void> _togglePlayRemote({
    required int index,
    required LoopDef loop,
    required bool locked,
    required String fallbackAssetKey,
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
      if (url.startsWith('http')) {
        await _previewPlayer.setUrl(url);
      } else if (url.startsWith('assets/')) {
        await _previewPlayer.setAsset(url);
      } else {
        await _previewPlayer.setAsset('assets/audio/$fallbackAssetKey.wav');
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

  String _loopIdFromAsset(String asset) {
    final name = asset.split('/').last;
    return name.split('.').first;
  }

  String _baseLoopIdForPack(String loopId, String packId) {
    final suffix = '_$packId';
    if (loopId.endsWith(suffix)) {
      return loopId.substring(0, loopId.length - suffix.length);
    }
    return loopId;
  }

  // --------------------------------------------------
  // BUILD
  // --------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppConfig>(
      stream: _contentRepo.watchAppConfig(),
      builder: (context, snapCfg) {
        final cfg = snapCfg.data;
        final remoteEnabled = _isRemoteEnabledFrom(cfg);

        return Scaffold(
          backgroundColor: const Color(0xFF0D0C14),
          appBar: AppBar(
            title: Text(
              remoteEnabled ? 'Loops de StepSync (Remote)' : 'Loops de StepSync',
              style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600),
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: _loadingProfile
              ? const Center(child: CircularProgressIndicator(color: Colors.greenAccent))
              : Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildPackSelector(cfg, remoteEnabled: remoteEnabled),
                const SizedBox(height: 20),
                Expanded(
                  child: remoteEnabled ? _buildRemoteLoopsList(cfg) : _buildLocalLoopsList(cfg),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // --------------------------------------------------
  // PACK SELECTOR
  // --------------------------------------------------
  Widget _buildPackSelector(AppConfig? cfg, {required bool remoteEnabled}) {
    final packs = _packsFromClientConfig(cfg);
    final shown = remoteEnabled ? packs : packs.where((p) => p == 'base' || p == 'rap').toList();
    final packIds = shown.isNotEmpty ? shown : <String>['base', 'rap'];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF15151E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final packId in packIds) ...[
              _buildPackChip(
                label: _packTitle(cfg, packId),
                subtitle: packId == 'base' ? 'Loops estándar' : 'Pack $packId',
                selected: _selectedPack == packId,
                locked: (_isGuest && packId != 'base') || (packId != 'base' && !_isPackUnlocked(packId)),
                onTap: () {
                  final safeCfg = cfg ??
                      const AppConfig(
                        contentVersion: 0,
                        minAppVersionCode: 0,
                        flags: <String, dynamic>{},
                        clientConfig: ClientConfig(
                          defaultPackId: 'base',
                          packs: <String, ClientPackCfg>{},
                        ),
                      );
                  _onSelectPack(safeCfg, packId, remoteEnabled: remoteEnabled);
                },
              ),
              const SizedBox(width: 10),
            ],
          ],
        ),
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
    final Color baseColor = locked ? Colors.grey : (selected ? const Color(0xFF42C86D) : Colors.white70);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 160,
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
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(color: baseColor, fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.nunito(color: Colors.white54, fontSize: 11),
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
  // LOCAL LIST
  // --------------------------------------------------
  Widget _buildLocalLoopsList(AppConfig? cfg) {
    final effectivePack = (_selectedPack == 'rap') ? 'rap' : 'base';
    final bool showFallbackBanner = _selectedPack != effectivePack;
    final buckets = walkingBuckets;

    return Column(
      children: [
        if (showFallbackBanner)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white12),
            ),
            child: Text(
              'Remote Content está desactivado. Mostrando pack Base.',
              style: GoogleFonts.nunito(color: Colors.white70),
            ),
          ),
        Expanded(
          child: ListView.separated(
            itemCount: buckets.length,
            separatorBuilder: (_, __) => const SizedBox(height: 14),
            itemBuilder: (context, index) {
              final bucket = buckets[index];
              final bpmLabel = _bpmLabelFromAsset(bucket.asset, bucket.min, bucket.max);
              final isPlaying = _currentIndex == index;

              final baseLoopId = _loopIdFromAsset(bucket.asset);
              final displayId = effectivePack == 'rap' ? '${baseLoopId}_rap' : baseLoopId;

              final locked = effectivePack == 'rap' && !_unlockedLoops.contains('${baseLoopId}_rap');

              return _buildLoopTile(
                index: index,
                bpmLabel: bpmLabel,
                bucketMin: bucket.min,
                bucketMax: bucket.max,
                isPlaying: isPlaying,
                displayId: displayId,
                currentPackLabel: effectivePack == 'rap' ? 'Pack RAP (Local)' : 'Pack BASE (Local)',
                locked: locked,
                onPlayPause: () => _togglePlayLocal(index, bucket.asset),
              );
            },
          ),
        ),
      ],
    );
  }

  // --------------------------------------------------
  // REMOTE LIST
  // --------------------------------------------------
  Widget _buildRemoteLoopsList(AppConfig? cfg) {
    final safeCfg = cfg ??
        const AppConfig(
          contentVersion: 0,
          minAppVersionCode: 0,
          flags: <String, dynamic>{},
          clientConfig: ClientConfig(
            defaultPackId: 'base',
            packs: <String, ClientPackCfg>{},
          ),
        );

    final client = safeCfg.clientConfig;

    // ✅ Guest consistente con GameScreen: siempre base
    String packId = _isGuest ? 'base' : _selectedPack;

    if (!client.isPackEnabled(packId)) {
      packId = client.isPackEnabled(client.defaultPackId) ? client.defaultPackId : 'base';
    }

    final currentPackLabel = 'Pack ${_packTitle(safeCfg, packId)} (Remote)';

    // ✅ lock por PACK (no por loop)
    final packLocked = (packId != 'base') && !_isPackUnlocked(packId);

    if (packLocked) {
      return Center(
        child: Text(
          'Este pack está bloqueado 🔒\nJugá para desbloquearlo.',
          textAlign: TextAlign.center,
          style: GoogleFonts.nunito(color: Colors.white70, fontSize: 16),
        ),
      );
    }

    return StreamBuilder<List<LoopDef>>(
      stream: _contentRepo.watchLoops(packId),
      builder: (context, snapLoops) {
        if (snapLoops.hasError) {
          return Center(
            child: Text('Error loops: ${snapLoops.error}', style: const TextStyle(color: Colors.white70)),
          );
        }

        final loops = (snapLoops.data ?? const <LoopDef>[])
            .where((l) => l.active)
            .toList()
          ..sort((a, b) => a.bpmMin.compareTo(b.bpmMin));

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

            final baseLoopId = _baseLoopIdForPack(loop.id, packId);
            final displayId = (packId == 'base') ? baseLoopId : '${baseLoopId}_$packId';

            // ✅ pack unlocked => no lockeamos por loopKey
            final locked = false;

            final bpmLabel = '${loop.bpmMin}–${loop.bpmMax} BPM';

            return _buildLoopTile(
              index: index,
              bpmLabel: bpmLabel,
              bucketMin: loop.bpmMin,
              bucketMax: loop.bpmMax,
              isPlaying: isPlaying,
              displayId: displayId,
              currentPackLabel: currentPackLabel,
              locked: locked,
              onPlayPause: () => _togglePlayRemote(
                index: index,
                loop: loop,
                locked: locked,
                fallbackAssetKey: displayId,
              ),
            );
          },
        );
      },
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
                  locked ? Icons.lock : (isPlaying ? Icons.pause : Icons.play_arrow),
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
                    style: GoogleFonts.poppins(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    modeHint,
                    style: GoogleFonts.nunito(color: Colors.white60, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$displayId  ·  $currentPackLabel',
                    style: GoogleFonts.nunito(color: Colors.white30, fontSize: 11),
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
// ---- LoopsScreen local buckets (export) ----
class BpmBucket {
  final int min;
  final int max;
  final String asset;
  const BpmBucket({required this.min, required this.max, required this.asset});

  bool contains(int bpm) => bpm >= min && bpm <= max;
}

const List<BpmBucket> walkingBuckets = <BpmBucket>[
  BpmBucket(min: 10,  max: 75,  asset: 'assets/audio/loop_70.wav'),
  BpmBucket(min: 76,  max: 85,  asset: 'assets/audio/loop_80.wav'),
  BpmBucket(min: 86,  max: 95,  asset: 'assets/audio/loop_90.wav'),
  BpmBucket(min: 96,  max: 105, asset: 'assets/audio/loop_100.wav'),
  BpmBucket(min: 106, max: 200, asset: 'assets/audio/loop_110.wav'),
];
