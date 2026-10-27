import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/controller.dart';
import '../domain/rewards.dart';
import 'design.dart';
import 'galaxy_components.dart';
import 'character_reactions.dart';
import '../services/learning_audio.dart';

const rarityNames = {
  'common': 'Обычный',
  'rare': 'Редкий',
  'epic': 'Эпический',
  'legendary': 'Легендарный',
};
const slotNames = {
  'avatar': 'Аватары',
  'frame': 'Рамки',
  'background': 'Фоны',
  'accessory': 'Аксессуары',
  'emote': 'Эмоции',
};
Color rarityColor(String rarity) => switch (rarity) {
  'rare' => const Color(0xFF087E9B),
  'epic' => const Color(0xFF8050CC),
  'legendary' => const Color(0xFF996100),
  _ => const Color(0xFF51658D),
};

class RewardShortcut extends ConsumerWidget {
  const RewardShortcut({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.watch(appProvider);
    final n = app.inventory.unopened;
    final next = app.rewards.catalog.milestones
        .where((m) => m['unique_lesson_count'] > app.progress.completed.length)
        .firstOrNull;
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 10,
        ),
        leading: Image.asset(
          'assets/kvesmos/explorer_closed.png',
          width: 64,
          height: 64,
        ),
        title: Text(
          n > 0
              ? 'Вас ждут сундуки: $n'
              : next == null
              ? 'Все рубежи пройдены!'
              : 'Впереди новая находка',
        ),
        subtitle: Text(
          n > 0
              ? 'Загляните к Пикси за наградой'
              : next == null
              ? 'Ваши находки — в коллекции'
              : 'Следующий сундук: ${next['unique_lesson_count']} разных уроков',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.go('/rewards'),
      ),
    );
  }
}

class ProfileLook extends StatelessWidget {
  final AppController app;
  final Cosmetic? preview;
  final bool showCustomizeButton;
  const ProfileLook(
    this.app, {
    super.key,
    this.preview,
    this.showCustomizeButton = true,
  });
  @override
  Widget build(BuildContext context) {
    final gear = Map<String, String>.from(app.inventory.equipped);
    if (preview != null) gear[preview!.slot] = preview!.id;
    String? asset(String slot) =>
        gear[slot] == null ? null : app.rewards.catalog.item(gear[slot]!).asset;
    final background = asset('background'),
        frame = asset('frame'),
        avatar = asset('avatar');
    return Semantics(
      label: preview == null
          ? 'Оформление профиля ${app.name}'
          : 'Примерка: ${preview!.name}',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: const LinearGradient(
            colors: [Color(0xFF194793), Color(0xFF34205D)],
          ),
          image: background == null
              ? null
              : DecorationImage(
                  image: AssetImage(background),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(
                    Colors.black.withValues(alpha: .48),
                    BlendMode.darken,
                  ),
                ),
        ),
        child: LayoutBuilder(
          builder: (context, c) {
            final diameter = math.min(200.0, c.maxWidth);
            return Column(
              children: [
                SizedBox(
                  width: diameter,
                  height: diameter,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (frame != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(30),
                          child: Image.asset(
                            frame,
                            width: diameter,
                            height: diameter,
                            fit: BoxFit.fill,
                          ),
                        ),
                      Container(
                        width: diameter * (frame == null ? .86 : .61),
                        height: diameter * (frame == null ? .86 : .61),
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: starYellow, width: 3),
                          color: space,
                        ),
                        child: Image.asset(
                          avatar ?? 'assets/kvesmos/orbi_logo.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  app.name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'Команда KVESMOS · уровень ${app.progress.level}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white),
                ),
                if (asset('accessory') != null || asset('emote') != null) ...[
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    alignment: WrapAlignment.center,
                    children: [
                      for (final slot in ['accessory', 'emote'])
                        if (asset(slot) != null)
                          Tooltip(
                            message: app.rewards.catalog.item(gear[slot]!).name,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Image.asset(
                                asset(slot)!,
                                width: 66,
                                height: 66,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                    ],
                  ),
                ],
                if (showCustomizeButton) ...[
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: cosmicBlue,
                    ),
                    onPressed: () => context.go('/inventory'),
                    icon: const Icon(Icons.palette_outlined),
                    label: const Text('Настроить профиль'),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class RewardsPage extends ConsumerWidget {
  const RewardsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.watch(appProvider), catalog = app.rewards.catalog;
    return pageBody([
      const MissionHeader(
        eyebrow: 'Находки экспедиции',
        title: 'Сокровища галактики',
        subtitle: 'Каждая находка — память о твоих открытиях.',
        icon: Icons.redeem_rounded,
      ),
      CharacterReaction(
        cue: CharacterCue.pixieReady,
        eventKey: 'rewards:${app.inventory.unopened}',
        announce: false,
      ),
      const SizedBox(height: 20),
      FilledButton.icon(
        onPressed: () => context.go('/inventory'),
        icon: const Icon(Icons.grid_view_rounded),
        label: Text(
          'Моя коллекция · ${app.inventory.owned.length} / ${catalog.items.length}',
        ),
      ),
      const SectionTitle(
        'Ваши сундуки',
        subtitle:
            'За учебные рубежи, задания дня и добровольные экспедиции. Каждая награда выдаётся один раз.',
      ),
      TextButton.icon(
        onPressed: () => context.go('/expeditions'),
        icon: const Icon(Icons.auto_stories_outlined),
        label: const Text('Паспорт и экспедиции'),
      ),
      if (app.inventory.grants.isEmpty)
        const Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              'Завершите первый урок — контейнер исследователя появится здесь.',
            ),
          ),
        ),
      for (final grant in app.inventory.grants.values)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Card(
            key: ValueKey(grant.id),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: GalaxyField(
                      deep: true,
                      child: SizedBox(
                        width: double.infinity,
                        height: 180,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Image.asset(
                            'assets/kvesmos/${grant.kind}_${grant.itemId == null ? 'closed' : 'open'}.png',
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    catalog.chest(grant.kind)['name_ru'],
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(
                    grant.id.startsWith('expedition:v1:week:')
                        ? 'За три учебных дня недели'
                        : grant.id.startsWith('expedition:v1:month:')
                        ? 'За восемь разных миссий месяца'
                        : grant.id.startsWith('daily:')
                        ? 'За выполненное задание дня'
                        : 'За учебный рубеж',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  if (grant.itemId == null)
                    OddsText(catalog.odds(grant.kind, app.inventory.owned))
                  else
                    Text(
                      'Ваша находка: ${catalog.item(grant.itemId!).name}',
                      textAlign: TextAlign.center,
                    ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (_) => OpenChestDialog(grant: grant),
                    ),
                    icon: Icon(
                      grant.itemId == null
                          ? Icons.auto_awesome
                          : Icons.visibility_outlined,
                    ),
                    label: Text(
                      grant.itemId == null
                          ? 'Открыть сундук'
                          : 'Посмотреть награду',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      const SectionTitle('Впереди новые находки'),
      for (final type in catalog.chests)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Image.asset(
                  'assets/kvesmos/${type['id']}_closed.png',
                  height: 116,
                ),
                Text(
                  type['name_ru'],
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                Text(
                  'За уроки: ${catalog.milestones.where((m) => m['chest_id'] == type['id']).map((m) => m['unique_lesson_count']).join(', ')}',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                OddsText(catalog.odds(type['id'], app.inventory.owned)),
              ],
            ),
          ),
        ),
      const SizedBox(height: 16),
      const Text(
        'Шансы учитывают уже собранные предметы. Внутри редкости все новые предметы равновероятны. Косметика не влияет на обучение. Коллекция хранится на этом устройстве.',
      ),
    ]);
  }
}

class OddsText extends StatelessWidget {
  final Map<String, double> odds;
  const OddsText(this.odds, {super.key});
  @override
  Widget build(BuildContext context) => Text(
    odds.isEmpty
        ? 'Все доступные предметы этого сундука уже собраны'
        : odds.entries
              .map(
                (e) =>
                    '${rarityNames[e.key]} ${(e.value * 100).toStringAsFixed(1)}%',
              )
              .join(' · '),
    textAlign: TextAlign.center,
    style: Theme.of(context).textTheme.bodySmall,
  );
}

class OpenChestDialog extends ConsumerStatefulWidget {
  final ChestGrant grant;
  const OpenChestDialog({super.key, required this.grant});
  @override
  ConsumerState<OpenChestDialog> createState() => _OpenChestDialogState();
}

class _OpenChestDialogState extends ConsumerState<OpenChestDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController revealAnimation;
  bool committed = false;
  Cosmetic? item;
  bool busy = false, revealed = false, skip = false;
  String? error;
  late final LearningAudio audio;
  bool rewardSoundPlayed = false;
  @override
  void initState() {
    super.initState();
    audio = ref.read(appProvider).audio;
    revealAnimation =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 1400),
        )..addStatusListener((status) {
          if (status == AnimationStatus.completed && mounted) {
            setState(() => revealed = true);
            rewardSound();
          }
        });
    final id = widget.grant.itemId;
    if (id != null) {
      item = ref.read(appProvider).rewards.catalog.item(id);
      revealed = true;
      skip = true;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (committed && !revealed && MediaQuery.disableAnimationsOf(context)) {
      revealAnimation.value = 1;
    }
  }

  @override
  void dispose() {
    audio.stop();
    revealAnimation.dispose();
    super.dispose();
  }

  void rewardSound() {
    if (!committed || rewardSoundPlayed || item == null) return;
    rewardSoundPlayed = true;
    audio.play(
      ['rare', 'epic', 'legendary'].contains(item!.rarity)
          ? SoundEffect.rare
          : SoundEffect.chest,
    );
  }

  void skipReveal() {
    setState(() {
      skip = true;
      if (committed) revealed = true;
    });
    if (committed) revealAnimation.value = 1;
    if (!committed && !busy && !revealed) open();
  }

  Future<void> open() async {
    if (busy || committed || revealed) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final app = ref.read(appProvider);
      final result = await app.rewards.open(widget.grant.id);
      await app.refresh();
      if (!mounted) return;
      setState(() {
        item = result;
        committed = true;
        revealed =
            result == null || skip || MediaQuery.disableAnimationsOf(context);
      });
      if (!revealed) {
        audio.play(SoundEffect.chest);
        revealAnimation.forward();
      } else {
        revealAnimation.value = 1;
        rewardSound();
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'Не удалось сохранить награду. Попробуйте снова.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context) || skip;
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Находка Пикси',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Закрыть',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              if (!skip && !revealed)
                TextButton(
                  onPressed: skipReveal,
                  child: Text(
                    committed ? 'Пропустить анимацию' : 'Без анимации',
                  ),
                ),
              CharacterReaction(
                cue: revealed && item != null
                    ? CharacterCue.pixieReward(
                        rarityNames[item!.rarity]!,
                        fresh: committed,
                      )
                    : revealed
                    ? CharacterCue.pixieComplete
                    : CharacterCue.pixieReady,
                eventKey: '${widget.grant.id}:$revealed:${item?.id ?? 'ready'}',
              ),
              AnimatedBuilder(
                animation: revealAnimation,
                builder: (context, _) {
                  final t = revealed ? 1.0 : revealAnimation.value;
                  final opened = revealed || t >= .55;
                  final glow = committed
                      ? math.sin(math.pi * t).abs() * .7 + (revealed ? .18 : 0)
                      : 0.0;
                  return Container(
                    height: 190,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: [
                          (item == null
                                  ? starYellow
                                  : rarityColor(item!.rarity))
                              .withValues(alpha: glow.clamp(0, 1)),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: CustomPaint(
                      foregroundPainter: RewardBurst(t, starYellow, reduce),
                      child: Transform.rotate(
                        angle: reduce || t >= .55
                            ? 0
                            : math.sin(t * math.pi * 20) * .055,
                        child: Transform.scale(
                          scale: reduce ? 1 : 1 + math.sin(math.pi * t) * .08,
                          child: Image.asset(
                            'assets/kvesmos/${widget.grant.kind}_${opened ? 'open' : 'closed'}.png',
                            height: 176,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              if (committed && !revealed)
                const Text(
                  'Пикси распаковывает вашу находку…',
                  textAlign: TextAlign.center,
                ),
              if (error != null) Text(error!, semanticsLabel: error),
              if (revealed && item != null) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TweenAnimationBuilder<double>(
                      key: ValueKey(item!.id),
                      tween: Tween(begin: .85, end: 1),
                      duration: reduce
                          ? Duration.zero
                          : const Duration(milliseconds: 260),
                      curve: Curves.easeOutBack,
                      builder: (_, value, child) =>
                          Transform.scale(scale: value, child: child),
                      child: Image.asset(
                        item!.asset,
                        width: 100,
                        height: 100,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ],
                ),
                Text(
                  item!.name,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text('${rarityNames[item!.rarity]} · ${slotNames[item!.slot]}'),
                const SizedBox(height: 12),
                const Text(
                  'Уже сохранено в вашей коллекции',
                  textAlign: TextAlign.center,
                ),
                if (committed)
                  CharacterReaction(
                    cue: CharacterCue.reward,
                    eventKey: 'reward:${widget.grant.id}',
                  ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Забрать'),
                ),
              ] else if (revealed) ...[
                const Text(
                  'Все доступные предметы этого сундука уже собраны. Сундук останется у вас.',
                  textAlign: TextAlign.center,
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Понятно'),
                ),
              ] else if (!committed) ...[
                OddsText(
                  ref
                      .watch(appProvider)
                      .rewards
                      .catalog
                      .odds(
                        widget.grant.kind,
                        ref.watch(appProvider).inventory.owned,
                      ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: busy ? null : open,
                  child: Text(busy ? 'Сохраняем находку…' : 'Открыть'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class InventoryPage extends ConsumerStatefulWidget {
  const InventoryPage({super.key});
  @override
  ConsumerState<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends ConsumerState<InventoryPage> {
  String? slot;
  bool onlyOwned = false;
  @override
  Widget build(BuildContext context) {
    final app = ref.watch(appProvider),
        inventory = app.inventory,
        catalog = app.rewards.catalog;
    final items = catalog.items
        .where(
          (e) =>
              (slot == null || slot == e.slot) &&
              (!onlyOwned || inventory.owned.contains(e.id)),
        )
        .toList();
    return pageBody([
      const SectionTitle(
        'Коллекция',
        subtitle:
            'Ваши открытия, ваш стиль. Выберите полученный предмет, чтобы применить его.',
      ),
      ProfileLook(app),
      const SizedBox(height: 18),
      Text(
        '${inventory.owned.length} из ${catalog.items.length} предметов',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: 10),
      LinearProgressIndicator(
        value: inventory.owned.length / catalog.items.length,
        minHeight: 10,
      ),
      const SizedBox(height: 16),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          ChoiceChip(
            label: const Text('Все'),
            selected: slot == null,
            onSelected: (_) => setState(() => slot = null),
          ),
          for (final e in slotNames.entries)
            ChoiceChip(
              label: Text(e.value),
              selected: slot == e.key,
              onSelected: (_) => setState(() => slot = e.key),
            ),
        ],
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Только полученные'),
        value: onlyOwned,
        onChanged: (v) => setState(() => onlyOwned = v),
      ),
      if (slot == 'accessory')
        const Text(
          'Аксессуар украшает карточку профиля. Наложение на тело персонажей пока недоступно.',
        ),
      if (items.isEmpty)
        const Padding(
          padding: EdgeInsets.all(20),
          child: Text(
            'Здесь появятся ваши находки. Откройте заработанный сундук у Пикси.',
          ),
        ),
      LayoutBuilder(
        builder: (context, c) {
          final columns = c.maxWidth > 620
              ? 3
              : MediaQuery.textScalerOf(context).scale(16) > 24
              ? 1
              : 2;
          final width = (c.maxWidth - 12 * (columns - 1)) / columns;
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: items.map((item) {
              final owned = inventory.owned.contains(item.id),
                  equipped = inventory.equipped[item.slot] == item.id;
              return SizedBox(
                width: width,
                child: Card(
                  child: InkWell(
                    onTap: () => _details(context, item),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Image.asset(
                              item.asset,
                              height: 112,
                              fit: BoxFit.contain,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            item.name,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            rarityNames[item.rarity]!,
                            style: TextStyle(
                              color:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? const Color(0xFFD7C8FF)
                                  : rarityColor(item.rarity),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(
                                equipped
                                    ? Icons.check_circle
                                    : owned
                                    ? Icons.check
                                    : Icons.lock_outline,
                                size: 18,
                              ),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  equipped
                                      ? 'Выбрано'
                                      : owned
                                      ? 'Получено'
                                      : 'В сундуках',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
      const SizedBox(height: 20),
      OutlinedButton.icon(
        onPressed: () => context.go('/crew'),
        icon: const Icon(Icons.groups_outlined),
        label: const Text('Познакомиться с командой'),
      ),
    ]);
  }

  void _details(BuildContext context, Cosmetic item) => showDialog<void>(
    context: context,
    builder: (_) => CosmeticPreviewDialog(item: item),
  );
}

class CosmeticPreviewDialog extends ConsumerStatefulWidget {
  final Cosmetic item;
  const CosmeticPreviewDialog({super.key, required this.item});
  @override
  ConsumerState<CosmeticPreviewDialog> createState() =>
      _CosmeticPreviewDialogState();
}

class _CosmeticPreviewDialogState extends ConsumerState<CosmeticPreviewDialog> {
  bool busy = false;
  String? error;
  @override
  Widget build(BuildContext context) {
    final app = ref.watch(appProvider), item = widget.item;
    final owned = app.inventory.owned.contains(item.id),
        equipped = app.inventory.equipped[item.slot] == item.id;
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(item.name, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                '${rarityNames[item.rarity]} · ${slotNames[item.slot]}',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFFD7C8FF)
                      : rarityColor(item.rarity),
                ),
              ),
              const SizedBox(height: 16),
              ProfileLook(app, preview: item, showCustomizeButton: false),
              const SizedBox(height: 12),
              Text(
                owned
                    ? 'Примерка. Изменения сохранятся после применения.'
                    : 'Это примерка. Чтобы применить предмет, сначала получите его из сундука.',
              ),
              if (item.slot == 'accessory')
                const Text(
                  'Аксессуар показывается отдельно на карточке профиля.',
                ),
              if (error != null) Text(error!),
              const SizedBox(height: 16),
              if (owned)
                FilledButton(
                  key: const ValueKey('apply-cosmetic'),
                  onPressed: busy
                      ? null
                      : () async {
                          if (busy) return;
                          setState(() => busy = true);
                          try {
                            await app.equipCosmetic(
                              item.slot,
                              equipped ? null : item.id,
                            );
                            if (context.mounted) Navigator.pop(context);
                          } catch (_) {
                            if (mounted) {
                              setState(() {
                                busy = false;
                                error =
                                    'Не удалось сохранить оформление. Попробуйте ещё раз.';
                              });
                            }
                          }
                        },
                  child: Text(
                    busy
                        ? 'Сохраняем…'
                        : equipped
                        ? 'Снять'
                        : ['avatar', 'frame', 'accessory'].contains(item.slot)
                        ? 'Надеть'
                        : 'Использовать',
                  ),
                ),
              TextButton(
                onPressed: busy ? null : () => Navigator.pop(context),
                child: const Text('Отмена'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CrewPage extends ConsumerWidget {
  const CrewPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const roles = {
      'mentor': 'Ваш спутник и добрый помощник',
      'experiments': 'Инженер удивительных экспериментов',
      'onboarding': 'Навигатор новых путешествий',
      'challenges': 'Энергия и смелые открытия',
      'languages': 'Исследователь слов и языков',
      'logic': 'Детектив сложных загадок',
      'special_missions': 'Хранитель редких знаний',
      'science_and_math': 'Профессор · имя ещё не выбрано',
      'rewards': 'Хранительница наград и находок',
    };
    return pageBody([
      const SectionTitle(
        'Команда KVESMOS',
        subtitle: 'У каждого своя история. Вместе открываем галактику знаний.',
      ),
      for (final c in ref.watch(appProvider).rewards.catalog.characters)
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.asset(
                      c['asset_path'],
                      width: 90,
                      height: 108,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c['name_ru'] ?? 'Профессор',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text(roles[c['role']] ?? ''),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
    ]);
  }
}
