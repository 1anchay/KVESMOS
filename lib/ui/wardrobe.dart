import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/controller.dart';
import '../domain/rewards.dart';
import '../services/learning_audio.dart';
import 'collection_components.dart';
import 'profile_look.dart';
import 'rewards_pages.dart' show rarityNames, slotNames, rarityColor;
import 'design.dart' show pageBody;

class InventoryPage extends ConsumerStatefulWidget {
  const InventoryPage({super.key});
  @override
  ConsumerState<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends ConsumerState<InventoryPage> {
  String? slot;
  bool onlyOwned = false, resetting = false;
  String? error;
  @override
  Widget build(BuildContext context) {
    final app = ref.watch(appProvider),
        catalog = app.rewards.catalog,
        inventory = app.inventory;
    final items = catalog.items
        .where(
          (i) =>
              (slot == null || slot == i.slot) &&
              (!onlyOwned || inventory.owned.contains(i.id)),
        )
        .toList();
    return pageBody([
      const CollectionHeading('Твой стиль путешествия', 'Гардероб'),
      ProfileLook(app, showCustomizeButton: false),
      const SizedBox(height: 18),
      Row(
        children: [
          Expanded(
            child: Text(
              '${inventory.owned.length} / ${catalog.items.length} находок',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          TextButton(
            onPressed: () => context.go('/rewards'),
            child: const Text('К сундукам'),
          ),
        ],
      ),
      LinearProgressIndicator(
        value: inventory.owned.length / catalog.items.length,
        minHeight: 5,
      ),
      const SizedBox(height: 16),
      Wrap(
        spacing: 7,
        runSpacing: 7,
        children: [
          for (final e in {'': 'Все', ...slotNames}.entries)
            Semantics(
              selected: (slot ?? '') == e.key,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(48, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  backgroundColor: (slot ?? '') == e.key
                      ? Theme.of(context).colorScheme.primaryContainer
                      : null,
                  side: BorderSide(
                    color: (slot ?? '') == e.key
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                onPressed: () =>
                    setState(() => slot = e.key.isEmpty ? null : e.key),
                child: Text(e.value),
              ),
            ),
        ],
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Только полученные'),
        value: onlyOwned,
        onChanged: (v) => setState(() => onlyOwned = v),
      ),
      if (slot == 'accessory' || slot == 'emote')
        const Padding(
          padding: EdgeInsets.only(bottom: 16),
          child: Text(
            'Эмблемы и эмоции украшают отдельные слоты карточки профиля.',
          ),
        ),
      if (items.isEmpty)
        CollectionPanel(
          child: Column(
            children: [
              const CollectionArt(
                'assets/kvesmos/explorer_closed.png',
                label: 'Будущая находка',
              ),
              const Text(
                'Здесь будет твоя история',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              const Text(
                'Заверши миссию и открой первый сундук.',
                textAlign: TextAlign.center,
              ),
              TextButton(
                onPressed: () => context.go('/map'),
                child: const Text('Выбрать миссию'),
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
              for (final item in items)
                SizedBox(
                  width: width,
                  child: Semantics(
                    button: true,
                    label: '${item.name}, ${rarityNames[item.rarity]}',
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(22),
                        onTap: () => showModalBottomSheet<void>(
                          context: context,
                          isScrollControlled: true,
                          useSafeArea: true,
                          builder: (_) => CosmeticPreviewDialog(item: item),
                        ),
                        child: CollectionPanel(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Center(
                                child: CollectionArt(
                                  item.asset,
                                  label: item.name,
                                  size: 108,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                rarityNames[item.rarity]!.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 10,
                                  letterSpacing: .5,
                                  fontWeight: FontWeight.w800,
                                  color:
                                      Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? collectionMint
                                      : rarityColor(item.rarity),
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                item.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Icon(
                                    inventory.equipped[item.slot] == item.id
                                        ? Icons.check_circle
                                        : inventory.owned.contains(item.id)
                                        ? Icons.check
                                        : Icons.lock_outline,
                                    size: 17,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      inventory.equipped[item.slot] == item.id
                                          ? 'Выбрано'
                                          : inventory.owned.contains(item.id)
                                          ? 'Получено'
                                          : 'В сундуках',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
      const SizedBox(height: 18),
      if (inventory.equipped.isNotEmpty)
        TextButton.icon(
          onPressed: resetting
              ? null
              : () async {
                  setState(() => resetting = true);
                  try {
                    await app.resetAppearance();
                    await app.audio.play(SoundEffect.equip);
                  } catch (_) {
                    if (mounted) {
                      setState(
                        () => error =
                            'Не удалось сохранить оформление. Попробуйте ещё раз.',
                      );
                    }
                  } finally {
                    if (mounted) setState(() => resetting = false);
                  }
                },
          icon: const Icon(Icons.restart_alt),
          label: Text(resetting ? 'Сохраняем…' : 'Стандартное оформление'),
        ),
      if (error != null) Text(error!),
      const Text(
        'Предметы остаются в коллекции после снятия. Оформление хранится на этом устройстве.',
        style: TextStyle(fontSize: 12),
      ),
    ]);
  }
}

class CosmeticPreviewDialog extends ConsumerStatefulWidget {
  final Cosmetic item;
  const CosmeticPreviewDialog({super.key, required this.item});
  @override
  ConsumerState<CosmeticPreviewDialog> createState() => _CosmeticPreviewState();
}

class _CosmeticPreviewState extends ConsumerState<CosmeticPreviewDialog> {
  bool busy = false;
  String? error;
  @override
  Widget build(BuildContext context) {
    final app = ref.watch(appProvider), item = widget.item;
    final owned = app.inventory.owned.contains(item.id),
        equipped = app.inventory.equipped[item.slot] == item.id;
    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .92,
            maxWidth: 600,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                CollectionHeading(
                  '${rarityNames[item.rarity]} · ${slotNames[item.slot]}',
                  item.name,
                ),
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: CollectionArt(
                      item.asset,
                      label: item.name,
                      size: 112,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ProfileLook(
                  app,
                  preview: error == null ? item : null,
                  showCustomizeButton: false,
                ),
                const SizedBox(height: 16),
                Text(
                  owned
                      ? 'Примерка. Изменения сохранятся после применения.'
                      : 'Это примерка. Чтобы применить предмет, сначала получите его из сундука.',
                ),
                if (item.slot == 'accessory')
                  const Text(
                    'Аксессуар показывается отдельно на карточке профиля.',
                  ),
                const SizedBox(height: 10),
                Text(
                  owned
                      ? 'Предмет получен из заработанного сундука.'
                      : 'Источник: сундуки за обучение. Шансы указаны в находках.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (error != null)
                  Semantics(
                    liveRegion: true,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
                if (owned)
                  FilledButton(
                    key: const ValueKey('apply-cosmetic'),
                    onPressed: busy
                        ? null
                        : () async {
                            if (busy) return;
                            setState(() {
                              busy = true;
                              error = null;
                            });
                            try {
                              await app.equipCosmetic(
                                item.slot,
                                equipped ? null : item.id,
                              );
                              await app.audio.play(SoundEffect.equip);
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
      ),
    );
  }
}
