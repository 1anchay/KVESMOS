import 'semantic_colors.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/controller.dart';
import '../domain/rewards.dart';
import '../services/learning_audio.dart';
import 'collection_components.dart';
import 'rewards_pages.dart' show rarityNames, OddsText;
import 'wardrobe.dart';
import 'character_moment.dart';

String grantSource(ChestGrant grant) =>
    grant.id.startsWith('expedition:v1:week:')
    ? 'За три учебных дня недели'
    : grant.id.startsWith('expedition:v1:month:')
    ? 'За восемь миссий месяца'
    : grant.id.startsWith('daily:')
    ? 'За выполненное задание дня'
    : 'За учебный рубеж';

/// Kept as a public name for existing callers; this is a full-screen route now.
class OpenChestDialog extends ConsumerStatefulWidget {
  final ChestGrant grant;
  const OpenChestDialog({super.key, required this.grant});
  @override
  ConsumerState<OpenChestDialog> createState() => _ChestSceneState();
}

class _ChestSceneState extends ConsumerState<OpenChestDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController animation;
  late final AppController app;
  Cosmetic? item;
  bool busy = false,
      committed = false,
      revealed = false,
      skip = false,
      fresh = false,
      sounded = false;
  String? error;
  @override
  void initState() {
    super.initState();
    app = ref.read(appProvider);
    animation =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 1800),
        )..addStatusListener((status) {
          if (status == AnimationStatus.completed && mounted) {
            setState(() => revealed = true);
            _rewardSound();
          }
        });
    // Consult current state, not a possibly stale route parameter.
    final saved = app.inventory.grants[widget.grant.id] ?? widget.grant;
    if (saved.claimed) {
      item = saved.itemId == null
          ? null
          : app.rewards.catalog.item(saved.itemId!);
      committed = true;
      revealed = true;
      skip = true;
    }
  }

  bool get reduced =>
      skip ||
      MediaQuery.disableAnimationsOf(context) ||
      !app.audio.preferences.reactions;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (committed && !revealed && reduced) animation.value = 1;
  }

  @override
  void dispose() {
    app.audio.stop();
    animation.dispose();
    super.dispose();
  }

  void _rewardSound() {
    if (!fresh || sounded || item == null) return;
    sounded = true;
    app.audio.play(switch (item!.rarity) {
      'legendary' => SoundEffect.legendary,
      'epic' => SoundEffect.epic,
      'rare' => SoundEffect.rare,
      _ => SoundEffect.correct,
    });
  }

  Future<void> open() async {
    if (busy || committed) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await app.rewards.openOnce(widget.grant.id);
      // Publishing state does not depend on the route surviving the transaction.
      await app.refresh();
      if (!mounted) return;
      setState(() {
        item = result.item;
        committed = true;
        fresh = result.fresh;
        revealed = result.item == null || !fresh || reduced;
      });
      if (!revealed) {
        app.audio.play(SoundEffect.chest);
        animation.forward();
      } else {
        _rewardSound();
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'Не удалось обновить находку. Повторите: сохранённый предмет останется тем же.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void skipReveal() {
    setState(() => skip = true);
    if (committed) {
      animation.value = 1;
    } else if (!busy) {
      open();
    }
  }

  void close() {
    if (Navigator.of(context).canPop()) {
      Navigator.pop(context);
    } else {
      GoRouter.maybeOf(context)?.go('/rewards');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = KvColors.of(context);
    ref.watch(appProvider);
    final grant = widget.grant, catalog = app.rewards.catalog;
    final accent = colors.rarity(item?.rarity);
    final next = app.inventory.grants.values
        .where((g) => !g.claimed && g.id != grant.id)
        .firstOrNull;
    final router = GoRouter.maybeOf(context);
    return Scaffold(
      backgroundColor: colors.canvas,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, bounds) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: bounds.maxHeight),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            revealed ? 'ТВОЯ КОЛЛЕКЦИЯ' : 'НАХОДКА ЭКСПЕДИЦИИ',
                            style: TextStyle(
                              color: colors.accent,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.7,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Закрыть',
                          onPressed: close,
                          icon: Icon(Icons.close, color: colors.text),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      revealed
                          ? (fresh
                                ? 'Вот это находка!'
                                : 'Твоя сохранённая находка')
                          : catalog.chest(grant.kind)['name_ru'],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      grantSource(grant),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: colors.muted, fontSize: 13),
                    ),
                    RepaintBoundary(
                      child: AnimatedBuilder(
                        animation: animation,
                        builder: (context, _) {
                          final t = animation.value,
                              opened = revealed || t >= .42;
                          final showItem = revealed || t >= .68;
                          final sceneSize = math.min(
                            280.0,
                            bounds.maxWidth - 48,
                          );
                          return SizedBox(
                            width: sceneSize,
                            height: sceneSize,
                            child: CustomPaint(
                              painter: RewardOrbitPainter(t, accent),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  if (committed)
                                    Container(
                                      width: sceneSize * .7,
                                      height: sceneSize * .7,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: RadialGradient(
                                          colors: [
                                            accent.withValues(alpha: .24),
                                            accent.withValues(alpha: 0),
                                          ],
                                        ),
                                      ),
                                    ),
                                  if (!showItem || item == null)
                                    Transform.translate(
                                      offset: Offset(
                                        0,
                                        opened
                                            ? -8
                                            : math.sin(t * math.pi * 10) *
                                                  4 *
                                                  (1 - t),
                                      ),
                                      child: Transform.rotate(
                                        angle: !opened
                                            ? math.sin(t * math.pi * 8) * .035
                                            : 0,
                                        child: AnimatedSwitcher(
                                          duration: reduced
                                              ? Duration.zero
                                              : const Duration(
                                                  milliseconds: 220,
                                                ),
                                          child: CollectionArt(
                                            'assets/kvesmos/${grant.kind}_${opened ? 'open' : 'closed'}.png',
                                            key: ValueKey(opened),
                                            label: opened
                                                ? 'Открытый сундук'
                                                : 'Сундук',
                                            size: sceneSize * .82,
                                          ),
                                        ),
                                      ),
                                    ),
                                  if (showItem && item != null)
                                    Transform.scale(
                                      scale: revealed
                                          ? 1
                                          : Curves.easeOutBack.transform(
                                              ((t - .68) / .32).clamp(0, 1),
                                            ),
                                      child: CollectionArt(
                                        item!.asset,
                                        label: item!.name,
                                        size: sceneSize * .68,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    if (!revealed) ...[
                      if (committed)
                        Text(
                          'Пикси распаковывает вашу находку…',
                          textAlign: TextAlign.center,
                        )
                      else ...[
                        Text(
                          'Твоё открытие уже близко',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        OddsText(catalog.odds(grant.kind, app.inventory.owned)),
                      ],
                      const SizedBox(height: 24),
                      if (!committed)
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: collectionMint,
                              foregroundColor: const Color(0xFF142F3B),
                            ),
                            onPressed: busy ? null : open,
                            child: Text(busy ? 'Сохраняем…' : 'Открыть'),
                          ),
                        ),
                      TextButton(
                        onPressed: skipReveal,
                        style: TextButton.styleFrom(
                          foregroundColor: colors.muted,
                        ),
                        child: Text(
                          committed ? 'Пропустить анимацию' : 'Без анимации',
                        ),
                      ),
                    ] else if (item == null) ...[
                      Text(
                        'Коллекция этого сундука собрана!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Все доступные предметы уже у тебя. Находка распакована; коллекция и история сохранены.',
                        textAlign: TextAlign.center,
                      ),
                      TextButton(onPressed: close, child: Text('Забрать')),
                    ] else ...[
                      Semantics(
                        liveRegion: true,
                        child: Column(
                          children: [
                            Wrap(
                              alignment: WrapAlignment.center,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 4,
                              children: [
                                for (
                                  var i = 0;
                                  i <
                                      switch (item!.rarity) {
                                        'rare' => 2,
                                        'epic' => 3,
                                        'legendary' => 4,
                                        _ => 1,
                                      };
                                  i++
                                )
                                  Icon(
                                    Icons.star_rounded,
                                    color: accent,
                                    size: 16,
                                  ),
                                Text(
                                  rarityNames[item!.rarity]!,
                                  style: TextStyle(
                                    color: accent,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              item!.name,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 25,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Уже сохранено в вашей коллекции',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: colors.muted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CharacterMoment(
                            characterId: 'pixie',
                            state: fresh
                                ? CharacterState.celebration
                                : CharacterState.idle,
                            animate: fresh && !reduced,
                            size: 52,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              fresh
                                  ? '«Люблю находки с историей. Эта — твоя!»'
                                  : '«Примерим твою сохранённую находку?»',
                              style: TextStyle(
                                color: colors.muted,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: accent,
                            foregroundColor: colors.dark
                                ? const Color(0xFF142F3B)
                                : Colors.white,
                          ),
                          onPressed: () => showModalBottomSheet<void>(
                            context: context,
                            isScrollControlled: true,
                            useSafeArea: true,
                            builder: (_) => CosmeticPreviewDialog(item: item!),
                          ),
                          icon: Icon(Icons.tune),
                          label: Text('Примерить находку'),
                        ),
                      ),
                      if (router != null) ...[
                        Text(
                          '${app.inventory.owned.length} / ${catalog.items.length} в коллекции · без повторов',
                          style: TextStyle(color: colors.muted, fontSize: 11),
                        ),
                        TextButton(
                          style: TextButton.styleFrom(
                            foregroundColor: colors.accent,
                          ),
                          onPressed: () => router.go('/inventory'),
                          child: Text('В коллекцию'),
                        ),

                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: colors.text,
                            side: BorderSide(color: colors.stroke),
                          ),
                          onPressed: () => router.go('/profile'),
                          icon: Icon(Icons.badge_outlined),
                          label: Text('Посмотреть профиль'),
                        ),
                        if (next != null)
                          TextButton(
                            style: TextButton.styleFrom(
                              foregroundColor: colors.accent,
                            ),
                            onPressed: () => router.replace(
                              '/chest/${Uri.encodeComponent(next.id)}',
                            ),
                            child: Text('Следующий сундук'),
                          ),
                        TextButton(
                          style: TextButton.styleFrom(
                            foregroundColor: colors.muted,
                          ),
                          onPressed: () => router.go('/map'),
                          child: Text('Продолжить обучение'),
                        ),
                      ] else
                        TextButton(onPressed: close, child: Text('Забрать')),
                    ],
                    if (error != null)
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          error!,
                          style: TextStyle(color: colors.error),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
