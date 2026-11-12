import 'package:flutter_test/flutter_test.dart';
import 'package:orbitwords/domain/course.dart';
import 'package:orbitwords/domain/learning_unit.dart';
import 'package:orbitwords/domain/progress.dart';

void main() {
  test('unit presentation preserves catalog order, boundaries and old IDs', () {
    final catalog = [
      for (var i = 0; i < 7; i++)
        LessonInfo(
          'old-$i',
          'Урок $i',
          i < 5 ? 'Тема' : 'Новая тема',
          i < 4 ? 'Раздел 1' : 'Раздел 2',
          'asset-$i',
          i,
        ),
    ];
    final units = LearningUnit.fromCatalog(catalog);
    expect(units.map((u) => u.lessons.length), [2, 2, 1, 2]);
    expect(units.expand((u) => u.lessons), catalog);
    final progress = ProgressSnapshot()..completed.add('old-0');
    expect(units.first.completed(progress), 1);
    expect(units.first.next(progress)?.id, 'old-1');
    expect(units.first.mastered(progress), isFalse);
    progress.completed.add('old-1');
    expect(units.first.mastered(progress), isTrue);
    expect(units.first.next(progress), isNull);
    expect(progress.xp, 0);
    expect(LearningUnit.fromCatalog([]), isEmpty);
  });
}
