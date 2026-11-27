import 'knowledge.dart';
import 'story_dialogue.dart';

const _need = 'en:grammar:i-need';
const _have = 'en:grammar:i-have';
const _batteryRequest = 'en:phrase:need-battery';
const _batteryFound = 'en:phrase:have-battery';
const _ready = 'en:phrase:is-ready';
const _be = 'en:grammar:be';
const _order = 'en:grammar:word-order';
const _not = 'en:grammar:negation';
const _question = 'en:grammar:questions';
const _needBattery = StoryOption('I need a battery.', 'Мне нужна батарея.');
const _haveBattery = StoryOption('I have a battery.', 'У меня есть батарея.');
const _needRule =
    'Начни с I («я»), затем need («мне нужно»), затем назови предмет. A ставится перед одним пока не уточнённым предметом. Have значит, что предмет уже есть.';
const _needExample = 'I need a key. — Мне нужен ключ.';

abstract final class FlightStory {
  static const repair = StoryScene(
    'repair',
    'Вызов из мастерской',
    StoryCue.beforeRepair,
    'call',
    {
      'call': StoryLine(
        StorySpeaker.orbi,
        'Станция зовёт нас на резервной частоте. Мико слышит нас с другого отсека. Давай сперва выясним, что нужно для генератора.',
        next: 'request',
      ),
      'request': StoryPractice(
        StorySpeaker.orbi,
        'В гнезде пусто. Попроси батарею у Мико.',
        next: 'cable',
        focus: _need,
        proves: [_batteryRequest],
        rule: _needRule,
        example: _needExample,
        tasks: [
          StoryTask(
            StoryFormat.answer,
            'Как сказать, что тебе нужна батарея?',
            ['I need a battery.'],
            options: [_haveBattery, _needBattery],
          ),
        ],
      ),
      'cable': StoryPractice(
        StorySpeaker.orbi,
        'Чтобы замкнуть цепь, нужен ещё кабель. Поможешь передать короткое сообщение на склад?',
        next: 'article',
        focus: _need,
        proves: [_order],
        rule: _needRule,
        example: _needExample,
        tasks: [
          StoryTask(
            StoryFormat.order,
            'Собери фразу «Мне нужен кабель».',
            ['I need a cable.'],
            tokens: ['cable', 'have', 'I', 'a', 'need'],
          ),
        ],
      ),
      'article': StoryPractice(
        StorySpeaker.orbi,
        'Мико уточняет, что новая антенна тоже пригодится. Antenna означает «антенна».',
        next: 'decision',
        focus: 'en:grammar:articles',
        rule:
            'A и an обозначают один предмет, о котором говорим впервые. A ставится перед согласным звуком, an — перед гласным. The указывает на уже известный предмет.',
        example:
            'A key, an engine. The key is here. — Ключ, двигатель. Этот ключ здесь.',
        tasks: [
          StoryTask(
            StoryFormat.word,
            'Дополни «I need ___ antenna».',
            ['an'],
            options: [
              StoryOption('a', 'перед согласным звуком'),
              StoryOption('an', 'перед гласным звуком'),
              StoryOption('the', 'об уже известном предмете'),
            ],
          ),
        ],
      ),
      'decision': StoryDecision(
        StorySpeaker.miko,
        'Я могу следить за частотой, пока ты у генератора. Мне сообщать тебе всё, что услышу?',
        [
          StoryChoice(
            'team',
            'Да, держим связь. Передавай всё, что услышишь.',
            'team',
            trust: StorySpeaker.miko,
          ),
          StoryChoice(
            'solo',
            'Я сам проверю генератор. Доложи только об опасности.',
            'solo',
          ),
        ],
      ),
      'team': StoryLine(
        StorySpeaker.miko,
        'Договорились. Я оставлю канал открытым и передам тебе записи, когда вернётся питание.',
      ),
      'solo': StoryLine(
        StorySpeaker.miko,
        'Хорошо. Буду слушать аварийный канал. Если обстановка изменится, я сообщу.',
      ),
    },
  );

  static const found = StoryScene(
    'battery',
    'Мико на связи',
    StoryCue.foundBattery,
    'found',
    {
      'found': StoryLine(
        StorySpeaker.miko,
        'Это батарея генератора. Сообщи мне о находке, чтобы я перестал искать вторую.',
        next: 'react',
      ),
      'react': StoryPractice(
        StorySpeaker.miko,
        'Батарея уже у тебя. Что ответишь на моё предложение поискать её?',
        next: 'radio',
        focus: _have,
        proves: [_batteryFound],
        rule:
            'Have сообщает, что предмет уже у тебя. Need сообщает, что предмет ещё нужен. В обоих случаях сначала I.',
        example: 'I have a key. — У меня есть ключ.',
        tasks: [
          StoryTask(
            StoryFormat.reaction,
            'Выбери подходящую реплику.',
            ['I have a battery.'],
            options: [_needBattery, _haveBattery],
          ),
        ],
      ),
      'radio': StoryPractice(
        StorySpeaker.miko,
        'Генератор получит твою батарею. Но у моей переносной рации пусто, а я здесь один. Передай просьбу от моего имени.',
        next: 'confirmed',
        focus: _need,
        proves: [_batteryRequest, _order],
        rule: _needRule,
        example: _needExample,
        transfer: true,
        tasks: [
          StoryTask(
            StoryFormat.order,
            'Собери фразу «Мне нужна батарея».',
            ['I need a battery.'],
            tokens: ['battery', 'I', 'have', 'a', 'need'],
          ),
        ],
      ),
      'confirmed': StoryLine(
        StorySpeaker.miko,
        'Связь есть. Запас для рации я запрошу у Пикси, а эту батарею ставь в генератор.',
        term: _batteryFound,
        sentenceSkills: [_batteryFound, _have],
      ),
    },
  );

  static const power = StoryScene(
    'power',
    'Пикси проверяет приёмник',
    StoryCue.restoredPower,
    'signal',
    {
      'signal': StoryLine(
        StorySpeaker.pixie,
        'Приёмник снова включился! Красный огонёк у передатчика ещё мигает. Давай передадим экипажу, какие приборы готовы.',
        next: 'ready',
      ),
      'ready': StoryPractice(
        StorySpeaker.pixie,
        'Приёмник готов. В сообщении it заменяет название прибора.',
        next: 'not-ready',
        focus: _be,
        proves: [_ready],
        rule:
            'С it употребляется is. Эта форма to be связывает предмет с тем, каким он сейчас является.',
        example: 'It is open. — Он открыт.',
        tasks: [
          StoryTask(
            StoryFormat.word,
            'Заполни «It ___ ready» (он готов).',
            ['is'],
            options: [
              StoryOption('are', 'форма для you, we, they'),
              StoryOption('is', 'форма для it'),
              StoryOption('am', 'форма для I'),
            ],
          ),
        ],
      ),
      'not-ready': StoryPractice(
        StorySpeaker.pixie,
        'А передатчик пока не готов. Предупреди Мико, чтобы он не нажимал пуск.',
        next: 'question',
        focus: _not,
        rule:
            'Чтобы сказать, что прибор не готов, поставь not сразу после is. It остаётся в начале.',
        example: 'It is not open. — Он не открыт.',
        tasks: [
          StoryTask(
            StoryFormat.phrase,
            'Заполни «It ___» (он не готов).',
            ['is not ready', 'isn’t ready'],
            options: [
              StoryOption('is ready', 'готов'),
              StoryOption('is not ready', 'не готов'),
              StoryOption('isn’t ready', 'не готов, сокращённо'),
            ],
          ),
        ],
      ),
      'question': StoryPractice(
        StorySpeaker.pixie,
        'Когда лампа перестанет мигать, спроси Мико о готовности передатчика.',
        next: 'done',
        focus: _question,
        rule:
            'В вопросе с to be поменяй местами is и it. Утверждение начинает it, вопрос начинает is.',
        example: 'Is it open? — Он открыт?',
        tasks: [
          StoryTask(
            StoryFormat.order,
            'Собери вопрос «Он готов?»',
            ['Is it ready?'],
            tokens: ['ready', 'it', 'Is'],
          ),
        ],
      ),
      'done': StoryLine(
        StorySpeaker.pixie,
        'Мне подтвердили готовность передатчика. Я запомню частоту станции до нашего следующего сеанса.',
        term: _ready,
        sentenceSkills: [_ready, _be],
      ),
    },
  );

  static const debrief = StoryScene(
    'debrief',
    'Последний пакет станции',
    StoryCue.launchDebrief,
    'memory',
    {
      'memory': StoryTrustLine(
        StorySpeaker.orbi,
        'Двигатели готовы. Перед вылетом проверим последний пакет станции.',
        who: StorySpeaker.miko,
        trusted: 'together',
        standard: 'direct',
      ),
      'together': StoryLine(
        StorySpeaker.miko,
        'Ты оставил канал открытым. Я сверил сигнал с нашей записью и нашёл голос диспетчера. Станции нужна батарея для рации.',
        next: 'message',
      ),
      'direct': StoryLine(
        StorySpeaker.orbi,
        'Мы проверили генератор сами. На аварийном канале пришёл короткий сигнал. Станции нужна батарея для рации.',
        next: 'message',
      ),
      'message': StoryPractice(
        StorySpeaker.pixie,
        'Перешли просьбу диспетчера в журнал станции от первого лица.',
        next: 'send',
        focus: _need,
        proves: [_batteryRequest],
        transfer: true,
        rule: _needRule,
        example: _needExample,
        tasks: [
          StoryTask(
            StoryFormat.answer,
            'Как диспетчеру сказать «Мне нужна батарея»?',
            ['I need a battery.'],
            options: [_haveBattery, _needBattery],
          ),
          StoryTask(
            StoryFormat.order,
            'Собери короткую просьбу диспетчера «Мне нужна батарея».',
            ['I need a battery.'],
            tokens: ['a', 'have', 'I', 'battery', 'need'],
            required: {
              _need: KnowledgeStage.recognized,
              _batteryRequest: KnowledgeStage.recognized,
            },
          ),
          StoryTask(
            StoryFormat.phrase,
            'Дополни сообщение станции: «I ___ for the radio.»',
            ['need a battery'],
            options: [
              StoryOption(
                'needs a battery',
                'форма needs подходит для he, she, it',
              ),
              StoryOption('need a battery', 'нужна батарея'),
              StoryOption('have a battery', 'уже есть батарея'),
            ],
            required: {
              _need: KnowledgeStage.recalled,
              _batteryRequest: KnowledgeStage.recalled,
            },
          ),
        ],
      ),
      'send': StoryDecision(
        StorySpeaker.pixie,
        'Основное сообщение готово. Отправляем?',
        [
          StoryChoice(
            'send-basic',
            'Отправить только просьбу станции.',
            'thanks',
          ),
          StoryChoice(
            'send-log',
            'Приложить запись Мико, чтобы станции было легче найти наш сигнал.',
            'log',
            requiresTrust: StorySpeaker.miko,
            trust: StorySpeaker.pixie,
          ),
        ],
      ),
      'thanks': StoryLine(
        StorySpeaker.pixie,
        'Станция получила сообщение. Ответ придёт по дороге.',
        term: _batteryRequest,
        sentenceSkills: [_batteryRequest, _need],
      ),
      'log': StoryLine(
        StorySpeaker.pixie,
        'Запись Мико помогла. Станция подтвердила курс и дала нам запасную частоту.',
        term: _batteryRequest,
        sentenceSkills: [_batteryRequest, _need],
      ),
    },
  );

  static const scenes = [repair, found, power, debrief];
  static final byId = {for (final scene in scenes) scene.id: scene};
}
