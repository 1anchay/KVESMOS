import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/controller.dart';
import 'design.dart';
import 'flight_components.dart';

/// Each choice is durable. A requested pin is never described as an install.
class CompanionOnboarding extends ConsumerStatefulWidget {
  final bool widgetStep;
  const CompanionOnboarding({super.key, this.widgetStep = false});
  @override
  ConsumerState<CompanionOnboarding> createState() =>
      _CompanionOnboardingState();
}

class _CompanionOnboardingState extends ConsumerState<CompanionOnboarding> {
  bool busy = true;
  String? decision, message;
  int minute = 1140;
  String get key =>
      'kvesmos.companion.choice.v012.${widget.widgetStep ? 'widget' : 'reminders'}';
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final app = ref.read(appProvider);
    final saved = await app.repository.setting(key);
    if (mounted) {
      setState(() {
        decision = saved;
        minute = app.companion.preferences.minute;
        busy = false;
      });
    }
  }

  Future<void> choose() async {
    if (busy || decision != null) return;
    setState(() => busy = true);
    final app = ref.read(appProvider);
    try {
      // Save before opening the OS dialog: a restart must not ask again.
      await app.repository.setSetting(key, 'requested');
      decision = 'requested';
      if (widget.widgetStep) {
        await app.companion.sync(app.goal);
        final accepted = await app.companion.pinWidget();
        message = accepted
            ? 'Запрос отправлен системе. Подтверди добавление на главном экране. Можно продолжить и без виджета.'
            : 'Автоматическое добавление недоступно. На главном экране телефона удерживай пустое место → Виджеты → KVESMOS. Учиться можно без виджета.';
      } else {
        final granted = await app.companion.requestPermission();
        await app.saveReminders(
          app.companion.preferences.copyWith(
            enabled: granted,
            minute: minute,
            courseId: app.course.id,
          ),
        );
        decision = granted ? 'enabled' : 'declined';
        await app.repository.setSetting(key, decision!);
        message = granted
            ? 'Напоминания включены. В тихие часы и после выполнения цели Орби не отвлекает.'
            : 'Разрешение не получено. Напоминания выключены; обучение доступно. Повторить запрос можно в настройках.';
      }
    } catch (_) {
      message =
          'Системная функция сейчас недоступна. Продолжай обучение; настройки останутся доступны позже.';
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> next() async {
    if (busy) return;
    setState(() => busy = true);
    final app = ref.read(appProvider);
    try {
      if (decision == null) await app.repository.setSetting(key, 'later');
      if (widget.widgetStep) {
        await app.dismissCompanionInvitation();
        final firstRun = !app.onboarded;
        if (!app.onboarded) await app.finishOnboarding();
        final route = firstRun && app.courseStart.entry != null
            ? await app.learningContinuationRoute()
            : '/';
        if (mounted) context.go(route);
      } else {
        await app.repository.setSetting(
          'kvesmos.onboarding.route.v012',
          '/companion/widget',
        );
        if (mounted) context.go('/companion/widget');
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          busy = false;
          message = 'Не удалось сохранить выбор. Попробуй ещё раз.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = ref.watch(appProvider), widgetStep = widget.widgetStep;
    final time = TimeOfDay(hour: minute ~/ 60, minute: minute % 60);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widgetStep ? 'Орби на главном экране' : 'Орби рядом каждый день',
        ),
      ),
      body: pageBody([
        const Center(child: OrbitRobot(size: 128, emotion: 'happy')),
        const SizedBox(height: 16),
        Text(
          widgetStep ? 'Твой маленький маяк' : 'Пять минут для себя',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 12),
        Text(
          widgetStep
              ? 'Виджет напомнит о серии дней и откроет продолжение урока одним касанием.'
              : 'Выбери удобное время. Я напомню о языке, если дневная цель ещё ждёт тебя.',
        ),
        const SizedBox(height: 20),
        if (widgetStep)
          FlightPanel(
            accent: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('ПРЕДПРОСМОТР ВИДЖЕТА · 2×2 / 4×2'),
                const SizedBox(height: 12),
                Text(
                  '${app.course.flag} ${app.course.name}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  '${app.progress.streak(app.repository.now())} дней подряд',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                Text('Сегодня · цель ${app.goal} XP'),
                const SizedBox(height: 10),
                const Text('Продолжить урок →'),
              ],
            ),
          )
        else ...[
          Text('${app.course.flag} ${app.course.name}'),
          OutlinedButton.icon(
            onPressed: busy || decision != null
                ? null
                : () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: time,
                    );
                    if (picked != null && mounted) {
                      setState(() => minute = picked.hour * 60 + picked.minute);
                    }
                  },
            icon: const Icon(Icons.schedule),
            label: Text(time.format(context)),
          ),
          if (app.companion.preferences.copyWith(minute: minute).timeIsQuiet)
            const Text(
              'Это время попадает в тихие часы. Выбери другое время или измени тихие часы позже в настройках.',
            ),
        ],
        const SizedBox(height: 20),
        if (message != null) Semantics(liveRegion: true, child: Text(message!)),
        if (decision == null)
          FilledButton(
            onPressed: busy ? null : choose,
            child: Text(
              widgetStep ? 'Добавить виджет' : 'Включить напоминания',
            ),
          ),
        TextButton(
          onPressed: busy ? null : next,
          child: Text(decision == null ? 'Не сейчас' : 'Продолжить'),
        ),
        const Text(
          'Это твой выбор. Ничто не ограничит уроки. Всё можно изменить в настройках.',
        ),
      ]),
    );
  }
}

class CompanionInvitation extends ConsumerWidget {
  const CompanionInvitation({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.watch(appProvider);
    if (!app.companionInvitation) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: FlightPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Орби может быть ближе',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const Text('Напоминания и виджет серии — если тебе удобно.'),
            Wrap(
              children: [
                TextButton(
                  onPressed: () => context.go('/companion/reminders'),
                  child: const Text('Посмотреть'),
                ),
                TextButton(
                  onPressed: app.dismissCompanionInvitation,
                  child: const Text('Не сейчас'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
