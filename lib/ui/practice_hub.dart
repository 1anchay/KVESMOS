import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/controller.dart';
import '../data/practice_repository.dart';
import 'design.dart';
import 'flight_components.dart';
import 'character_moment.dart';

const practiceLabels = {
  PracticeMode.words: (
    'Слова',
    'Вспоминай значения знакомых слов и фраз.',
    Icons.style_outlined,
  ),
  PracticeMode.listen: (
    'Аудирование',
    'Поймай сигнал на слух. При необходимости открой текст.',
    Icons.headphones_outlined,
  ),
  PracticeMode.speak: (
    'Говорение',
    'Произнеси фразу или введи ответ вручную.',
    Icons.mic_none,
  ),
  PracticeMode.mistakes: (
    'Ошибки',
    'Разбери материал, который пока вызывает трудности.',
    Icons.build_outlined,
  ),
  PracticeMode.dialogue: (
    'Диалоги',
    'Восстанови реплики из пройденных разговоров.',
    Icons.forum_outlined,
  ),
  PracticeMode.warmup: (
    'Разминка',
    'Три слова, которым пора вернуться по расписанию.',
    Icons.bolt_outlined,
  ),
};

class PracticeHub extends ConsumerWidget {
  const PracticeHub({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.watch(appProvider);
    final theme = Theme.of(context).textTheme;
    return pageBody([
      const CharacterMoment(characterId: 'miko', size: 80, animate: false),
      Text('Тренировочная орбита', style: theme.headlineMedium),
      Text('${app.course.name} · выбери, что хочется закрепить'),
      const SizedBox(height: 12),
      Text(
        app.progress.words.isEmpty
            ? 'После первого занятия здесь появится знакомый материал.'
            : 'Знакомых слов и фраз: ${app.progress.words.length}. Сначала возвращаем те, которым нужно внимание.',
      ),
      for (final entry in practiceLabels.entries) ...[
        const SizedBox(height: 12),
        FlightPanel(
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(entry.value.$3),
            title: Text(entry.value.$1),
            subtitle: Text(entry.value.$2),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go('/practice/${entry.key.name}'),
          ),
        ),
      ],
      const SizedBox(height: 16),
      OutlinedButton.icon(
        onPressed: () => context.go('/words'),
        icon: const Icon(Icons.menu_book_outlined),
        label: const Text('Мой словарь и сроки повторения'),
      ),
    ]);
  }
}
