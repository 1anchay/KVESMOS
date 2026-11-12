import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/controller.dart';
import '../domain/language_passport.dart';
import '../domain/progress.dart';
import 'collection_components.dart';

class LanguagePassportPanel extends ConsumerWidget {
  const LanguagePassportPanel({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.watch(appProvider), passports = app.passports;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        CollectionHeading(
          'Мои языки',
          'Изучаю языков: ${passports.where((p) => p.started).length}',
        ),
        Text(
          '${app.globalProgress.xp} XP всего · ${app.globalProgress.completed.length} уроков всех языков',
        ),
        const SizedBox(height: 12),
        for (final p in passports)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: CollectionPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '${p.course.flag} ${p.course.name}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    p.started
                        ? '${p.progress.xp} XP · ${p.progress.completed.length} / ${p.course.lessons} уроков · ${p.progress.streak(app.repository.now())} дней подряд'
                        : 'Маршрут ещё не начат',
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: p.progress.completed.length / p.course.lessons,
                  ),
                  TextButton(
                    onPressed: () => showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      useSafeArea: true,
                      builder: (_) => _CourseDetails(p, app),
                    ),
                    child: const Text('Мой путь в языке'),
                  ),
                ],
              ),
            ),
          ),
        const Text(
          'Языковые рубежи — отметки твоего пути. XP, находки и косметика общие; просмотр паспорта не выдаёт награды повторно.',
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _CourseDetails extends StatelessWidget {
  final LanguagePassport passport;
  final AppController app;
  const _CourseDetails(this.passport, this.app);
  @override
  Widget build(BuildContext context) {
    final p = passport.progress, now = app.repository.now();
    final active = List.generate(
      7,
      (i) => dayKey(now.subtract(Duration(days: i))),
    ).where((d) => (p.dailyXp[d] ?? 0) > 0).length;
    final badges = passport.achievements(now);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${passport.course.flag} ${passport.course.name}',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 16),
          Text(
            '${p.xp} XP · ${p.completed.length} уроков · серия ${p.streak(now)} дн.',
          ),
          Text(
            '${p.words.length} слов открыто · ${passport.mastered} освоено по повторениям',
          ),
          Text(
            'Ошибки, требующие внимания: ${p.words.values.where((w) => w.errors > 0 && w.repetitions == 0).length} слов',
          ),
          Text('Учебных дней за неделю: $active / 7'),
          const SizedBox(height: 16),
          const Text(
            'Достижения этого языка',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          Wrap(
            spacing: 8,
            children: [
              for (final b in badges)
                Chip(
                  avatar: const Icon(Icons.verified_outlined, size: 18),
                  label: Text(b),
                ),
            ],
          ),
          Text(
            p.completed.length >= passport.course.lessons
                ? 'Маршрут пройден. Повторяй слова, чтобы сохранить знания.'
                : 'Следующий рубеж: урок ${p.completed.length + 1} из ${passport.course.lessons}',
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () async {
              final router = GoRouter.of(context);
              await app.selectCourse(passport.course.id);
              if (context.mounted) {
                Navigator.pop(context);
                router.go('/map');
              }
            },
            child: const Text('Открыть маршрут'),
          ),
        ],
      ),
    );
  }
}
