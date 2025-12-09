class LoopDef {
  final String id;
  final String title;
  final int bpmMin;
  final int bpmMax;
  final String url;
  final String previewUrl;
  final int durationSec;
  final List<String> tags;
  final bool active;

  const LoopDef({
    required this.id,
    required this.title,
    required this.bpmMin,
    required this.bpmMax,
    required this.url,
    required this.previewUrl,
    required this.durationSec,
    required this.tags,
    required this.active,
  });

  factory LoopDef.fromFirestore(String id, Map<String, dynamic> data) {
    return LoopDef(
      id: id,
      title: (data['title'] ?? '') as String,
      bpmMin: (data['bpmMin'] ?? 60) as int,
      bpmMax: (data['bpmMax'] ?? 200) as int,
      url: (data['url'] ?? '') as String,
      previewUrl: (data['previewUrl'] ?? '') as String,
      durationSec: (data['durationSec'] ?? 0) as int,
      tags: ((data['tags'] as List?) ?? const []).map((e) => e.toString()).toList(),
      active: (data['active'] ?? true) as bool,
    );
  }
}
