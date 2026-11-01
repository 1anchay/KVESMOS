import 'package:go_router/go_router.dart';
import '../domain/explorer_profile.dart';
import 'collection_components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/controller.dart';
import 'design.dart';

class AchievementShowcase extends ConsumerWidget {
  const AchievementShowcase({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.watch(appProvider);
    final selected = app.featuredAchievements
        .where(app.globalProgress.achievements.contains)
        .toList();
    final big = MediaQuery.textScalerOf(context).scale(16) > 24;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Витрина достижений',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ),
            IconButton(
              key: const ValueKey('edit-showcase'),
              tooltip: 'Выбрать достижения',
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => const _ShowcaseDialog(),
              ),
              icon: const Icon(Icons.edit_outlined, size: 20),
            ),
          ],
        ),
        LayoutBuilder(
          builder: (context, c) => Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (var i = 0; i < 3; i++)
                SizedBox(
                  width: big ? c.maxWidth : (c.maxWidth - 20) / 3,
                  child: Column(
                    children: [
                      if (i < selected.length)
                        BadgeArt(
                          ExplorerBadge.all.firstWhere(
                            (b) => b.name == selected[i],
                          ),
                          size: 76,
                        )
                      else
                        Container(
                          width: 70,
                          height: 76,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Theme.of(
                                context,
                              ).colorScheme.outlineVariant,
                            ),
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: Text(
                            '0${i + 1}',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.outline,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      const SizedBox(height: 6),
                      Text(
                        i < selected.length ? selected[i] : 'Твой значок',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        if (selected.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 10),
            child: Text(
              'Отметьте до трёх любимых достижений — они появятся здесь.',
              style: TextStyle(fontSize: 12),
            ),
          ),
        TextButton(
          onPressed: () => context.go('/achievements'),
          child: const Text('Вся коллекция'),
        ),
      ],
    );
  }
}

class AchievementCollection extends ConsumerWidget {
  const AchievementCollection({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.watch(appProvider);
    return pageBody([
      CollectionHeading(
        'Каждый шаг оставляет след',
        'Коллекция открытий',
        trailing: Text(
          '${app.globalProgress.achievements.length} / 6',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
      ),
      const Text(
        'Твои знания становятся созвездием. Значки остаются с тобой — ошибки их не отнимают.',
      ),
      const SizedBox(height: 20),
      for (final badge in ExplorerBadge.all)
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                useSafeArea: true,
                builder: (_) => _BadgeDetails(badge),
              ),
              child: CollectionPanel(
                child: LayoutBuilder(
                  builder: (context, c) {
                    final art = BadgeArt(
                      badge,
                      unlocked: badge.earned(app.globalProgress),
                      size: 92,
                    );
                    final detail = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'СТУПЕНЬ ${badge.tier} · ${badge.earned(app.globalProgress) ? 'ПОЛУЧЕНО' : 'ЗАКРЫТО'}',
                          style: TextStyle(
                            fontSize: 10,
                            letterSpacing: .7,
                            fontWeight: FontWeight.w800,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          badge.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          badge.requirement,
                          style: const TextStyle(fontSize: 12),
                        ),
                        const SizedBox(height: 10),
                        LinearProgressIndicator(
                          value:
                              (badge.value(app.globalProgress) / badge.target)
                                  .clamp(0, 1),
                          minHeight: 5,
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '${badge.value(app.globalProgress).clamp(0, badge.target)} / ${badge.target}',
                          style: const TextStyle(fontSize: 11),
                        ),
                      ],
                    );
                    return MediaQuery.textScalerOf(context).scale(16) > 24
                        ? Column(
                            children: [art, const SizedBox(height: 12), detail],
                          )
                        : Row(
                            children: [
                              art,
                              const SizedBox(width: 18),
                              Expanded(child: detail),
                            ],
                          );
                  },
                ),
              ),
            ),
          ),
        ),
      const AchievementShowcase(),
    ]);
  }
}

class _BadgeDetails extends ConsumerWidget {
  final ExplorerBadge badge;
  const _BadgeDetails(this.badge);
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.watch(appProvider),
        earned = badge.earned(app.globalProgress),
        date = app.records.badgeDates[badge.name];
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BadgeArt(badge, unlocked: earned, size: 150),
            const SizedBox(height: 18),
            Text(
              badge.name,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(badge.requirement, textAlign: TextAlign.center),
            const SizedBox(height: 14),
            Text(
              earned
                  ? 'Получено${date == null ? '' : ' · $date'}'
                  : '${badge.value(app.globalProgress)} / ${badge.target}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 20),
            if (earned)
              FilledButton(
                onPressed: () {
                  Navigator.pop(context);
                  showDialog<void>(
                    context: context,
                    builder: (_) => const _ShowcaseDialog(),
                  );
                },
                child: const Text('Настроить витрину'),
              )
            else
              FilledButton(
                onPressed: () => GoRouter.of(context).go('/map'),
                child: const Text('К следующей миссии'),
              ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Закрыть'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShowcaseDialog extends ConsumerStatefulWidget {
  const _ShowcaseDialog();
  @override
  ConsumerState<_ShowcaseDialog> createState() => _ShowcaseDialogState();
}

class _ShowcaseDialogState extends ConsumerState<_ShowcaseDialog> {
  late final Set<String> selected;
  bool busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    final app = ref.read(appProvider);
    selected = app.featuredAchievements
        .where(app.globalProgress.achievements.contains)
        .toSet();
  }

  @override
  Widget build(BuildContext context) {
    final app = ref.watch(appProvider),
        available = app.globalProgress.achievements;
    return AlertDialog(
      title: const Text('Любимые достижения'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Выбрано ${selected.length} из 3'),
              if (available.isEmpty)
                const Text('Завершите урок, чтобы получить первое достижение.'),
              for (final name in available)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: BadgeArt(
                    ExplorerBadge.all.firstWhere((b) => b.name == name),
                    size: 42,
                  ),
                  title: Text(name),
                  value: selected.contains(name),
                  onChanged:
                      busy || (!selected.contains(name) && selected.length == 3)
                      ? null
                      : (v) => setState(() {
                          if (v == true) {
                            selected.add(name);
                          } else {
                            selected.remove(name);
                          }
                        }),
                ),
              if (error != null) Text(error!),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        FilledButton(
          key: const ValueKey('save-showcase'),
          onPressed: busy
              ? null
              : () async {
                  setState(() => busy = true);
                  try {
                    await app.saveShowcase(selected.toList());
                    if (context.mounted) Navigator.pop(context);
                  } catch (_) {
                    if (mounted) {
                      setState(() {
                        busy = false;
                        error =
                            'Не удалось сохранить витрину. Попробуйте ещё раз.';
                      });
                    }
                  }
                },
          child: const Text('Сохранить'),
        ),
      ],
    );
  }
}
