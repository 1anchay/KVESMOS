import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/controller.dart';
import '../data/picture_repository.dart';
import '../services/device.dart';
import '../services/learning_audio.dart';
import 'design.dart';
import 'lesson_effects.dart';
import 'picture_art.dart';

class PictureRecallPage extends ConsumerStatefulWidget {
  const PictureRecallPage({super.key});
  @override
  ConsumerState<PictureRecallPage> createState() => _PictureRecallPageState();
}

class _PictureRecallPageState extends ConsumerState<PictureRecallPage> {
  late final app = ref.read(appProvider);
  late final repository = PictureRepository(app.repository);
  final input = TextEditingController();
  final voice = VoiceService();
  Map<String, dynamic>? state;
  Map<String, PictureWord> cards = {};
  bool busy = false, error = false, showHint = false;
  int voiceGeneration = 0;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load({bool restart = false}) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = false;
    });
    try {
      final words = await repository.cards;
      final saved = await repository.open(restart: restart);
      if (!mounted) return;
      setState(() {
        cards = words;
        state = saved;
        input.text = saved['text'];
        showHint = false;
      });
    } catch (_) {
      if (mounted) setState(() => error = true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> advance() async {
    if (busy || state == null) return;
    final index = state!['index'] as int, checked = state!['checked'] as bool;
    FocusScope.of(context).unfocus();
    setState(() => busy = true);
    voiceGeneration++;
    try {
      await voice.stop();
      await app.audio.stop();
      final next = await repository.advance(index, checked, input.text);
      if (!mounted) return;
      setState(() {
        state = next;
        input.text = next['text'];
        if (checked) showHint = false;
      });
      if (!checked) {
        unawaited(
          app.audio.play(
            next['correct'] == true
                ? SoundEffect.correct
                : SoundEffect.incorrect,
          ),
        );
      }
      await app.refresh();
    } catch (_) {
      if (mounted) showMessage(context, 'Ответ не сохранён. Попробуй ещё раз.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> saveDraft(String text) async {
    if (state == null || state!['checked'] == true) return;
    setState(() {});
    try {
      await repository.draft(state!['index'], text);
    } catch (_) {
      if (mounted) showMessage(context, 'Черновик не сохранён.');
    }
  }

  Future<void> record() async {
    final generation = ++voiceGeneration;
    await app.audio.stop();
    if (!mounted || generation != voiceGeneration) return;
    final ok = await voice.listen(
      (text) {
        if (!mounted || generation != voiceGeneration || busy) return;
        input.text = text;
        unawaited(saveDraft(text));
      },
      (message) {
        if (mounted && generation == voiceGeneration) {
          showMessage(context, message);
        }
      },
      language: repository.language,
    );
    if (!ok && mounted && generation == voiceGeneration) {
      showMessage(context, 'Распознавание недоступно. Введи ответ текстом.');
    }
  }

  @override
  void dispose() {
    voiceGeneration++;
    unawaited(voice.stop());
    unawaited(app.audio.stop());
    input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final value = state, theme = Theme.of(context).textTheme;
    final ids = List<String>.from(value?['ids'] ?? []);
    final index = value?['index'] as int? ?? 0;
    final card = index < ids.length ? cards[ids[index]] : null;
    final checked = value?['checked'] == true;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Слова по картинкам'),
        leading: IconButton(
          tooltip: 'Сохранить и выйти',
          icon: const Icon(Icons.close),
          onPressed: busy ? null : () => context.go('/training'),
        ),
      ),
      body: error
          ? pageBody([
              const Text('Не удалось открыть карточки.'),
              TextButton(onPressed: load, child: const Text('Повторить')),
            ])
          : value == null
          ? const Center(child: CircularProgressIndicator())
          : pageBody([
              Text(app.course.name, style: theme.titleMedium),
              if (card == null) ...[
                Text(
                  ids.isEmpty
                      ? 'Сначала познакомься со словами в уроках'
                      : 'Карточки повторены',
                  style: theme.headlineSmall,
                ),
                Text(
                  ids.isEmpty
                      ? 'Карточки появятся после прохождения уроков со знакомыми предметами.'
                      : 'Вспомнил с первой попытки: ${value['score']} из ${ids.length}. Сроки повторения обновлены.',
                ),
                if (ids.isNotEmpty)
                  OutlinedButton(
                    onPressed: busy ? null : () => load(restart: true),
                    child: const Text('Подобрать карточки'),
                  ),
                TextButton(
                  onPressed: () => context.go('/training'),
                  child: const Text('К практике'),
                ),
              ] else ...[
                LessonProgress(done: index, total: ids.length),
                const SizedBox(height: 16),
                Text(
                  PictureArt.counts.containsKey(card.id)
                      ? 'Сколько звёзд?'
                      : 'Что на картинке?',
                  style: theme.headlineSmall,
                ),
                const SizedBox(height: 12),
                PictureArt(card.id),
                const SizedBox(height: 16),
                if (!checked) ...[
                  TextField(
                    key: const Key('picture-input'),
                    controller: input,
                    enabled: !busy,
                    textInputAction: TextInputAction.done,
                    onChanged: saveDraft,
                    onSubmitted: (_) {
                      if (input.text.trim().isNotEmpty) advance();
                    },
                    decoration: InputDecoration(
                      labelText: repository.language == 'zh'
                          ? 'Иероглифы или пиньинь с тонами'
                          : 'Ответ на изучаемом языке',
                    ),
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      TextButton.icon(
                        onPressed: busy ? null : record,
                        icon: const Icon(Icons.mic_none),
                        label: const Text('Сказать'),
                      ),
                      TextButton(
                        onPressed: () => setState(() => showHint = !showHint),
                        child: const Text('Подсказка'),
                      ),
                    ],
                  ),
                  if (showHint)
                    Text(
                      'Значение: ${card.meaning}. Вспомни слово на изучаемом языке.',
                    ),
                  const Text(
                    'Голосовой ввод заполняет поле. Ты можешь поправить распознанный текст.',
                  ),
                ] else ...[
                  Semantics(
                    liveRegion: true,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          value['correct'] == true
                              ? 'Вспомнил!'
                              : 'Сверим с примером',
                          style: theme.titleLarge,
                        ),
                        Text(
                          card.forms.join(' / '),
                          style: theme.headlineSmall,
                        ),
                        if (card.pinyin.isNotEmpty)
                          Text(card.pinyin.join(' / ')),
                        Text(card.meaning),
                      ],
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final ok = await app.audio.speak(
                        card.forms.first,
                        character: 'miko',
                      );
                      if (!ok && context.mounted) {
                        showMessage(
                          context,
                          'Голос недоступен. Слово можно прочитать на экране.',
                        );
                      }
                    },
                    icon: const Icon(Icons.volume_up_outlined),
                    label: const Text('Послушать'),
                  ),
                ],
                const SizedBox(height: 12),
                FilledButton(
                  key: const Key('picture-next'),
                  onPressed: busy || (!checked && input.text.trim().isEmpty)
                      ? null
                      : advance,
                  child: Text(checked ? 'Дальше' : 'Проверить'),
                ),
              ],
            ]),
    );
  }
}
