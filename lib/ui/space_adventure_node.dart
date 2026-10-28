import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/controller.dart';
import '../data/adventures_repository.dart';
import '../domain/space_adventures.dart';
import 'space_station.dart';

class SpaceAdventureNode extends ConsumerWidget {
  final SpaceAdventure adventure;
  const SpaceAdventureNode({super.key, required this.adventure});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.watch(appProvider);
    final open = adventure.unlocked(app.progress.completed);
    return FutureBuilder<AdventureState>(
      future: AdventuresRepository(app.repository).read(adventure.id),
      builder: (context, snapshot) {
        final state = snapshot.data;
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 16),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: stationInk,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: stationMint.withValues(alpha: .6)),
          ),
          child: DefaultTextStyle(
            style: Theme.of(
              context,
            ).textTheme.bodyMedium!.copyWith(color: Colors.white),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'SPACE ADVENTURES',
                  style: TextStyle(
                    color: stationMint,
                    letterSpacing: 1.5,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  adventure.title,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(adventure.subtitle),
                const SizedBox(height: 8),
                Text(
                  state?.completed == true
                      ? '✓ Печать станции получена · можно повторить'
                      : open
                      ? 'Короткая цель: ${adventure.steps.length} действий в космосе'
                      : 'После уроков: ${adventure.prerequisites.map((id) => app.repository.catalog.firstWhere((l) => l.id == id).title).join(", ")}',
                ),
                const SizedBox(height: 10),
                FilledButton.icon(
                  key: ValueKey('adventure-${adventure.id}'),
                  style: FilledButton.styleFrom(
                    backgroundColor: stationMint,
                    foregroundColor: stationInk,
                    disabledBackgroundColor: const Color(0xFF344C60),
                    disabledForegroundColor: Colors.white70,
                  ),
                  onPressed: open
                      ? () => context.go('/adventure/${adventure.id}')
                      : null,
                  icon: Icon(
                    open ? Icons.rocket_launch_outlined : Icons.lock_outline,
                  ),
                  label: Text(
                    state?.completed == true
                        ? 'Вспомнить приключение'
                        : (state?.revision ?? 0) > 0
                        ? 'Продолжить приключение'
                        : 'Войти на станцию',
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
