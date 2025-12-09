class PackUnlock {
  final String type; // "free" | "distance"
  final double? thresholdKm;

  const PackUnlock({required this.type, this.thresholdKm});

  factory PackUnlock.fromMap(Map<String, dynamic>? data) {
    final m = data ?? const <String, dynamic>{};
    return PackUnlock(
      type: (m['type'] ?? 'free') as String,
      thresholdKm: (m['thresholdKm'] is num) ? (m['thresholdKm'] as num).toDouble() : null,
    );
  }
}

class PackDef {
  final String id;
  final String name;
  final String description;
  final bool active;
  final int order;
  final PackUnlock unlock;

  const PackDef({
    required this.id,
    required this.name,
    required this.description,
    required this.active,
    required this.order,
    required this.unlock,
  });

  factory PackDef.fromFirestore(String id, Map<String, dynamic> data) {
    return PackDef(
      id: id,
      name: (data['name'] ?? '') as String,
      description: (data['description'] ?? '') as String,
      active: (data['active'] ?? true) as bool,
      order: (data['order'] ?? 0) as int,
      unlock: PackUnlock.fromMap((data['unlock'] as Map?)?.cast<String, dynamic>()),
    );
  }
}
