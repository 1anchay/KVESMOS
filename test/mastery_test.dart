import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbitwords/data/mastery_repository.dart';
import 'package:orbitwords/data/practice_repository.dart';
import 'package:orbitwords/domain/learning_unit.dart';
import 'package:orbitwords/domain/languages.dart';
import 'package:orbitwords/domain/journey.dart';
import 'support.dart';

void main() {
  setUpAll(setupSqlite);
  for (final course in StudyCourse.all) {
    test(
      '${course.id}: mastery resumes, retries do not grant XP, stamp is durable',
      () async {
        final r = memoryRepository();
        addTearDown(r.db.close);
        await r.initialize();
        await r.selectCourse(course.id);
        final unit = LearningUnit.fromCatalog(r.catalog).first;
        final m = MasteryRepository(r, unit);
        await expectLater(m.open(), throwsStateError);
        for (final info in unit.lessons) {
          final run = await r.startLesson(info.id);
          for (var i = 0; i < run.lesson.exercises.length; i++) {
            final e = run.lesson.exercises[i];
            await r.answer(
              run.session.id,
              i,
              e,
              e.answers.first,
              total: run.lesson.exercises.length,
            );
          }
        }
        final before = await r.allEvents();
        var state = await m.open();
        await m.draft(0, 'draft');
        expect((await MasteryRepository(r, unit).open())['text'], 'draft');
        // Failed attempt never changes lesson unlocks or awards a stamp.
        while (state['done'] != true) {
          state = await m.advance(state['index'], false, 'wrong');
          state = await m.advance(state['index'], true, '');
        }
        expect(state['passed'], false);
        expect(await m.earned(), false);
        expect(unit.mastered(await r.progress()), true);
        // Mastery itself never changes the answer/XP ledger. Its weak list
        // feeds the existing mistakes mode, then a real SM-2 review clears it.
        expect((await r.allEvents()).map((e) => e.id), before.map((e) => e.id));
        final practice = PracticeRepository(r, mode: PracticeMode.mistakes);
        final picks = await practice.open();
        final weak = List<String>.from(state['difficult']);
        expect(picks['words'], containsAll(weak));
        final reviewed = (picks['words'] as List).first as String;
        await practice.advance(0, 0, '');
        await practice.advance(0, 1, r.vocabulary[reviewed]!.en);
        final reviewXp = (await r.progress()).xp;
        await practice.advance(0, 1, r.vocabulary[reviewed]!.en);
        expect((await r.progress()).xp, reviewXp);
        expect(
          jsonDecode((await r.setting(m.difficultKey))!),
          isNot(contains(reviewed)),
        );
        final afterReview = await r.allEvents();
        for (var replay = 0; replay < 2; replay++) {
          state = await m.open(restart: true);
          while (state['done'] != true) {
            final i = state['index'] as int;
            final item = (state['items'] as List)[i];
            state = await m.advance(
              i,
              false,
              item['pronunciation'] ?? item['phrase'],
            );
            final duplicate = await m.advance(i, false, item['phrase']);
            expect(duplicate['score'], state['score']);
            state = await m.advance(i, true, '');
            final again = await m.advance(i, true, '');
            expect(again['index'], state['index']);
          }
          expect(state['passed'], true);
          expect(await m.earned(), true);
        }
        expect(
          (await r.allEvents()).map((e) => e.id),
          afterReview.map((e) => e.id),
        );
        final regions = JourneyRegion.forCourse(
          course.language,
          catalog: r.catalog,
        );
        expect(
          regions
              .expand((region) => region.lessons(r.catalog))
              .map((l) => l.id),
          r.catalog.map((l) => l.id),
        );
        expect(
          regions.every(
            (region) => !region.title.startsWith('Маршрут разговоров'),
          ),
          true,
        );
        await r.selectCourse(course.id == 'ru-en' ? 'ru-es' : 'ru-en');
        await expectLater(m.open(), throwsStateError);
      },
    );
  }
}
