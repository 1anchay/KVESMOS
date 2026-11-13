import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbitwords/data/conversation_repository.dart';
import 'package:orbitwords/data/picture_repository.dart';
import 'package:orbitwords/data/placement_repository.dart';
import 'package:orbitwords/domain/activity_calendar.dart';
import 'package:orbitwords/domain/course.dart';
import 'package:orbitwords/domain/languages.dart';
import 'package:orbitwords/domain/mistake_feedback.dart';
import 'package:orbitwords/domain/progress.dart';
import 'support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(setupSqlite);
  for (final course in StudyCourse.all) {
    test(
      '${course.language}: placement, image recall and branching preserve legacy draft and economy',
      () async {
        final repository = memoryRepository(
          now: () => DateTime(2026, 11, 12, 15),
        );
        addTearDown(repository.db.close);
        await repository.initialize();
        await repository.selectCourse(course.id);
        final legacy = await repository.startLesson(
          repository.catalog.first.id,
        );
        await repository.draft(legacy.session.id, 0, '{"text":"legacy draft"}');
        final originalEvents = (await repository.allEvents()).length;
        final placement = PlacementRepository(repository);
        var diagnostic = await placement.open();
        final questions = diagnostic['questions'] as List;
        expect(questions, hasLength(8));
        expect((await repository.allEvents()).length, originalEvents);
        for (var i = 0; i < questions.length; i++) {
          final answer = (questions[i]['answers'] as List).first as String;
          diagnostic = await placement.answer(i, answer);
          final resumed = await PlacementRepository(repository).open();
          expect(resumed['results'], diagnostic['results']);
          expect(
            (await placement.answer(i, answer))['results'],
            hasLength(i + 1),
          );
        }
        expect(diagnostic['recommendation'], repository.catalog[15].id);
        expect((await repository.allEvents()).length, originalEvents);
        expect((await repository.progress()).completed, isEmpty);

        final pictures = PictureRepository(repository);
        expect(await pictures.cards, hasLength(30));
        expect((await pictures.open())['ids'], isEmpty);
        final book = (await pictures.cards)['book']!;
        final scenes = (await Conversation.load())
            .where((s) => s.language == course.language)
            .toList();
        expect(scenes, hasLength(2));
        final requirements = {
          book.prerequisite!,
          ...scenes.map((s) => s.prerequisite),
        };
        for (final id in requirements) {
          await repository.append(
            repository.event('complete', {'lesson': id, 'session': 'seed:$id'}),
          );
        }
        final baselineXp = (await repository.progress()).xp;
        final baselineEvents = (await repository.allEvents()).length;
        var state = await pictures.open();
        expect(state['ids'], contains('book'));
        final card = (await pictures.cards)[(state['ids'] as List).first]!;
        await pictures.draft(0, 'partial');
        expect((await PictureRepository(repository).open())['text'], 'partial');
        state = await pictures.advance(
          0,
          false,
          card.pinyin.firstOrNull ?? card.bare(card.forms.first),
        );
        expect(state['correct'], true);
        await pictures.advance(0, false, card.forms.first);
        final progress = await repository.progress();
        expect(progress.words[card.word.id]!.next, isNotNull);
        expect(progress.xp, baselineXp);
        expect((await repository.allEvents()).length, baselineEvents + 1);

        for (final scene in scenes) {
          final conversation = ConversationRepository(repository, scene);
          for (var branch = 0; branch < 2; branch++) {
            final path = scene.paths[branch], other = scene.paths[1 - branch];
            expect(path.reply.text, isNot(other.reply.text));
            expect(
              (await conversation.advance(0, path.request.text))['branch'],
              branch,
            );
            expect(
              (await conversation.advance(1, other.confirmation.text))['error'],
              true,
            );
            expect(
              (await ConversationRepository(
                repository,
                scene,
              ).open())['branch'],
              branch,
            );
            expect(
              (await conversation.advance(1, path.confirmation.text))['step'],
              2,
            );
            await conversation.draft('partial reply');
            expect((await conversation.open())['text'], 'partial reply');
            expect(
              (await conversation.advance(
                2,
                path.farewell.pronunciation ?? path.farewell.text,
              ))['step'],
              3,
            );
            expect(
              (await conversation.advance(2, path.farewell.text))['step'],
              3,
            );
            await conversation.restart();
          }
        }
        expect((await repository.allEvents()).length, baselineEvents + 1);
        final resumed = await repository.startLesson(legacy.lesson.id);
        expect(resumed.session.id, legacy.session.id);
        expect(resumed.session.draft, '{"text":"legacy draft"}');
      },
    );
  }

  test(
    'calendar preserves stored day keys and excludes future days from records',
    () {
      final progress = ProgressSnapshot();
      final now = DateTime(2026, 11, 1, 23, 30);
      final empty = activityDays(progress, now, 30);
      expect(empty, hasLength(30));
      expect(empty.first.date, DateTime.utc(2026, 10, 3));
      expect(empty.every((d) => d.xp == 0 && d.lessons == 0), true);
      for (final day in empty) {
        progress.dailyXp[dayKey(day.date)] = 50;
        progress.dailyLessons[dayKey(day.date)] = 1;
      }
      progress.dailyXp['2026-11-02'] = 80;
      expect(bestActivityStreak(progress, now), 30);
      expect(progress.streak(now), 30);
      expect(
        activityDays(progress, now, 30).fold(0, (sum, day) => sum + day.xp),
        1500,
      );
    },
  );

  test(
    'all five grammar rules match the actual authored error and accepted answer',
    () {
      for (final id in [
        'en-a1-61-e06',
        'es-a1-07-e06',
        'de-a1-08-e06',
        'fr-a1-14-e05',
        'zh-a1-17-e06',
      ]) {
        final asset = id.substring(0, id.lastIndexOf('-'));
        final lesson = Lesson.fromJson(
          jsonDecode(File('assets/courses/$asset.json').readAsStringSync()),
        );
        final exercise = lesson.exercises.singleWhere((e) => e.id == id);
        final wrong = exercise.options.firstWhere(
          (o) => !checkAnswer(exercise, o),
        );
        expect(
          mistakeExplanation(exercise, wrong),
          isNot(exercise.explanation),
        );
        expect(
          mistakeExplanation(exercise, 'unknown input'),
          exercise.explanation,
        );
      }
    },
  );
}
