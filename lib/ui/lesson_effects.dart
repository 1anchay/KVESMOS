import 'package:flutter/material.dart';

class QuestionEntrance extends StatelessWidget {
  final String questionId;
  final Widget child;
  const QuestionEntrance({
    super.key,
    required this.questionId,
    required this.child,
  });
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    key: ValueKey('question:$questionId'),
    tween: Tween(begin: 0, end: 1),
    duration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 220),
    builder: (_, value, child) => Opacity(
      opacity: .35 + .65 * value,
      child: Transform.translate(
        offset: Offset(0, 8 * (1 - value)),
        child: child,
      ),
    ),
    child: child,
  );
}

class LessonProgress extends StatelessWidget {
  final int done, total;
  const LessonProgress({super.key, required this.done, required this.total});
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Готово $done из $total упражнений',
    value: '$done / $total',
    child: Row(
      children: [
        for (var i = 0; i < total; i++) ...[
          if (i > 0) SizedBox(width: i == total ~/ 2 ? 10 : 4),
          Expanded(
            child: AnimatedContainer(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 240),
              height: 6,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                color: i < done
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
          ),
        ],
      ],
    ),
  );
}

class XpPop extends StatelessWidget {
  final bool enabled;
  final String eventKey;
  final Widget child;
  const XpPop({
    super.key,
    required this.enabled,
    required this.eventKey,
    required this.child,
  });
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    key: ValueKey(eventKey),
    tween: Tween(begin: .95, end: 1),
    curve: Curves.easeOutBack,
    duration: !enabled || MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 320),
    builder: (_, value, child) => Transform.scale(
      scale: value,
      alignment: Alignment.centerLeft,
      child: child,
    ),
    child: child,
  );
}
