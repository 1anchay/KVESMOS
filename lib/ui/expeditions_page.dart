import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/controller.dart';
import '../domain/journey.dart';
import 'design.dart';
import 'flight_components.dart';
import 'journey_planet.dart';
import 'adventure_map.dart';

class ExpeditionsPage extends ConsumerStatefulWidget {
  const ExpeditionsPage({super.key});
  @override
  ConsumerState<ExpeditionsPage> createState() => _ExpeditionsPageState();
}

class _ExpeditionsPageState extends ConsumerState<ExpeditionsPage> {
  List<Expedition>? expeditions;
  bool enabled = false, busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final repo = ref.read(appProvider).repository;
      final optin =
          await repo.setting('kvesmos.expeditions.optin.v1') == 'true';
      final list = Expedition.fromEvents(await repo.allEvents(), repo.now());
      if (mounted) {
        setState(() {
          enabled = optin;
          expeditions = list;
          error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'Не удалось загрузить экспедиции. Попробуйте ещё раз.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = ref.watch(appProvider), type = Theme.of(context).textTheme;
    return pageBody([
      Text('Паспорт путешествий', style: type.headlineLarge),
      const SizedBox(height: 8),
      const Text(
        'Каждая печать — за уроки области выбранного языка. Экспедиции и награды общие для всех языков.',
      ),
      const SizedBox(height: 20),
      for (final region in JourneyRegion.forCourse(app.course.language)) ...[
        FlightPanel(
          accent: region.complete(
            app.progress.completed,
            app.repository.catalog,
          ),
          child: Row(
            children: [
              if (MediaQuery.textScalerOf(context).scale(14) <= 20)
                SizedBox(
                  width: 56,
                  height: 56,
                  child: CustomPaint(
                    painter: JourneyPlanetPainter(
                      region.index,
                      regionColors[region.index % regionColors.length],
                    ),
                  ),
                ),
              if (MediaQuery.textScalerOf(context).scale(14) <= 20)
                const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(region.title, style: type.titleMedium),
                    Text(
                      region.complete(
                            app.progress.completed,
                            app.repository.catalog,
                          )
                          ? 'Печать получена · ${region.subtitle}'
                          : '${region.lessons(app.repository.catalog).where((l) => app.progress.completed.contains(l.id)).length} / ${region.lessons(app.repository.catalog).length} миссии',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
      ],
      const SizedBox(height: 14),
      Text('Необязательные экспедиции', style: type.titleLarge),
      if (error != null) ...[
        Text(error!),
        TextButton(onPressed: load, child: const Text('Повторить')),
      ],
      const Text(
        'Небольшие цели недели и месяца. Отказ ничего не отнимает; уведомления не включаются.',
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Участвовать в экспедициях'),
        value: enabled,
        onChanged: busy || expeditions == null
            ? null
            : (value) async {
                setState(() => busy = true);
                try {
                  await app.repository.setSetting(
                    'kvesmos.expeditions.optin.v1',
                    '$value',
                  );
                  await app.refresh();
                  await load();
                } catch (_) {
                  if (context.mounted) {
                    showMessage(
                      context,
                      'Не удалось сохранить выбор. Попробуйте ещё раз.',
                    );
                  }
                } finally {
                  if (mounted) setState(() => busy = false);
                }
              },
      ),
      for (final e in expeditions ?? <Expedition>[]) ...[
        FlightPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(e.title, style: type.titleMedium),
              const SizedBox(height: 8),
              Text(e.detail),
              const SizedBox(height: 12),
              FlightProgress(value: e.count, target: e.target, label: e.title),
              const SizedBox(height: 8),
              Text(
                '${e.count.clamp(0, e.target)} / ${e.target} · ${app.inventory.grants.containsKey(e.id)
                    ? 'награда уже в находках'
                    : enabled
                    ? 'сундук за завершение'
                    : 'предпросмотр, участие выключено'}',
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
      ],
      OutlinedButton(
        onPressed: () => context.go('/rewards'),
        child: const Text('Мои находки'),
      ),
    ]);
  }
}
