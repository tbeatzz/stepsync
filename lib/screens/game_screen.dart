import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/step_service_fft.dart';
import '../services/audio_loop_service.dart';
import '../services/session_repository.dart';

import '../services/content_repository.dart';
import '../services/cache_service.dart';

import '../models/app_config.dart';
import '../config/app_flags.dart';
import '../config/app_version.dart';

import '../services/user_repository.dart';

class GameScreen extends StatefulWidget {
  final int initialBpm;
  final int initialSteps;
  final StepServiceFFT stepService;
  final String mode;

  const GameScreen({
    super.key,
    required this.initialBpm,
    required this.initialSteps,
    required this.stepService,
    required this.mode,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  int _rawBpm = 0;
  int _steps = 0;

  int _stableBpm = 0;

  final UserRepository _userRepo = UserRepository();

  final List<int> _bpmWindow = [];
  static const int _bpmWinSize = 7;

  bool _inRhythm = false;
  int _syncTicks = 0;
  int _maxCombo = 0;

  bool _navigatingOut = false;
  bool _disposedOrExiting = false;
  bool _cleanedUp = false;

  late final ContentRepository _contentRepo;
  final CacheService _cache = CacheService();

  late final AudioLoopService _audioLoopService;

  final SessionRepository _sessionRepo = SessionRepository();
  late final DateTime _startTime;

  int _bpmSum = 0;
  int _bpmSamples = 0;

  // Packs que tienen soporte LOCAL (assets variantes). Si no, GameScreen fuerza base cuando remote=OFF.
  static const Set<String> _localSupportedPacks = {'base', 'rap'};

  bool _isRemoteEnabledFromCfg(AppConfig cfg) {
    final minOk = cfg.minAppVersionCode <= AppVersion.versionCode;
    final useRemote = cfg.flagBool('useRemoteContent', fallback: AppFlags.useRemoteContent);
    return useRemote && minOk;
  }

  // Derivar unlockedPacks desde unlockedLoops (solo keys "loop_110_rap" -> "rap")
  Set<String> _deriveUnlockedPacksFromLoops(List<String> unlockedLoops) {
    final out = <String>{'base'};
    for (final k in unlockedLoops) {
      final parts = k.split('_');
      // loop_110_rap => ["loop","110","rap"] (>=3)
      if (parts.length >= 3) {
        out.add(parts.last);
      }
    }
    return out;
  }

  String _pickEffectivePack({
    required AppConfig cfg,
    required bool isGuest,
    required bool remoteEnabled,
    required String selectedPackFromProfile,
    required Set<String> unlockedPacks,
  }) {
    final client = cfg.clientConfig;

    // Invitado: defaultPackId si está enabled, si no base
    if (isGuest) {
      final def = client.defaultPackId;
      var p = client.isPackEnabled(def) ? def : 'base';

      // Si remote OFF, solo packs locales
      if (!remoteEnabled && !_localSupportedPacks.contains(p)) p = 'base';
      return p;
    }

    // Preferencia del perfil -> si no, default
    String pack = selectedPackFromProfile.trim().isEmpty ? client.defaultPackId : selectedPackFromProfile.trim();
    if (pack.isEmpty) pack = 'base';

    // 1) Debe estar enabled en clientConfig (o base)
    if (pack != 'base' && !client.isPackEnabled(pack)) {
      pack = client.isPackEnabled(client.defaultPackId) ? client.defaultPackId : 'base';
    }

    // 2) Debe estar desbloqueado (si no es base)
    if (pack != 'base' && !unlockedPacks.contains(pack)) {
      pack = 'base';
    }

    // 3) Si remote OFF, solo packs locales
    if (!remoteEnabled && !_localSupportedPacks.contains(pack)) {
      pack = 'base';
    }

    return pack;
  }

  // ============================================================
  // ✅ NUEVO: precarga remota RAW (sin LoopDef / sin ContentRepo)
  // ============================================================
  int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  bool _toBool(dynamic v, {bool fallback = false}) {
    if (v is bool) return v;
    final s = v?.toString().toLowerCase().trim();
    if (s == 'true') return true;
    if (s == 'false') return false;
    return fallback;
  }

  String _toStr(dynamic v) => (v ?? '').toString();

  Future<List<RemoteLoopEntry>> _fetchRemoteLoopsRaw(String packId) async {
    final col = FirebaseFirestore.instance
        .collection('packs')
        .doc(packId)
        .collection('loops');

    // solo activos (igual logueamos si trae 0)
    final q = await col.where('active', isEqualTo: true).get();

    // ignore: avoid_print
    print('[GameScreen] RAW loops pack=$packId docs=${q.docs.length}');

    final out = <RemoteLoopEntry>[];
    for (final d in q.docs) {
      final m = d.data();

      final active = _toBool(m['active'], fallback: true);
      final bpmMin = _toInt(m['bpmMin']);
      final bpmMax = _toInt(m['bpmMax']);
      final url = _toStr(m['url']); // tu campo real

      if (!active) {
        // ignore: avoid_print
        print('[GameScreen] drop ${d.id} reason=inactive');
        continue;
      }
      if (url.isEmpty) {
        // ignore: avoid_print
        print('[GameScreen] drop ${d.id} reason=urlEmpty keys=${m.keys.toList()}');
        continue;
      }

      out.add(RemoteLoopEntry(
        id: d.id,
        bpmMin: bpmMin,
        bpmMax: bpmMax,
        url: url,
      ));
    }

    out.sort((a, b) => a.bpmMin.compareTo(b.bpmMin));
    // ignore: avoid_print
    print('[GameScreen] RAW ok pack=$packId kept=${out.length}');
    return out;
  }

  Future<void> _initAudioService() async {
    // -------------------------
    // 0) Perfil: selectedPack + unlockedLoops + unlockedPacks
    // -------------------------
    String selectedPack = 'base';
    List<String> unlockedLoops = const <String>[];
    Set<String> unlockedPacks = const <String>{'base'};
    bool isGuest = true;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        isGuest = false;

        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        final data = doc.data() ?? {};

        selectedPack = (data['selectedPack'] as String?) ?? 'base';

        final rawLoops = data['unlockedLoops'];
        if (rawLoops is List) {
          unlockedLoops = rawLoops.map((e) => e.toString()).toList();
        }

        final rawPacks = data['unlockedPacks'];
        if (rawPacks is List) {
          unlockedPacks = {
            'base',
            ...rawPacks.map((e) => e.toString()),
          };
        } else {
          unlockedPacks = _deriveUnlockedPacksFromLoops(unlockedLoops);
        }

        // ignore: avoid_print
        print('[GameScreen] isGuest=$isGuest selectedPack=$selectedPack unlockedLoops=${unlockedLoops.length} unlockedPacks=$unlockedPacks');
      }
    } catch (e) {
      // ignore: avoid_print
      print('[GameScreen] WARN perfil: $e');
      unlockedPacks = _deriveUnlockedPacksFromLoops(unlockedLoops);
    }

    if (_disposedOrExiting) return;

    // -------------------------
    // 1) Config + remoteEnabled
    // -------------------------
    final AppConfig cfg = await _contentRepo.getAppConfigOnce();
    final bool remoteEnabled = _isRemoteEnabledFromCfg(cfg);

    // -------------------------
    // 2) Pack Gate final
    // -------------------------
    final String packToPlay = _pickEffectivePack(
      cfg: cfg,
      isGuest: isGuest,
      remoteEnabled: remoteEnabled,
      selectedPackFromProfile: selectedPack,
      unlockedPacks: unlockedPacks,
    );

    // -------------------------
    // 3) Preload catálogo remoto (RAW) (base + packToPlay)
    // -------------------------
    final Map<String, List<RemoteLoopEntry>> remote = {};

    if (remoteEnabled) {
      try {
        // base siempre como fallback
        remote['base'] = await _fetchRemoteLoopsRaw('base');

        // pack elegido si no es base
        if (packToPlay != 'base') {
          remote[packToPlay] = await _fetchRemoteLoopsRaw(packToPlay);
        }
      } catch (e) {
        // ignore: avoid_print
        print('[GameScreen] WARN preload RAW remoto: $e');
      }
    }

    if (_disposedOrExiting) return;

    // -------------------------
    // 4) Configurar AudioLoopService
    // -------------------------
    await _audioLoopService.init();

    _audioLoopService.configurePack(
      selectedPack: packToPlay, // 👈 pack final validado
      unlockedLoops: unlockedLoops,
    );

    _audioLoopService.configureRemote(
      enabled: remoteEnabled,
      loopsByPack: remote,
    );
    // Warmup: baja base + pack actual a cache (5 + 5 archivos)
    await _audioLoopService.warmupRemoteCache(
      packId: packToPlay,
      includeBase: true,
    );


    // arrancar con bpm estable actual
    _audioLoopService.updateLoopForBpm(_stableBpm);
  }

  // -------- objetivos por modo --------
  int get _targetMin {
    switch (widget.mode) {
      case 'Caminar':
        return 80;
      case 'Trotar':
        return 110;
      case 'Correr':
        return 130;
      default:
        return 80;
    }
  }

  int get _targetMax {
    switch (widget.mode) {
      case 'Caminar':
        return 115;
      case 'Trotar':
        return 135;
      case 'Correr':
        return 170;
      default:
        return 115;
    }
  }

  String get _modeLower => widget.mode.toLowerCase();

  bool _isInTargetRange(int bpm) {
    if (bpm <= 0) return false;
    return bpm >= _targetMin && bpm <= _targetMax;
  }

  String get _tempoLabel {
    if (_stableBpm <= 0) return 'Esperando ritmo...';
    const margin = 5;

    if (_stableBpm < _targetMin - margin) return 'Vas más lento que el objetivo de $_modeLower';
    if (_stableBpm > _targetMax + margin) return 'Vas más rápido que el objetivo de $_modeLower';

    return '¡Estás en ritmo para $_modeLower!';
  }

  double get _tempoPosition {
    if (_stableBpm <= 0) return 0;
    const globalMin = 60.0;
    const globalMax = 190.0;
    final clamped = _stableBpm.clamp(globalMin.toInt(), globalMax.toInt()).toDouble();
    return (clamped - globalMin) / (globalMax - globalMin);
  }

  @override
  void initState() {
    super.initState();

    _contentRepo = ContentRepository(FirebaseFirestore.instance, cache: _cache);

    _startTime = DateTime.now();

    _rawBpm = widget.initialBpm;
    _stableBpm = widget.initialBpm;
    _steps = widget.initialSteps;

    if (_stableBpm > 0) {
      _bpmSum += _stableBpm;
      _bpmSamples++;
    }

    _audioLoopService = AudioLoopService();
    _initAudioService();

    _recalcRhythmAndCombo();

    widget.stepService.updateListener((bpmCrudo, stepsNow) {
      if (!mounted || _disposedOrExiting) return;

      setState(() {
        _rawBpm = bpmCrudo;
        _steps = stepsNow;

        _pushBpmSample(bpmCrudo);
        _stableBpm = _computeStableBpm();

        if (_stableBpm > 0) {
          _bpmSum += _stableBpm;
          _bpmSamples++;
        }

        _recalcRhythmAndCombo();
      });

      _audioLoopService.updateLoopForBpm(_stableBpm);
    });
  }

  void _pushBpmSample(int val) {
    if (val < 30 || val > 240) return;
    _bpmWindow.add(val);
    if (_bpmWindow.length > _bpmWinSize) _bpmWindow.removeAt(0);
  }

  int _computeStableBpm() {
    if (_bpmWindow.isEmpty) return _rawBpm;

    final samples = List<int>.from(_bpmWindow)..sort();
    final medianPre = samples[samples.length ~/ 2];

    final cleaned = samples.where((b) => (b - medianPre).abs() <= 20).toList();
    if (cleaned.isEmpty) return _quantizeBpm(medianPre);

    cleaned.sort();
    final median = cleaned[cleaned.length ~/ 2];
    return _quantizeBpm(median);
  }

  int _quantizeBpm(int bpm) => (bpm / 2).round() * 2;

  void _recalcRhythmAndCombo() {
    final inside = _isInTargetRange(_stableBpm);

    if (inside) {
      _syncTicks++;
      if (_syncTicks > _maxCombo) _maxCombo = _syncTicks;
    } else {
      _syncTicks = 0;
    }

    _inRhythm = inside;
  }

  Future<void> _saveSessionIfNeeded() async {
    if (_bpmSamples == 0 && _steps == 0) return;

    final endTime = DateTime.now();
    final avgBpm = _bpmSamples > 0 ? (_bpmSum / _bpmSamples).round() : _stableBpm;

    try {
      await _sessionRepo.saveSession(
        mode: widget.mode,
        steps: _steps,
        maxCombo: _maxCombo,
        avgBpm: avgBpm,
        startedAt: _startTime,
        endedAt: endTime,
      );

      final reward = await _userRepo.applySessionRewards(
        mode: widget.mode,
        steps: _steps,
        maxCombo: _maxCombo,
        avgBpm: avgBpm,
        distanceMeters: 0, // TODO: conectar distancia real
      );

      // ignore: avoid_print
      print('[GameScreen] applySessionRewards OK reward=$reward');
    } catch (e) {
      // ignore: avoid_print
      print('[GameScreen] Error guardando sesión/rewards: $e');
    }
  }

  Future<void> _finishSessionAndExit() async {
    if (_navigatingOut || !mounted) return;

    _navigatingOut = true;
    _disposedOrExiting = true;

    await _saveSessionIfNeeded();

    if (!mounted) return;
    context.go('/home');
  }

  @override
  void dispose() {
    _disposedOrExiting = true;

    if (!_cleanedUp) {
      _cleanedUp = true;
      widget.stepService.disposeService();
      _audioLoopService.stop();
      _audioLoopService.dispose();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        await _finishSessionAndExit();
        return false;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF05050A),
        appBar: AppBar(
          title: Text(
            'StepSync – ${widget.mode}',
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
    final targetText = 'Objetivo: $_targetMin–$_targetMax BPM';

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
          Text('Modo: ${widget.mode}', style: GoogleFonts.nunito(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 4),
          Text(targetText, style: GoogleFonts.nunito(color: Colors.white54, fontSize: 13)),
          const SizedBox(height: 12),
          Text(
            _stableBpm > 0 ? '$_stableBpm BPM' : '-- BPM',
            style: GoogleFonts.poppins(color: Colors.white, fontSize: 44, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text('Pasos: $_steps', style: GoogleFonts.nunito(color: Colors.white60, fontSize: 18)),
          const SizedBox(height: 16),
          Text(_tempoLabel, style: GoogleFonts.nunito(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Container(
              height: 10,
              decoration: const BoxDecoration(color: Colors.white12),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        const globalMin = 60.0;
                        const globalMax = 190.0;
                        final width = constraints.maxWidth;

                        double start = (_targetMin - globalMin) / (globalMax - globalMin);
                        double end = (_targetMax - globalMin) / (globalMax - globalMin);

                        start = start.clamp(0.0, 1.0);
                        end = end.clamp(0.0, 1.0);

                        final leftPx = width * start;
                        final rightPx = width * end;

                        return Stack(
                          children: [
                            Positioned(
                              left: leftPx,
                              right: width - rightPx,
                              top: 0,
                              bottom: 0,
                              child: Container(
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [Color(0xFF42C86D), Color(0xFF2D978C)],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  Positioned.fill(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final x = constraints.maxWidth * _tempoPosition;
                        return Align(
                          alignment: Alignment.centerLeft,
                          child: Transform.translate(
                            offset: Offset(x - 4, 0),
                            child: Container(
                              width: 8,
                              height: 10,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComboHint() {
    final good = _inRhythm;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
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
            color: (good ? const Color(0xFF42C86D) : const Color(0xFFFF6464)).withOpacity(0.35),
            blurRadius: 18,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            good ? '¡Combo x$_syncTicks!' : 'Fuera de ritmo',
            style: GoogleFonts.poppins(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            good
                ? 'Mantené el ritmo de $_modeLower para subir el combo.\nMáx: x$_maxCombo'
                : 'Volvé al rango objetivo de $_modeLower para reactivar el combo.',
            style: GoogleFonts.nunito(color: Colors.white, fontSize: 16),
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
            style: GoogleFonts.poppins(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}
