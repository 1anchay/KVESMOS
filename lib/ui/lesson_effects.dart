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
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: total == 0 ? 0 : done / total),
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 240),
        builder: (_, value, _) => LinearProgressIndicator(
          value: value.clamp(0, 1),
          minHeight: 10,
          semanticsLabel: 'Готово $done из $total упражнений',
        ),
      ),
      const SizedBox(height: 10),
      Text(
        'Готово $done из $total',
        style: Theme.of(context).textTheme.labelLarge,
      ),
    ],
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
