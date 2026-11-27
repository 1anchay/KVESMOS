import 'package:flutter/material.dart';

import '../data/fishing_repository.dart';
import '../domain/fishing.dart';
import '../domain/fishing_story.dart';
import '../domain/knowledge.dart';
import '../domain/story_dialogue.dart';
import 'fishing_art.dart';
import 'flight_ui.dart';
import 'knowledge_widgets.dart';

String fishingMass(int grams) => grams < 1000
    ? '$grams г'
    : "${(grams / 1000).toStringAsFixed(2).replaceFirst('.', ',')} кг";

String fishingReportLine(List<FishingCatch> items) {
  if (items.isEmpty) return 'За этот вылет улова нет.';
  final names = items.map((item) => item.fish.title).toSet().join(', ');
  return [
    if (items.length == 1)
      'В улове одна рыба — $names.'
    else
      'Рыб в улове: ${items.length}. Виды — $names.',
    if (items.any((entry) => entry.discovery)) 'В атласе появился новый вид.',
    if (items.any((entry) => entry.record)) 'Ты установил личный рекорд.',
  ].join(' ');
}

StoryScene fishingReportScene(List<FishingCatch> items) =>
    items.isEmpty ? FishingStory.emptyReport : FishingStory.report;

Future<void> showFishingPanel(BuildContext context, Widget child) =>
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (_) => FractionallySizedBox(heightFactor: .86, child: child),
    );

class FishingPanel extends StatelessWidget {
  const FishingPanel(this.title, this.children, {super.key});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = FlightPalette.of(context);
    return SafeArea(
      top: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 3),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: c.text,
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                IconButton(
                  key: const Key('fishing-close-panel'),
                  tooltip: 'Закрыть',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: c.line),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}

class FishingGear extends StatefulWidget {
  const FishingGear({
    super.key,
    required this.initial,
    required this.repository,
    required this.onSaved,
    required this.language,
  });
  final FishingSave initial;
  final FishingRepository repository;
  final ValueChanged<FishingSave> onSaved;
  final LanguageContext language;

  @override
  State<FishingGear> createState() => _FishingGearState();
}

class _FishingGearState extends State<FishingGear> {
  late FishingSave save = widget.initial;
  bool busy = false;
  String? problem;

  Future<void> update({
    FishingRod? rod,
    FishingBait? bait,
    bool? comfort,
    FishingUpgrade? buy,
  }) async {
    if (busy) return;
    setState(() {
      busy = true;
      problem = null;
    });
    try {
      final next = await widget.repository.equipment(
        rod: rod,
        bait: bait,
        comfort: comfort,
        buy: buy,
      );
      widget.onSaved(next);
      if (mounted) setState(() => save = next);
    } catch (_) {
      if (mounted) {
        setState(() => problem = 'Не удалось сохранить снасти. Повтори выбор.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = FlightPalette.of(context);
    final upgrade = FishingUpgrade.values.elementAtOrNull(save.level);
    return FishingPanel('Снасти экспедиции', [
      if (problem != null) Text(problem!, style: TextStyle(color: c.warning)),
      AdaptiveTerm(
        language: widget.language,
        entry: KnowledgeCatalog.lexicon['en:word:rod:fishing']!,
      ),
      for (final rod in FishingRod.values)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: FlightControl(
            key: Key('fishing-rod-${rod.name}'),
            label: rod.title,
            icon: Icons.set_meal_outlined,
            description: rod.level > save.level
                ? '${rod.description} Откроется в мастерской.'
                : rod.description,
            selected: save.rod == rod,
            onTap: busy || rod.level > save.level
                ? null
                : () => update(rod: rod),
          ),
        ),
      AdaptiveTerm(
        language: widget.language,
        entry: KnowledgeCatalog.lexicon['en:word:bait:fishing']!,
      ),
      for (final bait in FishingBait.values)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: FlightControl(
            key: Key('fishing-bait-${bait.name}'),
            label: bait.title,
            description: bait.description,
            selected: save.bait == bait,
            onTap: busy ? null : () => update(bait: bait),
          ),
        ),
      SwitchListTile(
        key: const Key('fishing-comfort'),
        contentPadding: EdgeInsets.zero,
        title: const Text('Комфортная рыбалка'),
        subtitle: const Text(
          'Больше времени на подсечку и исправление натяжения.',
        ),
        value: save.comfort,
        onChanged: busy ? null : (value) => update(comfort: value),
      ),
      const SizedBox(height: 14),
      Text(
        'Мастерская · ${save.samples} образцов',
        style: TextStyle(
          color: c.text,
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 6),
      const Text('Каждая рыба приносит образцы для улучшения снастей.'),
      if (upgrade != null) ...[
        const SizedBox(height: 8),
        FlightControl(
          key: const Key('fishing-upgrade'),
          label: '${upgrade.title} · ${upgrade.price}',
          description: upgrade.description,
          onTap: busy || upgrade.price > save.samples
              ? null
              : () => update(buy: upgrade),
        ),
      ],
    ]);
  }
}

class FishingCollection extends StatelessWidget {
  const FishingCollection(this.save, this.language, {super.key});
  final FishingSave save;
  final LanguageContext language;

  @override
  Widget build(BuildContext context) {
    final c = FlightPalette.of(context);
    final found = save.catches.values.map((entry) => entry.fish).toSet().length;
    return FishingPanel('Атлас Нереи', [
      Text(
        'Открыто $found из ${SpaceFish.values.length} · улов ${save.catches.length}',
        key: const Key('fishing-collection-count'),
        style: TextStyle(
          color: c.text,
          fontWeight: FontWeight.w800,
          fontSize: 17,
        ),
      ),
      if (save.record > 0)
        Text('Рекорд экспедиции · ${fishingMass(save.record)}'),
      const SizedBox(height: 10),
      for (final fish in SpaceFish.values)
        _SpeciesEntry(fish, save.forSpecies(fish), language),
    ]);
  }
}

class _SpeciesEntry extends StatelessWidget {
  const _SpeciesEntry(this.fish, this.catches, this.language);
  final SpaceFish fish;
  final List<FishingCatch> catches;
  final LanguageContext language;

  @override
  Widget build(BuildContext context) {
    final c = FlightPalette.of(context);
    final locked = catches.isEmpty;
    final best = catches.fold<int>(
      0,
      (best, c) => c.result.grams > best ? c.result.grams : best,
    );
    final habitat = catches.map((c) => c.result.zone.title).toSet().join(', ');
    return Card(
      key: Key('fishing-species-${fish.name}'),
      elevation: 0,
      color: c.inset,
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Align(
              alignment: Alignment.center,
              child: FishPortrait(fish, hidden: locked, size: 138),
            ),
            Text(
              locked ? 'Неизвестный вид' : '${fish.title} · ${fish.english}',
              style: TextStyle(
                color: c.text,
                fontWeight: FontWeight.w800,
                fontSize: 17,
              ),
            ),
            const SizedBox(height: 5),
            if (locked)
              Text(
                '${fish.zone.title}. Возможная приманка — ${fish.bait.title.toLowerCase()}.',
              )
            else ...[
              Text(
                '${fish.rarity.title} · ${fish.minCm}–${fish.maxCm} см · '
                '${fishingMass(fish.minGrams)}–${fishingMass(fish.maxGrams)}',
              ),
              Text(fish.description),
              Text(
                'Место: $habitat. Улов: ${catches.length}. Рекорд: ${fishingMass(best)}.',
              ),
              AdaptiveTerm(
                language: language,
                entry: KnowledgeCatalog.fishing.firstWhere(
                  (entry) => entry.english == fish.word,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class FishingWords extends StatelessWidget {
  const FishingWords(this.language, {super.key});
  final LanguageContext language;
  static const groups = [
    ('У озера', ['Fish', 'Water', 'Lake', 'River']),
    ('В рюкзаке', ['Rod', 'Hook', 'Bait', 'Line']),
    ('Во время ловли', ['Wait', 'Pull', 'Catch', 'Small', 'Big']),
  ];

  @override
  Widget build(BuildContext context) => FishingPanel('Слова экспедиции', [
    for (final (title, words) in groups)
      ExpansionTile(
        title: Text(title),
        children: [
          for (final word in words)
            AdaptiveTerm(
              language: language,
              entry: KnowledgeCatalog.fishing.firstWhere(
                (entry) => entry.english == word,
              ),
            ),
        ],
      ),
  ]);
}
