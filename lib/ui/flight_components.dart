import 'package:flutter/material.dart';

/// KVESMOS flight journal: ink, paper, signal. Flat surfaces, one accent,
/// deliberate spacing; no simulated extrusion or perpetual motion.
abstract final class FlightTokens {
  static const ink = Color(0xFF142B38);
  static const paper = Color(0xFFF7F8F4);
  static const signal = Color(0xFF087E83);
  static const night = Color(0xFF101E29);
  static const gold = Color(0xFFFFCE6A);
  static const radius = 20.0;
  static const beat = Duration(milliseconds: 360);
}

class FlightPanel extends StatelessWidget {
  final Widget child;
  final bool accent;
  final EdgeInsetsGeometry padding;
  const FlightPanel({
    super.key,
    required this.child,
    this.accent = false,
    this.padding = const EdgeInsets.all(18),
  });
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: accent
            ? (dark ? const Color(0xFF173B40) : const Color(0xFFE4F3EE))
            : (dark ? const Color(0xFF192C38) : Colors.white),
        borderRadius: BorderRadius.circular(FlightTokens.radius),
        border: Border.all(
          color: dark ? const Color(0xFF2C4552) : const Color(0xFFDCE5DF),
        ),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class FlightProgress extends StatelessWidget {
  final int value, target;
  final String label;
  const FlightProgress({
    super.key,
    required this.value,
    required this.target,
    required this.label,
  });
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(end: (value / target).clamp(0, 1)),
    duration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : FlightTokens.beat,
    builder: (_, t, _) => LinearProgressIndicator(
      value: t,
      minHeight: 6,
      semanticsLabel: '$label: $value из $target',
    ),
  );
}

class FlightArrival extends StatelessWidget {
  final Widget child;
  final bool animate;
  const FlightArrival({super.key, required this.child, required this.animate});
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: animate ? 0 : 1, end: 1),
    duration: animate && !MediaQuery.disableAnimationsOf(context)
        ? const Duration(milliseconds: 650)
        : Duration.zero,
    builder: (_, t, child) => Opacity(
      opacity: .4 + .6 * t,
      child: Transform.translate(offset: Offset(0, 14 * (1 - t)), child: child),
    ),
    child: child,
  );
}
