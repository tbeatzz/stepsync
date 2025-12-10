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
    int asInt(dynamic v, {int fallback = 0}) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      return fallback;
    }

    return LoopDef(
      id: id,
      title: (data['title'] ?? '') as String,
      bpmMin: asInt(data['bpmMin'], fallback: 60),
      bpmMax: asInt(data['bpmMax'], fallback: 200),
      url: (data['url'] ?? '') as String,
      previewUrl: (data['previewUrl'] ?? '') as String,
      durationSec: asInt(data['durationSec'], fallback: 0),
      tags: ((data['tags'] as List?) ?? const []).map((e) => e.toString()).toList(),
      active: (data['active'] is bool) ? data['active'] as bool : true,
    );
  }
}
