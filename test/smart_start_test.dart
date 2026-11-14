import 'package:flutter_test/flutter_test.dart';
import 'package:orbitwords/data/smart_placement_repository.dart';
import 'package:orbitwords/domain/languages.dart';

import 'support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(setupSqlite);
  for (final course in StudyCourse.all) {
    test(
      '${course.language}: choose a later start without fictional progress',
      () async {
        final repo = memoryRepository();
        addTearDown(repo.db.close);
        await repo.initialize();
        await repo.selectCourse(course.id);
        expect(await repo.needsCourseStart(), isTrue);
        final diagnostic = SmartPlacementRepository(repo);
        var state = await diagnostic.open();
        final skills = <String>{};
        final bands = <int>{};
        while (true) {
          final item = SmartPlacementRepository.question(state);
          if (item == null) break;
          skills.add(item['skill'] as String);
          bands.add(item['band'] as int);
          state = await diagnostic.answer(
            item['id'],
            (item['answers'] as List).first,
          );
          expect((await diagnostic.open())['results'], state['results']);
        }
        expect(skills.length, greaterThanOrEqualTo(3));
        expect(bands, {0, 1, 2});
        expect(state['results'], hasLength(12));
        final target = state['recommendation'] as String;
        final index = repo.catalog.indexWhere((l) => l.id == target);
        expect(index, greaterThan(0));
        await expectLater(repo.ensureLessonAccess(target), throwsStateError);
        await repo.chooseCourseStart(target);
        expect(await repo.needsCourseStart(), isFalse);
        expect(await repo.allEvents(), isEmpty);
        expect((await repo.courseStart()).next?.id, target);
        expect((await repo.courseStart()).deferred(repo.catalog.first), isTrue);
        await repo.ensureLessonAccess(repo.catalog.first.id);
        await repo.ensureLessonAccess(target);
        final lesson = await repo.startLesson(target);
        for (final (position, item) in lesson.lesson.exercises.indexed) {
          await repo.answer(
            lesson.session.id,
            position,
            item,
            item.answers.first,
            total: lesson.lesson.exercises.length,
          );
        }
        expect((await repo.progress()).completed, {target});
        expect((await repo.courseStart()).next?.id, repo.catalog[index + 1].id);
        await repo.chooseCourseStart(repo.catalog.first.id);
        expect((await repo.courseStart()).next?.id, repo.catalog.first.id);
        expect((await repo.progress()).completed, {target});
      },
    );
  }
}
