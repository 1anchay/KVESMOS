/// The approved neutral portrait remains the fallback for every cast member.
/// Names refer to hand-selected drawings, not transforms of that portrait.
abstract final class CharacterAnimationCatalog {
  static const cast = [
    'miko',
    'zig_quartz',
    'pixie',
    'aster',
    'reyvo',
    'vespa',
    'nox',
    'fox_scholar',
  ];

  static String neutral(String id) => 'assets/kvesmos/$id.png';
  static String artwork(String id, String pose) =>
      'assets/kvesmos/crew_motion/${id}_$pose.webp';

  static List<String> frames(String id, String state) {
    if (!cast.contains(id)) return [neutral(id)];
    if (state == 'idle') {
      return [id == 'pixie' ? neutral(id) : artwork(id, 'bridge')];
    }
    if (id == 'pixie') {
      return switch (state) {
        'greeting' ||
        'goodbye' ||
        'correct' ||
        'celebration' => [artwork(id, 'surprise'), artwork(id, 'happy')],
        'talking' || 'surprise' => [neutral(id), artwork(id, 'surprise')],
        _ => [neutral(id), artwork(id, 'think')],
      };
    }
    final (first, last) = switch (state) {
      'greeting' => ('happy', 'gesture'),
      'thinking' => ('support', 'think'),
      'listening' => ('surprise', 'think'),
      'correct' => ('surprise', 'happy'),
      'support' => ('think', 'support'),
      'talking' => ('think', 'talk'),
      'celebration' => ('gesture', 'happy'),
      'surprise' => ('think', 'surprise'),
      'goodbye' => ('happy', 'gesture'),
      _ => ('think', 'support'),
    };
    return [artwork(id, first), artwork(id, last)];
  }
}
