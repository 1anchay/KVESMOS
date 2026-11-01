import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/controller.dart';
import '../domain/languages.dart';
import '../domain/progress.dart';
import '../domain/reminders.dart';
import 'design.dart';

class CompanionSettings extends ConsumerStatefulWidget {
  const CompanionSettings({super.key});
  @override
  ConsumerState<CompanionSettings> createState() => _CompanionSettingsState();
}

class _CompanionSettingsState extends ConsumerState<CompanionSettings> {
  bool busy = false;
  String clock(int value) =>
      '${(value ~/ 60).toString().padLeft(2, '0')}:${(value % 60).toString().padLeft(2, '0')}';
  Future<void> save(ReminderPreferences value) async {
    setState(() => busy = true);
    try {
      await ref.read(appProvider).saveReminders(value);
    } catch (_) {
      if (mounted) {
        showMessage(
          context,
          'Не удалось сохранить напоминания. Повторите попытку.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> chooseTime(int minute, void Function(int) use) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: minute ~/ 60, minute: minute % 60),
    );
    if (picked != null && mounted) use(picked.hour * 60 + picked.minute);
  }

  @override
  Widget build(BuildContext context) {
    final app = ref.watch(appProvider), p = app.companion.preferences;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionTitle('Орби рядом'),
        const Text(
          'Добровольное напоминание о выбранном языке, не чаще одного раза в день. Если цель выполнена, Орби не отвлекает. Без сети и серверов.',
        ),
        SwitchListTile(
          key: const Key('reminders-enabled'),
          contentPadding: EdgeInsets.zero,
          title: const Text('Напоминания'),
          subtitle: const Text(
            'Для показа нужно разрешение телефона. Отказ не ограничивает обучение.',
          ),
          value: p.enabled,
          onChanged: busy
              ? null
              : (value) async {
                  if (value) {
                    setState(() => busy = true);
                    final granted = await app.companion.requestPermission();
                    if (!context.mounted) return;
                    setState(() => busy = false);
                    if (!granted) {
                      showMessage(
                        context,
                        'Уведомления не разрешены. Учиться можно как обычно.',
                      );
                      return;
                    }
                  }
                  await save(p.copyWith(enabled: value));
                },
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Время по часам телефона'),
          trailing: Text(clock(p.minute)),
          onTap: busy
              ? null
              : () => chooseTime(p.minute, (v) => save(p.copyWith(minute: v))),
        ),
        ListTile(
          key: const Key('reminder-course'),
          contentPadding: EdgeInsets.zero,
          title: const Text('Язык напоминания'),
          subtitle: Text(StudyCourse.byId(p.courseId).name),
          trailing: const Icon(Icons.expand_more),
          onTap: busy
              ? null
              : () async {
                  final id = await showModalBottomSheet<String>(
                    context: context,
                    isScrollControlled: true,
                    builder: (context) => SafeArea(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (final c in StudyCourse.all)
                              ListTile(
                                title: Text(c.name),
                                leading: Text(c.flag),
                                trailing: c.id == p.courseId
                                    ? const Icon(Icons.check)
                                    : null,
                                onTap: () => Navigator.pop(context, c.id),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                  if (id != null && mounted) {
                    await save(p.copyWith(courseId: id));
                  }
                },
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 5,
          runSpacing: 5,
          children: [
            for (var i = 1; i <= 7; i++)
              FilterChip(
                label: Text(['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'][i - 1]),
                selected: p.weekdays.contains(i),
                onSelected: busy
                    ? null
                    : (v) {
                        final days = {...p.weekdays};
                        if (v) {
                          days.add(i);
                        } else {
                          days.remove(i);
                        }
                        save(p.copyWith(weekdays: days));
                      },
              ),
          ],
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Тихие часы'),
          value: p.quiet,
          onChanged: busy ? null : (v) => save(p.copyWith(quiet: v)),
        ),
        if (p.quiet)
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton(
                onPressed: busy
                    ? null
                    : () => chooseTime(
                        p.quietStart,
                        (v) => save(p.copyWith(quietStart: v)),
                      ),
                child: Text('С ${clock(p.quietStart)}'),
              ),
              OutlinedButton(
                onPressed: busy
                    ? null
                    : () => chooseTime(
                        p.quietEnd,
                        (v) => save(p.copyWith(quietEnd: v)),
                      ),
                child: Text('До ${clock(p.quietEnd)}'),
              ),
            ],
          ),
        if (p.timeIsQuiet || p.weekdays.isEmpty)
          const Text(
            'В выбранное время напоминаний не будет: измените тихие часы или выберите дни.',
          ),
        TextButton.icon(
          onPressed: busy
              ? null
              : () => save(
                  p.pausedUntil == null
                      ? p.copyWith(
                          pausedUntil: dayKey(
                            app.repository.now().add(const Duration(days: 7)),
                          ),
                        )
                      : p.copyWith(resume: true),
                ),
          icon: const Icon(Icons.pause_circle_outline),
          label: Text(
            p.pausedUntil == null
                ? 'Пауза на 7 дней'
                : 'Пауза до ${p.pausedUntil} · возобновить',
          ),
        ),
        const Text(
          'Android может доставить напоминание позже из-за экономии батареи. Точные будильники и постоянная служба не используются.',
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          key: const Key('add-home-widget'),
          icon: const Icon(Icons.widgets_outlined),
          label: const Text('Добавить виджет'),
          onPressed: () async {
            final requested = await app.companion.pinWidget();
            if (context.mounted) {
              showMessage(
                context,
                requested
                    ? 'Подтвердите добавление в системном окне Android.'
                    : 'На Android: удерживайте главный экран → Виджеты → KVESMOS. Виджет iOS пока не доступен.',
              );
            }
          },
        ),
        TextButton(
          onPressed: () => showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Как добавить виджет'),
              content: const Text(
                'На Android нажмите и удерживайте пустое место главного экрана → Виджеты → KVESMOS · Серия дней. Перетащите виджет и меняйте размер удержанием. Он показывает язык, выбранный в приложении. На iOS виджет пока не доступен.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Понятно'),
                ),
              ],
            ),
          ),
          child: const Text('Как добавить виджет'),
        ),
      ],
    );
  }
}
