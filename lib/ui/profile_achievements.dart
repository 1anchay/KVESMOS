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
        .where(app.progress.achievements.contains)
        .toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Витрина достижений',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            if (selected.isEmpty)
              const Text(
                'Отметьте до трёх любимых достижений — они появятся здесь.',
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final name in selected)
                    Chip(
                      avatar: const Icon(Icons.auto_awesome, color: starYellow),
                      label: Text(name),
                    ),
                ],
              ),
            const SizedBox(height: 8),
            TextButton.icon(
              key: const ValueKey('edit-showcase'),
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => const _ShowcaseDialog(),
              ),
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Выбрать достижения'),
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
        .where(app.progress.achievements.contains)
        .toSet();
  }

  @override
  Widget build(BuildContext context) {
    final app = ref.watch(appProvider), available = app.progress.achievements;
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
