import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbitwords/domain/course.dart';
import 'support.dart';

void main() {
  setUpAll(setupSqlite);
  test(
    'twenty lessons introduce vocabulary and prerequisite skills in order',
    () {
      final map =
          jsonDecode(
                File('assets/courses/skills.json').readAsStringSync(),
              )['lessons']
              as List;
      expect(map, hasLength(20));
      final skills = <String>{}, words = <String>{};
      for (var index = 0; index < map.length; index++) {
        final row = map[index];
        expect(
          (row['requires'] as List).every(skills.contains),
          true,
          reason: row['lesson'],
        );
        skills.addAll(List<String>.from(row['provides']));
        words.addAll(List<String>.from(row['words']));
        final lesson = Lesson.fromJson(
          jsonDecode(
            File(
              'assets/courses/demo/${row['lesson']}.json',
            ).readAsStringSync(),
          ),
        );
        expect(lesson.order, index);
        expect(lesson.objective, row['objective']);
        expect(lesson.teachingSteps.length, greaterThanOrEqualTo(3));
        final answers = <String, int>{};
        for (final exercise in lesson.exercises) {
          expect(
            exercise.wordIds.every(words.contains),
            true,
            reason: exercise.id,
          );
          expect(exercise.hint, isNotEmpty);
          expect(exercise.explanation, isNotEmpty);
          answers.update(
            normalizeAnswer(exercise.answers.first),
            (v) => v + 1,
            ifAbsent: () => 1,
          );
        }
        expect(answers.values.every((v) => v <= 3), true, reason: lesson.id);
        expect(
          lesson.exercises.last.options,
          isEmpty,
          reason: 'independent recall ${lesson.id}',
        );
      }
      expect(words, hasLength(60));
    },
  );

  test(
    'eight complete story arcs resume their pinned beat and draft',
    () async {
      final repo = memoryRepository();
      await repo.initialize();
      for (final n in [2, 6, 7, 10, 12, 17, 18, 20]) {
        final id = 'a1-${n.toString().padLeft(2, '0')}';
        final material = await repo.startLesson(id);
        final beats = material.lesson.exercises
            .where((e) => e.story != null)
            .toList();
        expect(beats.map((e) => e.story!.step), [1, 2, 3]);
        expect(beats.map((e) => e.story!.id).toSet(), hasLength(1));
        for (var i = 0; i < 8; i++) {
          final e = material.lesson.exercises[i];
          await repo.answer(
            material.session.id,
            i,
            e,
            e.answers.first,
            total: 10,
          );
        }
        await repo.draft(material.session.id, 8, '{"text":"story draft"}');
        final pinned = await repo.setting(
          'kvesmos.session.material.v1:${material.session.id}',
        );
        repo.updatedMaterials[id] = repo.updatedMaterials[id]!.replaceAll(
          beats[0].story!.title,
          'Changed future story',
        );
        final resumed = await repo.startLesson(id);
        expect(resumed.session.position, 8);
        expect(resumed.session.draft, contains('story draft'));
        expect(resumed.lesson.exercises[8].story!.title, beats[0].story!.title);
        expect(
          await repo.setting(
            'kvesmos.session.material.v1:${material.session.id}',
          ),
          pinned,
        );
      }
      expect((await repo.progress()).xp, 8 * 80);
      await repo.db.close();
    },
  );
}
