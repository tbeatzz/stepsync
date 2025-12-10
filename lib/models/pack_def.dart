class PackUnlock {
  final String type; // "free" | "level" | "purchase" | "distance" (lo que uses)
  final double? thresholdKm;
  final int? levelRequired;
  final String? productId;

  const PackUnlock({
    required this.type,
    this.thresholdKm,
    this.levelRequired,
    this.productId,
  });

  factory PackUnlock.fromMap(Map<String, dynamic>? data) {
    final m = data ?? const <String, dynamic>{};

    double? asDouble(dynamic v) => v is num ? v.toDouble() : null;
    int? asInt(dynamic v) => v is num ? v.toInt() : null;

    return PackUnlock(
      type: (m['type'] ?? 'free') as String,
      thresholdKm: asDouble(m['thresholdKm']),
      levelRequired: asInt(m['levelRequired']),
      productId: (m['productId'] as String?),
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
    int asInt(dynamic v, {int fallback = 0}) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      return fallback;
    }

    return PackDef(
      id: id,
      name: (data['name'] ?? '') as String,
      description: (data['description'] ?? '') as String,
      active: (data['active'] is bool) ? data['active'] as bool : true,
      order: asInt(data['order']),
      unlock: PackUnlock.fromMap((data['unlock'] as Map?)?.cast<String, dynamic>()),
    );
  }
}
