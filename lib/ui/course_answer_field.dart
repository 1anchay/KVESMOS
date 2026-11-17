import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/controller.dart';
import '../services/device.dart';

class CourseAnswerField extends ConsumerStatefulWidget {
  final TextEditingController controller;
  final Key? fieldKey;
  final InputDecoration decoration;
  final bool enabled, autocorrect, enableSuggestions;
  final int? minLines, maxLines, maxLength;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged, onSubmitted;
  final Iterable<String> accepted;
  const CourseAnswerField({
    super.key,
    this.fieldKey,
    required this.controller,
    required this.decoration,
    this.enabled = true,
    this.autocorrect = false,
    this.enableSuggestions = false,
    this.minLines,
    this.maxLines = 1,
    this.maxLength,
    this.textInputAction,
    this.onChanged,
    this.onSubmitted,
    this.accepted = const [],
  });

  @override
  ConsumerState<CourseAnswerField> createState() => _CourseAnswerFieldState();
}

class _CourseAnswerFieldState extends ConsumerState<CourseAnswerField> {
  final focus = FocusNode();
  bool expanded = false;

  @override
  void dispose() {
    focus.dispose();
    super.dispose();
  }

  void insert(String symbol) {
    final controller = widget.controller;
    final value = controller.value;
    final selection = value.selection;
    final start = selection.isValid ? selection.start : value.text.length;
    final end = selection.isValid ? selection.end : start;
    final text = value.text.replaceRange(start, end, symbol);
    if (widget.maxLength case final limit?) {
      if (text.characters.length > limit) return;
    }
    controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: start + symbol.length),
    );
    widget.onChanged?.call(text);
  }

  @override
  Widget build(BuildContext context) {
    final course = ref.watch(appProvider).course;
    final russian =
        widget.accepted.isNotEmpty &&
        widget.accepted.every(
          (answer) => RegExp('[А-Яа-яЁё]').hasMatch(answer),
        );
    final parts = (russian ? 'ru-RU' : course.locale).split('-');
    final chars = switch (parts.first) {
      'es' => 'ñ á é í ó ú ü ¿ ¡ Ñ Á É Í Ó Ú Ü',
      'de' => 'ä ö ü ß Ä Ö Ü ẞ',
      'fr' => 'à â æ ç é è ê ë î ï ô œ ù û ü ÿ À Â Æ Ç É È Ê Ë Î Ï Ô Œ Ù Û Ü Ÿ',
      'zh' => 'ā á ǎ à ē é ě è ī í ǐ ì ō ó ǒ ò ū ú ǔ ù ǖ ǘ ǚ ǜ ü',
      _ => '',
    };
    final hanzi = parts.first == 'zh'
        ? ({
            for (final answer in widget.accepted)
              for (final ch in answer.runes)
                if (ch >= 0x3400 && ch <= 0x9fff) String.fromCharCode(ch),
            '我',
            '你',
            '不',
            '了',
          }.toList()..sort())
        : const <String>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: widget.fieldKey,
          focusNode: focus,
          controller: widget.controller,
          decoration: widget.decoration,
          enabled: widget.enabled,
          autocorrect: widget.autocorrect,
          enableSuggestions: widget.enableSuggestions,
          maxLength: widget.maxLength,
          minLines: widget.minLines,
          maxLines: widget.maxLines,
          textInputAction: widget.textInputAction,
          hintLocales: [Locale(parts[0], parts[1])],
          onChanged: widget.onChanged,
          onSubmitted: widget.onSubmitted,
        ),
        if (widget.enabled && (chars.isNotEmpty || Platform.isAndroid))
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              icon: const Icon(Icons.keyboard_alt_outlined),
              onPressed: () => setState(() => expanded = !expanded),
              label: Text(
                expanded ? 'Скрыть помощь с вводом' : 'Символы и клавиатура',
              ),
            ),
          ),
        if (expanded && widget.enabled) ...[
          if (Platform.isAndroid)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => VoiceService.settings('keyboardSettings'),
                child: const Text('Языки клавиатуры Android'),
              ),
            ),
          if (parts.first == 'zh')
            const Text(
              'Выберите китайскую раскладку с вводом пиньиня или соберите ответ из иероглифов. Ввод пиньинем принимается в заданиях, где он предусмотрен.',
            ),
          if (chars.isNotEmpty)
            Wrap(
              spacing: 4,
              children: [
                for (final ch in [...chars.split(' '), ...hanzi])
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(40, 44),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    onPressed: () => insert(ch),
                    child: Text(ch),
                  ),
              ],
            ),
        ],
      ],
    );
  }
}
