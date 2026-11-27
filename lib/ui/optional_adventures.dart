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
      'Игровые миссии и короткие истории. Мир меняется от твоих действий, а английский помогает выполнить задачу.',
    ),
    const SizedBox(height: 12),
    Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        image: const DecorationImage(
          image: AssetImage('assets/kvesmos/scenes/observatory.webp'),
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(Color(0xaa07131e), BlendMode.srcOver),
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xff78d8ce)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'MISSION 01 · GAMEPLAY PROTOTYPE',
            style: TextStyle(
              color: Color(0xff78d8ce),
              fontSize: 11,
              letterSpacing: 1.4,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Text(
            'Lost Signal',
            style: TextStyle(
              color: Colors.white,
              fontSize: 27,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Text(
            'Исследуй Station Echo, найди предметы и восстанови питание. 5–10 минут · работает офлайн.',
            style: TextStyle(color: Colors.white),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            key: const Key('mission-lost-signal'),
            onPressed: () => context.go('/mission/lost-signal'),
            icon: const Icon(Icons.satellite_alt_rounded),
            label: const Text('Start mission'),
          ),
        ],
      ),
    ),
    const SizedBox(height: 12),
    const AdventureVisibilitySetting(),
    for (final adventure in SpaceAdventure.all)
      SpaceAdventureNode(adventure: adventure),
  ]);
}
