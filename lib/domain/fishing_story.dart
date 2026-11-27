import 'knowledge.dart';
import 'story_dialogue.dart';

abstract final class FishingStory {
  static const briefing = StoryScene(
    'fishing-briefing',
    'Приглашение на Нерею',
    StoryCue.beforeFishing,
    'invite',
    {
      'invite': StoryLine(
        StorySpeaker.pixie,
        'С запуском! На Нерее у меня есть любимое озеро. Полетим? Я покажу заросли и лунную впадину. Тебе понадобится удочка.',
        term: 'en:word:rod:fishing',
        next: 'rod',
      ),
      'rod': StoryPractice(
        StorySpeaker.pixie,
        'Попробуй попросить удочку для экспедиции. Rod означает «удочка».',
        next: 'hook',
        focus: 'en:grammar:i-need',
        proves: ['en:phrase:need-rod'],
        rule: 'Начни с I («я»). Need значит «нужно». A rod — одна удочка.',
        example: 'I need a rod. — Мне нужна удочка.',
        tasks: [
          StoryTask(
            StoryFormat.answer,
            'Как попросить удочку?',
            ['I need a rod.'],
            options: [
              StoryOption('I have a rod.', 'У меня уже есть удочка.'),
              StoryOption('I need a rod.', 'Мне нужна удочка.'),
            ],
          ),
          StoryTask(
            StoryFormat.order,
            'Собери просьбу об удочке.',
            ['I need a rod.'],
            tokens: ['rod', 'have', 'I', 'a', 'need'],
            required: {'en:grammar:i-need': KnowledgeStage.recalled},
          ),
        ],
      ),
      'hook': StoryLine(
        StorySpeaker.pixie,
        'Удочка и крючок готовы. На берегу выбери место, набери силу заброса и следи за поплавком.',
        term: 'en:phrase:have-hook',
        sentenceSkills: ['en:grammar:i-have'],
        next: 'clearance',
      ),
      'clearance': StoryTrustLine(
        StorySpeaker.pixie,
        'Маршрут проложен. Когда будешь готов, поднимайся на борт.',
        who: StorySpeaker.pixie,
        trusted: 'together',
        standard: 'departure',
      ),
      'departure': StoryLine(
        StorySpeaker.pixie,
        'Встретимся у озера. Там всё покажу.',
      ),
      'together': StoryLine(
        StorySpeaker.pixie,
        'Помнишь, как мы восстанавливали связь? Здесь тоже держимся вместе. Увидимся у озера!',
      ),
    },
  );

  static const report = StoryScene(
    'fishing-report',
    'Улов экспедиции',
    StoryCue.afterFishing,
    'report',
    {
      'report': StoryLine(
        StorySpeaker.pixie,
        'Сверим записи для бортового журнала. Fish — рыба.',
        term: 'en:word:fish:animal',
        next: 'have',
      ),
      'have': StoryPractice(
        StorySpeaker.pixie,
        'Сообщи по рации об одном экземпляре из своего улова.',
        next: 'decision',
        focus: 'en:grammar:i-have',
        proves: ['en:phrase:have-fish'],
        transfer: true,
        rule: 'I have значит «у меня есть». A fish — одна рыба.',
        example: 'I have a fish. — У меня есть рыба.',
        tasks: [
          StoryTask(
            StoryFormat.answer,
            'Как сообщить, что у тебя есть рыба?',
            ['I have a fish.'],
            options: [
              StoryOption('I need a fish.', 'Мне нужна рыба.'),
              StoryOption('I have a fish.', 'У меня есть рыба.'),
            ],
          ),
          StoryTask(
            StoryFormat.order,
            'Самостоятельно составь сообщение о рыбе.',
            ['I have a fish.'],
            tokens: ['fish', 'need', 'I', 'a', 'have'],
            required: {'en:grammar:i-have': KnowledgeStage.recalled},
          ),
        ],
      ),
      'decision': StoryDecision(
        StorySpeaker.pixie,
        'Исследователям пригодятся сведения об улове. Как поступим?',
        [
          StoryChoice(
            'share',
            'Поделиться наблюдениями со станцией',
            'shared',
            trust: StorySpeaker.pixie,
          ),
          StoryChoice('keep', 'Оставить заметки в бортовом журнале', 'saved'),
        ],
      ),
      'shared': StoryLine(
        StorySpeaker.pixie,
        'Отправила наблюдения. Станция ждёт нас снова! Твои находки остаются в коллекции.',
        term: 'en:phrase:have-fish',
        sentenceSkills: ['en:grammar:i-have'],
      ),
      'saved': StoryLine(
        StorySpeaker.pixie,
        'Запись осталась в твоём журнале. Можешь сверить её с коллекцией.',
        term: 'en:phrase:have-fish',
        sentenceSkills: ['en:grammar:i-have'],
      ),
    },
  );

  static const emptyReport = StoryScene(
    'fishing-empty',
    'Заметки с Нереи',
    StoryCue.afterFishing,
    'report',
    {
      'report': StoryLine(
        StorySpeaker.pixie,
        'Даже без улова мы узнали озеро. Могу в следующий раз помочь выбрать место.',
        next: 'decision',
      ),
      'decision': StoryDecision(
        StorySpeaker.pixie,
        'Как спланируем следующий вылет?',
        [
          StoryChoice(
            'together',
            'Позвать Пикси на следующую рыбалку',
            'together',
            trust: StorySpeaker.pixie,
          ),
          StoryChoice('solo', 'Самостоятельно обследовать другую зону', 'solo'),
        ],
      ),
      'together': StoryLine(
        StorySpeaker.pixie,
        'Договорились. Попробуем тихие заросли и светлячка на крючке.',
      ),
      'solo': StoryLine(
        StorySpeaker.pixie,
        'Хорошо. Можешь начать в открытой воде и плавно подтягивать леску.',
      ),
    },
  );

  static const scenes = [briefing, report, emptyReport];
}
