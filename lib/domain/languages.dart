/// Interface language stays Russian; course IDs are durable ledger metadata.
class StudyCourse {
  final String id, language, name, flag, locale, manifest;
  final int lessons;
  const StudyCourse(
    this.id,
    this.language,
    this.name,
    this.flag,
    this.locale,
    this.manifest,
    this.lessons,
  );
  static const english = StudyCourse(
    'ru-en',
    'en',
    'Английский',
    '🇬🇧',
    'en-US',
    'assets/courses/manifest.json',
    28,
  );
  static const all = [
    english,
    StudyCourse(
      'ru-es',
      'es',
      'Испанский',
      '🇪🇸',
      'es-ES',
      'assets/courses/manifest-es.json',
      6,
    ),
    StudyCourse(
      'ru-de',
      'de',
      'Немецкий',
      '🇩🇪',
      'de-DE',
      'assets/courses/manifest-de.json',
      6,
    ),
  ];
  static StudyCourse byId(String? id) =>
      all.where((c) => c.id == id).firstOrNull ?? english;
  static StudyCourse forContent(String id) =>
      id.startsWith('es-') || id.startsWith('es:')
      ? all[1]
      : id.startsWith('de-') || id.startsWith('de:')
      ? all[2]
      : english;
}
