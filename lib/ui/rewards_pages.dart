export 'profile_look.dart';
export 'chest_scene.dart';
export 'wardrobe.dart';
export 'rewards_lobby.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/controller.dart';
import 'design.dart';

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
