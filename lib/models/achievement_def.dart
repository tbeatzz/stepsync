class AchievementDef {
  final String code;
  final String title;
  final String description;

  const AchievementDef({
    required this.code,
    required this.title,
    required this.description,
  });
}

// 🔹 Catálogo de logros de StepSync
const achievementDefs = <AchievementDef>[
  AchievementDef(
    code: 'first_session',
    title: 'Primera sesión',
    description: 'Completaste tu primera sesión en StepSync.',
  ),
  AchievementDef(
    code: 'ten_sessions',
    title: 'Calentando motores',
    description: 'Completaste 10 sesiones en total.',
  ),
  AchievementDef(
    code: 'combo_20',
    title: 'En trance',
    description: 'Alcanzaste un combo de x20 o más en una sesión.',
  ),
  AchievementDef(
    code: 'first_run',
    title: 'Primer sprint',
    description: 'Completaste una sesión en modo Correr.',
  ),
];
