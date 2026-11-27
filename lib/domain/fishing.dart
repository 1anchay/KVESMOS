import 'dart:math' as math;

import '../services/learning_audio.dart' show AudioScene;
import 'story_dialogue.dart';

/// Activity time is supplied by the host and stops while the host is covered.
abstract interface class GameActivity<Result> {
  String get activityId;
  AudioScene get audioScene;
  String get courseId;
  Set<StoryCue> get storyCues;
  bool get paused;
  Result? get result;
  void pause();
  void resume();
  void advance(Duration elapsed);
}

enum FishingPhase {
  preparation,
  aiming,
  charging,
  casting,
  flight,
  waiting,
  bite,
  hooked,
  fighting,
  caught,
  escaped,
  finished,
}

enum FishingZone {
  reeds('Заросли', 'мелководье', .12, .53),
  water('Открытая вода', 'средняя глубина', .33, .79),
  trench('Лунная впадина', 'глубокая вода', .60, 1);

  const FishingZone(this.title, this.habitat, this.minDepth, this.maxDepth);
  final String title, habitat;
  final double minDepth, maxDepth;

  static FishingZone at(double bearing) =>
      values[(bearing * values.length).floor().clamp(0, values.length - 1)];
}

enum FishingRarity {
  common('Обычная', 1),
  uncommon('Необычная', 2),
  rare('Редкая', 3),
  legendary('Легендарная', 5);

  const FishingRarity(this.title, this.samples);
  final String title;
  final int samples;
}

enum FishingBait {
  spores('Споры', 'Для тихой воды и растений у берега.'),
  glimmer('Светлячок', 'Заметен в зарослях и в открытой воде.'),
  prism('Призма', 'Мерцает на глубине, привлекает крупных рыб.');

  const FishingBait(this.title, this.description);
  final String title, description;
}

enum FishingRod {
  scout('Походная', 'Прощает резкие движения катушки.', .86, .075, .94, 0),
  compass('Компас', 'Дальний и точный заброс во впадину.', 1.18, .045, 1.0, 2),
  anchor('Якорь', 'Быстрее подтягивает сильную рыбу.', .98, .025, 1.28, 3);

  const FishingRod(
    this.title,
    this.description,
    this.reach,
    this.forgiveness,
    this.reel,
    this.level,
  );
  final String title, description;
  final double reach, forgiveness, reel;
  final int level;
}

enum FishingUpgrade {
  spool('Настроить катушку', 'Шире безопасный диапазон натяжения.', 3),
  compass('Собрать удочку «Компас»', 'Больше дальность заброса.', 5),
  anchor('Собрать удочку «Якорь»', 'Быстрее вываживание.', 8);

  const FishingUpgrade(this.title, this.description, this.price);
  final String title, description;
  final int price;

  static int spent(int level) =>
      values.take(level).fold(0, (n, u) => n + u.price);
}

enum SpaceFish {
  goldenfin(
    'Goldenfin',
    'Золотопёр',
    'Греется в ярких полосах по краю озера.',
    'Small',
    FishingZone.reeds,
    FishingBait.glimmer,
    FishingRarity.common,
    18,
    34,
    220,
    690,
    .24,
    1.45,
    .42,
    2.0,
  ),
  mossfin(
    'Mossfin',
    'Мохопёр',
    'Замирает среди листьев, а затем тянет леску рывками.',
    'Hook',
    FishingZone.reeds,
    FishingBait.spores,
    FishingRarity.common,
    22,
    45,
    380,
    1160,
    .34,
    2.6,
    .29,
    1.8,
  ),
  silverdrift(
    'Silverdrift',
    'Серебряный плавник',
    'Стремительно пересекает открытое озеро.',
    'Lake',
    FishingZone.water,
    FishingBait.glimmer,
    FishingRarity.common,
    23,
    49,
    430,
    1450,
    .40,
    4.3,
    .56,
    1.55,
  ),
  crystalfin(
    'Crystalfin',
    'Кристаллопёр',
    'Плавники ловят свет у границы лунной впадины.',
    'Line',
    FishingZone.water,
    FishingBait.prism,
    FishingRarity.uncommon,
    31,
    63,
    800,
    2690,
    .53,
    2.2,
    .71,
    1.45,
  ),
  emberfish(
    'Emberfish',
    'Огненная рыба',
    'Прячется в тёплой воде под холодными скалами.',
    'Bait',
    FishingZone.trench,
    FishingBait.glimmer,
    FishingRarity.rare,
    35,
    72,
    1350,
    4100,
    .66,
    4.6,
    .68,
    1.26,
  ),
  nebulafish(
    'Nebulafish',
    'Туманная рыба',
    'Резко меняет направление, словно облако на ветру.',
    'Wait',
    FishingZone.water,
    FishingBait.spores,
    FishingRarity.rare,
    31,
    79,
    1200,
    3700,
    .60,
    3.7,
    .60,
    1.32,
  ),
  moonray(
    'Moonray',
    'Лунный скат',
    'Прижимается ко дну, а потом делает длинный бросок.',
    'Pull',
    FishingZone.trench,
    FishingBait.prism,
    FishingRarity.rare,
    65,
    120,
    2800,
    6700,
    .73,
    1.75,
    .82,
    1.22,
  ),
  leviathan(
    'Star Leviathan',
    'Звёздный левиафан',
    'Поднимается со дна на мерцание призмы.',
    'Big',
    FishingZone.trench,
    FishingBait.prism,
    FishingRarity.legendary,
    119,
    185,
    6200,
    14000,
    .92,
    3.25,
    .93,
    1.10,
  );

  const SpaceFish(
    this.english,
    this.title,
    this.description,
    this.word,
    this.zone,
    this.bait,
    this.rarity,
    this.minCm,
    this.maxCm,
    this.minGrams,
    this.maxGrams,
    this.strength,
    this.speed,
    this.depth,
    this.reaction,
  );
  final String english, title, description, word;
  final FishingZone zone;
  final FishingBait bait;
  final FishingRarity rarity;
  final int minCm, maxCm, minGrams, maxGrams;
  final double strength, speed, depth, reaction;
}

enum FishingEscape { missed, snapped, loose }

class FishingResult {
  const FishingResult.caught(this.fish, this.grams, this.cm, this.zone)
    : escape = null;
  const FishingResult.escaped(this.escape, this.zone)
    : fish = null,
      grams = 0,
      cm = 0;

  final SpaceFish? fish;
  final int grams, cm;
  final FishingZone zone;
  final FishingEscape? escape;
}

class FishingGame implements GameActivity<FishingResult> {
  FishingGame({math.Random? random}) : _random = random ?? math.Random();

  final math.Random _random;
  @override
  String get activityId => 'galactic-fishing';
  @override
  final audioScene = AudioScene.water;
  @override
  final courseId = 'ru-en';
  @override
  final storyCues = const {StoryCue.beforeFishing, StoryCue.afterFishing};

  FishingPhase phase = FishingPhase.preparation;
  @override
  bool paused = false;
  @override
  FishingResult? result;

  FishingRod rod = FishingRod.scout;
  FishingBait bait = FishingBait.glimmer;
  bool comfort = false;
  bool tuned = false;
  double bearing = .49;
  double elapsed = 0, waterTime = 0, depth = 0;
  double tension = .36, progress = 0, resistance = 0, drift = 0;
  double _wait = 0, _danger = 0, _slack = 0, _current = 0;
  double pressure = .10;
  SpaceFish? _fish;

  FishingZone get zone => FishingZone.at(bearing);
  bool get playing => switch (phase) {
    FishingPhase.preparation ||
    FishingPhase.aiming ||
    FishingPhase.caught ||
    FishingPhase.escaped ||
    FishingPhase.finished => false,
    _ => true,
  };
  bool get hasLure => switch (phase) {
    FishingPhase.flight ||
    FishingPhase.waiting ||
    FishingPhase.bite ||
    FishingPhase.hooked ||
    FishingPhase.fighting => true,
    _ => false,
  };
  SpaceFish? get hookedFish =>
      phase == FishingPhase.hooked || phase == FishingPhase.fighting
      ? _fish
      : null;
  double get power {
    if (phase != FishingPhase.charging) return depth;
    final ramp = (elapsed / (comfort ? 1.9 : 1.25)) % 2;
    return ramp <= 1 ? ramp : 2 - ramp;
  }

  double get travel => (elapsed / .72).clamp(0, 1);
  double get reactionWindow => (_fish?.reaction ?? 1.5) * (comfort ? 1.85 : 1);
  double get safeMin => .30 - rod.forgiveness - (tuned ? .03 : 0);
  double get safeMax => .70 + rod.forgiveness + (tuned ? .035 : 0);
  bool get dangerous => tension > safeMax + .09;
  bool get reeling =>
      phase == FishingPhase.fighting &&
      tension >= safeMin &&
      tension <= safeMax;

  @override
  void pause() => paused = true;
  @override
  void resume() => paused = false;

  void aim() {
    if (!paused &&
        (phase == FishingPhase.preparation ||
            phase == FishingPhase.caught ||
            phase == FishingPhase.escaped)) {
      result = null;
      _fish = null;
      depth = 0;
      _enter(FishingPhase.aiming);
    }
  }

  void point(double target) {
    if (!paused &&
        (phase == FishingPhase.aiming || phase == FishingPhase.charging)) {
      bearing = target.clamp(.03, .97);
    }
  }

  void charge() {
    if (!paused && phase == FishingPhase.aiming) _enter(FishingPhase.charging);
  }

  void cast() {
    if (paused || phase != FishingPhase.charging) return;
    depth = (.09 + power * .91 * rod.reach).clamp(.10, 1);
    _current = _random.nextDouble() * math.pi * 2;
    _fish = _findFish();
    _wait = 1.4 + _random.nextDouble() * 3.4 + (_fish!.depth - depth).abs() * 2;
    _enter(FishingPhase.casting);
  }

  void strike() {
    if (paused) return;
    if (phase == FishingPhase.waiting) {
      _escape(FishingEscape.missed);
    } else if (phase == FishingPhase.bite) {
      pressure = .10;
      tension = .41;
      progress = 0;
      drift = 0;
      resistance = 0;
      _slack = 0;
      _danger = 0;
      _enter(FishingPhase.hooked);
    }
  }

  void reel(double force) {
    if (!paused && phase == FishingPhase.fighting) pressure = force.clamp(0, 1);
  }

  void finish() {
    if (playing) result = null;
    _enter(FishingPhase.finished);
  }

  @override
  void advance(Duration elapsed) {
    if (paused) return;
    var remaining = elapsed.inMicroseconds / Duration.microsecondsPerSecond;
    while (remaining > 0) {
      final step = math.min(remaining, .025);
      remaining -= step;
      waterTime += step;
      this.elapsed += step;
      switch (phase) {
        case FishingPhase.casting when this.elapsed >= .14:
          _enter(FishingPhase.flight);
        case FishingPhase.flight when this.elapsed >= .72:
          _enter(FishingPhase.waiting);
        case FishingPhase.waiting when this.elapsed >= _wait:
          _enter(FishingPhase.bite);
        case FishingPhase.bite when this.elapsed > reactionWindow:
          _escape(FishingEscape.missed);
        case FishingPhase.hooked when this.elapsed >= .32:
          _enter(FishingPhase.fighting);
        case FishingPhase.fighting:
          _fight(step);
        default:
          break;
      }
    }
  }

  SpaceFish _findFish() {
    final habitat = zone;
    final weights = <SpaceFish, double>{};
    for (final fish in SpaceFish.values) {
      if (fish.rarity == FishingRarity.legendary &&
          (depth < .84 || habitat != fish.zone || bait != fish.bait)) {
        continue;
      }
      if (fish.rarity.index >= FishingRarity.rare.index &&
          (habitat != fish.zone || (depth - fish.depth).abs() > .28)) {
        continue;
      }
      final habitatFit = habitat == fish.zone ? 1.0 : .12;
      final depthFit = math.max(.05, 1 - (depth - fish.depth).abs() * 2.35);
      final waterDepth = depth >= habitat.minDepth && depth <= habitat.maxDepth
          ? 1.0
          : .55;
      final baitFit = bait == fish.bait ? 2.7 : .64;
      final rarity = switch (fish.rarity) {
        FishingRarity.common => 1.0,
        FishingRarity.uncommon => .62,
        FishingRarity.rare => .39,
        FishingRarity.legendary => .185,
      };
      weights[fish] = habitatFit * depthFit * waterDepth * baitFit * rarity;
    }
    var draw = _random.nextDouble() * weights.values.reduce((a, b) => a + b);
    for (final entry in weights.entries) {
      draw -= entry.value;
      if (draw <= 0) return entry.key;
    }
    return weights.keys.last;
  }

  void _fight(double step) {
    final fish = _fish!;
    final wave = math.sin(elapsed * fish.speed + _current);
    final surge = math.pow((wave + 1) / 2, 2).toDouble();
    resistance = fish.strength * (.24 + .76 * surge);
    drift =
        math.sin(elapsed * fish.speed * .72 + _current) *
        (.03 + fish.strength * .058);
    final target = .08 + .71 * pressure + resistance * .53;
    tension = (tension + (target - tension) * step * 5.5).clamp(0, 1);
    if (reeling) {
      final speed =
          (.11 + .27 * pressure) * rod.reel / (1 + .66 * fish.strength);
      progress = (progress + speed * step).clamp(0, 1);
    } else if (tension < safeMin) {
      progress = (progress - .04 * step).clamp(0, 1);
    }
    _danger = dangerous ? _danger + step : math.max(0, _danger - step * 1.6);
    _slack = tension < safeMin - .03
        ? _slack + step
        : math.max(0, _slack - step);
    if (_danger >= (comfort ? 1.75 : 1.03)) {
      _escape(FishingEscape.snapped);
    } else if (_slack >= (comfort ? 4.7 : 3.15)) {
      _escape(FishingEscape.loose);
    } else if (progress >= 1) {
      final fraction = _random.nextDouble();
      result = FishingResult.caught(
        fish,
        fish.minGrams + ((fish.maxGrams - fish.minGrams) * fraction).round(),
        fish.minCm + ((fish.maxCm - fish.minCm) * fraction).round(),
        zone,
      );
      _enter(FishingPhase.caught);
    }
  }

  void _escape(FishingEscape reason) {
    result = FishingResult.escaped(reason, zone);
    _enter(FishingPhase.escaped);
  }

  void _enter(FishingPhase next) {
    phase = next;
    elapsed = 0;
  }
}
