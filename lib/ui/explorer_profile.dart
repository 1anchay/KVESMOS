import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/controller.dart';
import '../domain/explorer_profile.dart';
import '../domain/journey.dart';
import '../domain/progress.dart';
import 'collection_components.dart';
import 'profile_look.dart';
import 'profile_achievements.dart';

class ExplorerProfile extends ConsumerWidget {
  const ExplorerProfile({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.watch(appProvider), p = app.progress;
    final next = ExplorerBadge.all
        .where((b) => !b.earned(app.globalProgress))
        .firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CollectionHeading(
          'Паспорт KVESMOS',
          'Мой профиль',
          trailing: IconButton(
            key: const ValueKey('edit-explorer-name'),
            tooltip: 'Изменить имя',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              useSafeArea: true,
              builder: (_) => const _NameEditor(),
            ),
          ),
        ),
        ProfileLook(app, showCustomizeButton: false),
        Text(
          '${app.course.name}: ${p.xp} XP · Все языки: ${app.globalProgress.xp} XP',
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, c) => Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final pair in [
                (
                  '${p.streak(app.repository.now())}',
                  'дней · рекорд ${app.records.longestStreak}',
                ),
                ('${p.completed.length}', 'миссий'),
                ('${app.inventory.owned.length}', 'находок'),
              ])
                SizedBox(
                  width: MediaQuery.textScalerOf(context).scale(16) > 24
                      ? c.maxWidth
                      : (c.maxWidth - 20) / 3,
                  child: CollectionPanel(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 12,
                    ),
                    child: Column(
                      children: [
                        Text(
                          pair.$1,
                          style: const TextStyle(
                            fontSize: 25,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          pair.$2,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        if (next != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              'Впереди: ${next.name} · ${next.value(app.globalProgress)} / ${next.target}',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        const AchievementShowcase(),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: () => context.go('/inventory'),
              icon: const Icon(Icons.tune),
              label: const Text('Мой гардероб'),
            ),
            OutlinedButton.icon(
              onPressed: () => context.go('/rewards'),
              icon: const Icon(Icons.redeem_outlined),
              label: Text('Находки · ${app.inventory.unopened}'),
            ),
            TextButton(
              onPressed: () => context.go('/expeditions'),
              child: const Text('Паспорт'),
            ),
            TextButton(
              onPressed: () => context.go('/stats'),
              child: const Text('Активность'),
            ),
          ],
        ),
        const SizedBox(height: 24),
        if (next != null)
          CollectionPanel(
            child: Row(
              children: [
                BadgeArt(next, unlocked: false, size: 64),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'СЛЕДУЮЩИЙ РУБЕЖ',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        next.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        next.requirement,
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: next.value(app.globalProgress) / next.target,
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '${next.value(app.globalProgress)} / ${next.target}',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 24),
        const CollectionHeading('Твой личный путь', 'Рекорды путешествия'),
        CollectionPanel(
          child: Column(
            children: [
              _RecordRow(
                Icons.local_fire_department_outlined,
                'Самая длинная серия',
                '${app.records.longestStreak} дн.',
              ),
              const Divider(height: 24),
              _RecordRow(
                Icons.bolt,
                'Лучший учебный день',
                '${app.records.bestDailyXp} XP',
              ),
              if (app.records.bestDay != null)
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    app.records.bestDay!,
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
              if (p.dailyXp.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 14),
                  child: Text('Первое занятие начнёт твою историю.'),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const ExplorerActivity(),
        const SizedBox(height: 24),
        const CollectionHeading('Маршрут A1', 'Освоенные области'),
        for (final region in JourneyRegion.forCourse(app.course.language))
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: CollectionPanel(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color:
                          region.complete(p.completed, app.repository.catalog)
                          ? collectionMint
                          : Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                    ),
                    child: Text(
                      '${region.index + 1}',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 20,
                        color:
                            region.complete(p.completed, app.repository.catalog)
                            ? collectionInk
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          region.title,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        Text(
                          '${region.lessons(app.repository.catalog).where((l) => p.completed.contains(l.id)).length} / ${region.lessons(app.repository.catalog).length} миссии',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  if (region.complete(p.completed, app.repository.catalog))
                    const Icon(Icons.verified_outlined),
                ],
              ),
            ),
          ),
        TextButton(
          onPressed: () => context.go('/map'),
          child: const Text('Продолжить путешествие'),
        ),
      ],
    );
  }
}

class _RecordRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _RecordRow(this.icon, this.label, this.value);
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, color: Theme.of(context).colorScheme.primary),
      const SizedBox(width: 12),
      Expanded(child: Text(label)),
      const SizedBox(width: 10),
      Flexible(
        child: Text(
          value,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
      ),
    ],
  );
}

class ExplorerActivity extends ConsumerStatefulWidget {
  const ExplorerActivity({super.key});
  @override
  ConsumerState<ExplorerActivity> createState() => _ExplorerActivityState();
}

class _ExplorerActivityState extends ConsumerState<ExplorerActivity> {
  int days = 7;
  @override
  Widget build(BuildContext context) {
    final app = ref.watch(appProvider), now = app.repository.now();
    final end = DateTime.utc(now.year, now.month, now.day);
    final dates = List.generate(
      days,
      (i) => dayKey(end.subtract(Duration(days: days - 1 - i))),
    );
    final values = dates.map((d) => app.progress.dailyXp[d] ?? 0).toList();
    final total = values.fold(0, (a, b) => a + b),
        maxValue = math.max(1, values.reduce(math.max));
    return CollectionPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 10,
            children: [
              Text(
                'Активность · $total XP',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final n in [7, 30])
                    TextButton(
                      style: TextButton.styleFrom(
                        backgroundColor: days == n
                            ? Theme.of(context).colorScheme.primaryContainer
                            : null,
                      ),
                      onPressed: () => setState(() => days = n),
                      child: Text('$n дней'),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 72,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < days; i++)
                  Expanded(
                    child: Tooltip(
                      message: '${dates[i]}: ${values[i]} XP',
                      child: Semantics(
                        label: '${dates[i]}, ${values[i]} XP',
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          height: values[i] == 0
                              ? 3
                              : 8 + values[i] / maxValue * 64,
                          decoration: BoxDecoration(
                            color: values[i] == 0
                                ? Theme.of(context).colorScheme.outlineVariant
                                : Theme.of(context).colorScheme.primary,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '${dates.first} — ${dates.last}',
            style: const TextStyle(fontSize: 11),
          ),
          if (total == 0)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('За этот период занятий пока нет.'),
            ),
          const SizedBox(height: 6),
          const Text(
            'XP за день по сохранённой истории занятий.',
            style: TextStyle(fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _NameEditor extends ConsumerStatefulWidget {
  const _NameEditor();
  @override
  ConsumerState<_NameEditor> createState() => _NameEditorState();
}

class _NameEditorState extends ConsumerState<_NameEditor> {
  late final TextEditingController name = TextEditingController(
    text: ref.read(appProvider).name,
  );
  bool busy = false;
  String? error;
  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      20,
      24,
      20,
      24 + MediaQuery.viewInsetsOf(context).bottom,
    ),
    child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const CollectionHeading('Паспорт исследователя', 'Как тебя зовут?'),
          TextField(
            controller: name,
            maxLength: 32,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Имя в профиле'),
          ),
          const SizedBox(height: 16),
          if (error != null) Text(error!),
          FilledButton(
            onPressed: busy
                ? null
                : () async {
                    setState(() => busy = true);
                    try {
                      await ref
                          .read(appProvider)
                          .savePreferences(newName: name.text);
                      if (context.mounted) Navigator.pop(context);
                    } catch (_) {
                      if (mounted) {
                        setState(() {
                          busy = false;
                          error = 'Имя не сохранено. Попробуйте ещё раз.';
                        });
                      }
                    }
                  },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    ),
  );
}
