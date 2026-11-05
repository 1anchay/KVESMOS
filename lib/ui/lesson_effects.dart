import 'package:flutter/material.dart';

class QuestionEntrance extends StatelessWidget {
  final String questionId;
  final bool enabled;
  final Widget child;
  const QuestionEntrance({
    super.key,
    required this.questionId,
    this.enabled = true,
    required this.child,
  });
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    key: ValueKey('question:$questionId'),
    tween: Tween(begin: 0, end: 1),
    duration: !enabled || MediaQuery.disableAnimationsOf(context)
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
    child: TweenAnimationBuilder<double>(
      tween: Tween(end: total == 0 ? 0 : (done / total).clamp(0, 1)),
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) => ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: LinearProgressIndicator(
          value: value,
          minHeight: 14,
          color: Theme.of(context).colorScheme.primary,
          backgroundColor: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
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
