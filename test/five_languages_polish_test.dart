import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbitwords/data/rewards_repository.dart';
import 'package:orbitwords/domain/course.dart';
import 'package:orbitwords/domain/languages.dart';
import 'package:orbitwords/domain/language_passport.dart';
import 'package:orbitwords/domain/progress.dart';
import 'package:orbitwords/domain/rewards.dart';
import 'package:orbitwords/services/recorded_speech.dart';
import 'support.dart';

void main() {
  setUpAll(setupSqlite);
  test(
    'v1 inventory preserves historical IDs; exhausted grants stay consumed after reload/reconcile',
    () async {
      final r = memoryRepository();
      addTearDown(r.db.close);
      await r.initialize();
      final catalog = RewardCatalog(
        File('assets/kvesmos/catalog.json').readAsStringSync(),
      );
      final old = jsonEncode({
        'version': 1,
        'equipped': {
          'avatar': catalog.items.firstWhere((i) => i.slot == 'avatar').id,
        },
        'grants': [
          for (final item in catalog.items)
            {
              'chestInstanceId': 'old:${item.id}',
              'kind': 'explorer',
              'itemId': item.id,
            },
          {'chestInstanceId': 'full', 'kind': 'supernova'},
        ],
      });
      await r.setSetting(RewardsRepository.storageKey, old);
      final repo = RewardsRepository(r, catalog);
      final results = await Future.wait([
        repo.openOnce('full'),
        repo.openOnce('full'),
      ]);
      expect(results.where((r) => r.fresh), hasLength(1));
      expect(results.every((r) => r.item == null), isTrue);
      final before = Inventory.decode(old),
          after = await RewardsRepository(r, catalog).reconcile();
      expect(after.grants.keys, containsAll(before.grants.keys));
      expect(after.equipped, before.equipped);
      expect(after.owned, before.owned);
      expect(after.pending, isEmpty);
      expect(after.grants['full']!.toJson()['openEventId'], 'open:full');
      expect(
        (await RewardsRepository(r, catalog).openOnce('full')).fresh,
        isFalse,
      );
    },
  );
  test(
    '0/1/2/5 passports are derived from genuine events, legacy English remains English',
    () {
      final events = <LearningEvent>[];
      expect(
        LanguagePassport.fromEvents(events).where((p) => p.started),
        isEmpty,
      );
      for (var i = 0; i < 5; i++) {
        events.add(
          LearningEvent(
            id: 'e$i',
            kind: 'answer',
            occurredAt: '2026-11-02T10:00:00Z',
            day: '2026-11-02',
            data: {
              if (i > 0) 'courseId': StudyCourse.all[i].id,
              'session': 's$i',
              'exercise': 'q$i',
              'correct': true,
              'words': <String>[],
            },
          ),
        );
        final passports = LanguagePassport.fromEvents(events);
        expect(passports.where((p) => p.started), hasLength(i + 1));
        expect(
          passports.fold(0, (n, p) => n + p.progress.xp),
          ProgressSnapshot.fromEvents(events).xp,
        );
      }
      final copy = jsonEncode(events.map((e) => e.toJson()).toList());
      LanguagePassport.fromEvents(events);
      expect(jsonEncode(events.map((e) => e.toJson()).toList()), copy);
    },
  );
  test(
    'Hanzi punctuation and chunk spacing accepted; tones, word order and French accents remain meaningful',
    () {
      Exercise ex(String answer) => Exercise(
        id: 'test',
        type: ExerciseType.order,
        prompt: '',
        answers: [answer],
        explanation: '',
      );
      expect(checkAnswer(ex('我二十岁。'), '我 二十 岁'), isTrue);
      expect(checkAnswer(ex('我二十岁。'), '二十我岁'), isFalse);
      expect(checkAnswer(ex('J’ai vingt ans.'), "j'ai vingt ans"), isTrue);
      expect(checkAnswer(ex('Ça va ?'), 'Ca va'), isFalse);
      expect(normalizeAnswer('mā'), isNot(normalizeAnswer('má')));
    },
  );
  test(
    'new manifests teach all target expressions; Mandarin has tone-marked support and usable chunks',
    () async {
      final r = memoryRepository();
      addTearDown(r.db.close);
      await r.initialize();
      for (final lang in ['fr', 'zh']) {
        await r.selectCourse('ru-$lang');
        for (final info in r.catalog) {
          final l = await r.lesson(info.id);
          expect(l.teachingSteps, hasLength(4));
          if (lang == 'zh') {
            expect(
              l.teachingSteps.every((s) => s.pronunciation != null),
              isTrue,
            );
            expect(l.vocabulary.every((s) => s.pronunciation != null), isTrue);
          }
          for (final e in l.exercises.where(
            (e) => e.type == ExerciseType.order,
          )) {
            expect(checkAnswer(e, e.tokens.join(' ')), isTrue, reason: e.id);
          }
        }
      }
    },
  );
  test(
    'existing ES/DE/FR recording packs retain both speeds and their locale',
    () {
      final recordings = RecordedSpeechCatalog.decode(
        File('assets/audio/voices/manifest.json').readAsStringSync(),
      );
      for (final lang in ['es', 'de', 'fr']) {
        final c = StudyCourse.byId('ru-$lang');
        for (final f
            in Directory('assets/courses').listSync().whereType<File>().where(
              (f) => f.path
                  .split(Platform.pathSeparator)
                  .last
                  .startsWith('$lang-a1-'),
            )) {
          final l = Lesson.fromJson(jsonDecode(f.readAsStringSync()));
          if (l.order >= (lang == 'fr' ? 32 : 42)) continue;
          final phrases = [
            ...l.teachingSteps.map((s) => s.phrase),
            ...l.vocabulary.map((s) => s.en),
            ...l.exercises.where((e) => e.audio != null).map((e) => e.audio!),
            ...l.exercises
                .where((e) => e.type == ExerciseType.dialogue)
                .expand((e) => e.answers),
          ];
          for (final phrase in phrases.where(
            (s) => !RegExp('[А-Яа-яЁё]').hasMatch(s),
          )) {
            final clip = recordings.find('aster', c.locale, phrase);
            expect(clip, isNotNull, reason: '${c.id}: $phrase');
            expect(clip!.slowAsset, isNotNull);
            expect(File(clip.asset).existsSync(), isTrue);
          }
        }
      }
      expect(recordings.find('orbi', 'fr-FR', 'Hola.'), isNull);
      expect(recordings.find('orbi', 'zh-CN', 'Hallo.'), isNull);
    },
  );
}
