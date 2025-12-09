class AppConfig {
  final int contentVersion;
  final int minAppVersionCode;
  final Map<String, dynamic> flags;

  const AppConfig({
    required this.contentVersion,
    required this.minAppVersionCode,
    required this.flags,
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
    );
  }

  Map<String, dynamic> toMap() => {
    'contentVersion': contentVersion,
    'minAppVersionCode': minAppVersionCode,
    'flags': flags,
  };
}
