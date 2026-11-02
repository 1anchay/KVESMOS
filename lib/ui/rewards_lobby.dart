import 'semantic_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/controller.dart';
import 'design.dart' show pageBody;
import 'collection_components.dart';
import 'chest_scene.dart';
import 'rewards_pages.dart' show OddsText;

class RewardsPage extends ConsumerWidget {
  const RewardsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = KvColors.of(context);
    final app = ref.watch(appProvider), catalog = app.rewards.catalog;
    final grants = app.inventory.pending.toList();
    return pageBody([
      CollectionHeading(
        'Находки экспедиции',
        'Сокровища галактики',
        trailing: const CollectionArt(
          'assets/kvesmos/pixie.png',
          label: 'Пикси',
          size: 70,
        ),
      ),
      CollectionPanel(
        color: colors.hero,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${app.inventory.unopened} ждут открытия',
                    style: TextStyle(
                      color: colors.text,
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Каждая находка — память\nо твоих открытиях.',
                    style: TextStyle(color: colors.muted, fontSize: 13),
                  ),
                ],
              ),
            ),
            const CollectionArt(
              'assets/kvesmos/explorer_closed.png',
              label: 'Контейнер исследователя',
              size: 94,
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      TextButton.icon(
        onPressed: () => context.go('/inventory'),
        icon: Icon(Icons.grid_view_rounded),
        label: Text(
          'Моя коллекция · ${app.inventory.owned.length} / ${catalog.items.length}',
        ),
      ),
      const SizedBox(height: 12),
      if (grants.isEmpty)
        CollectionPanel(
          child: Column(
            children: [
              Text(
                'Всё распаковано!',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
              ),
              const SizedBox(height: 10),
              Text(
                'Полученные предметы ждут в коллекции. Новые знания принесут следующие находки.',
              ),
              const SizedBox(height: 14),
              FilledButton(
                onPressed: () => context.go('/map'),
                child: Text('Начать миссию'),
              ),
            ],
          ),
        ),
      LayoutBuilder(
        builder: (context, c) {
          final columns = MediaQuery.textScalerOf(context).scale(16) > 24
              ? 1
              : c.maxWidth > 620
              ? 3
              : 2;
          final width = (c.maxWidth - 12 * (columns - 1)) / columns;
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final grant in grants)
                SizedBox(
                  width: width,
                  key: ValueKey(grant.id),
                  child: CollectionPanel(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        CollectionArt(
                          'assets/kvesmos/${grant.kind}_closed.png',
                          label: catalog.chest(grant.kind)['name_ru'],
                          size: 108,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          catalog.chest(grant.kind)['name_ru'],
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          grantSource(grant),
                          style: TextStyle(fontSize: 11),
                        ),
                        const SizedBox(height: 10),
                        TextButton(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            alignment: Alignment.centerLeft,
                          ),
                          onPressed: () => context.push(
                            '/chest/${Uri.encodeComponent(grant.id)}',
                          ),
                          child: Text(
                            'Открыть сундук',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
      const SizedBox(height: 28),
      const CollectionHeading('За новые знания', 'Три вида находок'),
      for (final type in catalog.chests)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: CollectionPanel(
            child: Column(
              children: [
                Row(
                  children: [
                    CollectionArt(
                      'assets/kvesmos/${type['id']}_closed.png',
                      label: type['name_ru'],
                      size: 80,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            type['name_ru'],
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                          Text(
                            'За уроки: ${catalog.milestones.where((m) => m['chest_id'] == type['id']).map((m) => m['unique_lesson_count']).join(', ')}',
                            style: TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                OddsText(catalog.odds(type['id'], app.inventory.owned)),
              ],
            ),
          ),
        ),
      Text(
        'Шансы учитывают уже собранные предметы. Внутри редкости все новые предметы равновероятны. Косметика не влияет на обучение. Коллекция хранится на этом устройстве.',
        style: TextStyle(fontSize: 12),
      ),
      TextButton(
        onPressed: () => context.go('/expeditions'),
        child: Text('Паспорт и экспедиции'),
      ),
    ]);
  }
}
