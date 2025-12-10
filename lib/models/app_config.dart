class ClientPackCfg {
  final bool enabled;
  final int order;
  final String title;

  const ClientPackCfg({
    required this.enabled,
    required this.order,
    required this.title,
  });

  factory ClientPackCfg.fromMap(Map<String, dynamic>? data) {
    final m = data ?? const <String, dynamic>{};
    return ClientPackCfg(
      enabled: (m['enabled'] ?? false) as bool,
      order: (m['order'] ?? 0) as int,
      title: (m['title'] ?? '') as String,
    );
  }

  Map<String, dynamic> toMap() => {
    'enabled': enabled,
    'order': order,
    'title': title,
  };
}

class ClientConfig {
  final String defaultPackId;
  final Map<String, ClientPackCfg> packs;

  const ClientConfig({
    required this.defaultPackId,
    required this.packs,
  });

  factory ClientConfig.fromMap(Map<String, dynamic>? data) {
    final m = data ?? const <String, dynamic>{};

    final rawPacks = (m['packs'] as Map?)?.cast<String, dynamic>() ?? const {};
    final parsed = <String, ClientPackCfg>{};

    rawPacks.forEach((id, v) {
      if (v is Map) {
        parsed[id] = ClientPackCfg.fromMap(v.cast<String, dynamic>());
      }
    });

    return ClientConfig(
      defaultPackId: (m['defaultPackId'] ?? 'base') as String,
      packs: parsed,
    );
  }

  Map<String, dynamic> toMap() => {
    'defaultPackId': defaultPackId,
    'packs': {for (final e in packs.entries) e.key: e.value.toMap()},
  };

  bool isPackEnabled(String id) => packs[id]?.enabled ?? false;

  List<String> enabledPackIdsSorted() {
    final ids = packs.entries.where((e) => e.value.enabled).toList();
    ids.sort((a, b) => a.value.order.compareTo(b.value.order));
    return ids.map((e) => e.key).toList();
  }
}

class AppConfig {
  final int contentVersion;
  final int minAppVersionCode;
  final Map<String, dynamic> flags;
  final ClientConfig clientConfig;

  const AppConfig({
    required this.contentVersion,
    required this.minAppVersionCode,
    required this.flags,
    required this.clientConfig,
  });

  bool flagBool(String key, {bool fallback = false}) {
    final v = flags[key];
    return v is bool ? v : fallback;
  }

  factory AppConfig.fromMap(Map<String, dynamic>? data) {
    final m = data ?? const <String, dynamic>{};

    return AppConfig(
      contentVersion: (m['contentVersion'] ?? 0) as int,
      minAppVersionCode: (m['minAppVersionCode'] ?? 0) as int,
      flags: (m['flags'] as Map?)?.cast<String, dynamic>() ?? const {},
      clientConfig: ClientConfig.fromMap(
        (m['clientConfig'] as Map?)?.cast<String, dynamic>(),
      ),
    );
  }

  Map<String, dynamic> toMap() => {
    'contentVersion': contentVersion,
    'minAppVersionCode': minAppVersionCode,
    'flags': flags,
    'clientConfig': clientConfig.toMap(),
  };
}
