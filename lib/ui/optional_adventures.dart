import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/controller.dart';
import '../domain/space_adventures.dart';
import 'space_adventure_node.dart';
import 'design.dart';

class SkipAdventureButton extends ConsumerStatefulWidget {
  const SkipAdventureButton({super.key});
  @override
  ConsumerState<SkipAdventureButton> createState() =>
      _SkipAdventureButtonState();
}

class _SkipAdventureButtonState extends ConsumerState<SkipAdventureButton> {
  bool busy = false;
  @override
  Widget build(BuildContext context) => TextButton.icon(
    key: const Key('skip-adventure'),
    icon: const Icon(Icons.arrow_forward_rounded),
    label: const Text('Пропустить и продолжить уроки'),
    onPressed: busy
        ? null
        : () async {
            setState(() => busy = true);
            try {
              final app = ref.read(appProvider);
              await app.audio.stop();
              final route = await app.learningContinuationRoute();
              if (context.mounted) context.go(route);
            } catch (_) {
              if (context.mounted) {
                showMessage(
                  context,
                  'Не удалось открыть урок. Сохранение приключения осталось на месте.',
                );
              }
            } finally {
              if (mounted) setState(() => busy = false);
            }
          },
  );
}

class AdventureVisibilitySetting extends ConsumerWidget {
  const AdventureVisibilitySetting({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.watch(appProvider);
    return SwitchListTile.adaptive(
      key: const Key('show-adventures'),
      contentPadding: EdgeInsets.zero,
      title: const Text('Показывать мини-приключения на учебном пути'),
      subtitle: const Text(
        'Необязательно. Игры и их сохранения всегда доступны в разделе «Приключения».',
      ),
      value: app.showMiniAdventures,
      onChanged: (value) async {
        try {
          await app.saveAdventureVisibility(value);
        } catch (_) {
          if (context.mounted) {
            showMessage(
              context,
              'Настройка не сохранилась. Попробуйте ещё раз.',
            );
          }
        }
      },
    );
  }
}

class OptionalAdventuresPage extends StatelessWidget {
  const OptionalAdventuresPage({super.key});
  @override
  Widget build(BuildContext context) => pageBody([
    Text('Приключения', style: Theme.of(context).textTheme.headlineLarge),
    const Text(
      'Три необязательные истории. Обычные уроки доступны независимо от игр. Можно вернуться к сохранённой сцене в любой момент.',
    ),
    const SizedBox(height: 12),
    const AdventureVisibilitySetting(),
    for (final adventure in SpaceAdventure.all)
      SpaceAdventureNode(adventure: adventure),
  ]);
}
