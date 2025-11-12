import 'package:flutter/material.dart';
import 'package:stepsync/data/loops_repository.dart';
import 'package:stepsync/data/user_level_provider.dart';

class DevPanel extends StatefulWidget {
  const DevPanel({super.key});

  @override
  State<DevPanel> createState() => _DevPanelState();
}

class _DevPanelState extends State<DevPanel> {
  final _loopsRepo = LoopsRepository();
  final _levelProv = UserLevelProvider();

  Future<void> _listarLoops() async {
    final loops = await _loopsRepo.fetchAll();
    for (final l in loops) {
      // ignore: avoid_print
      print('[LOOP] id=${l['id']} name=${l['name']} bpm=${l['bpm']} '
          'bucket=${l['bucket']} reqLevel=${l['requiredLevel']} '
          'asset=${l['localAssetPath']}');
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Loops listados en consola')),
    );
  }

  Future<void> _probarBucket(int bucket) async {
    final userLevel = await _levelProv.getCurrentUserLevel();
    final loop = await _loopsRepo.bestForBucket(bucket, userLevel);

    if (!mounted) return;
    if (loop == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No hay loop para bucket $bucket y nivel $userLevel')),
      );
      return;
    }

    final msg = 'Bucket $bucket | Nivel $userLevel → '
        '${loop['name']} (req=${loop['requiredLevel']}) asset=${loop['localAssetPath']}';
    // ignore: avoid_print
    print('[LOOP SELECT] $msg');

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('DEV Panel (Loops)', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _listarLoops,
              child: const Text('Listar loops (consola)'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => _probarBucket(90),
              child: const Text('Probar selección bucket 90'),
            ),
          ],
        ),
      ),
    );
  }
}
