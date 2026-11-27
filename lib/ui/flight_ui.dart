import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/controller.dart';

@immutable
class FlightPalette extends ThemeExtension<FlightPalette> {
  const FlightPalette(
    this.background,
    this.surface,
    this.inset,
    this.text,
    this.secondary,
    this.line,
    this.control,
    this.accent,
    this.onAccent,
    this.selected,
    this.warning,
    this.warningSurface,
  );

  static const light = FlightPalette(
    Color(0xfff7f9f6),
    Color(0xffffffff),
    Color(0xffedf2f1),
    Color(0xff243748),
    Color(0xff52707c),
    Color(0xffd6dfe4),
    Color(0xff6e8290),
    Color(0xff246b5c),
    Color(0xffffffff),
    Color(0xffe0f3ed),
    Color(0xff82401c),
    Color(0xfffff0e4),
  );
  static const dark = FlightPalette(
    Color(0xff121f2e),
    Color(0xff243649),
    Color(0xff192a3c),
    Color(0xffe8eff5),
    Color(0xffa9b9c9),
    Color(0xff42566b),
    Color(0xff849cb2),
    Color(0xff9ce8cd),
    Color(0xff122c28),
    Color(0xff254840),
    Color(0xffffd3ad),
    Color(0xff46372f),
  );

  static FlightPalette of(BuildContext context) =>
      Theme.of(context).extension<FlightPalette>() ??
      (Theme.of(context).brightness == Brightness.dark ? dark : light);

  final Color background,
      surface,
      inset,
      text,
      secondary,
      line,
      control,
      accent,
      onAccent,
      selected,
      warning,
      warningSurface;

  @override
  FlightPalette copyWith() => this;

  @override
  FlightPalette lerp(covariant FlightPalette? other, double t) {
    if (other == null) return this;
    // Switch foreground/background pairs together throughout a theme transition.
    return t < .5 ? this : other;
  }

  ButtonStyle get filled => FilledButton.styleFrom(
    backgroundColor: accent,
    foregroundColor: onAccent,
    minimumSize: const Size(0, 48),
  );
  ButtonStyle get outline => OutlinedButton.styleFrom(
    foregroundColor: text,
    side: BorderSide(color: control),
    minimumSize: const Size(0, 48),
  );
  ButtonStyle get link => TextButton.styleFrom(
    foregroundColor: accent,
    minimumSize: const Size(0, 48),
  );
}

class FlightThemePicker extends ConsumerWidget {
  const FlightThemePicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.watch(appProvider);
    final colors = FlightPalette.of(context);
    return PopupMenuButton<ThemeMode>(
      tooltip: 'Оформление',
      initialValue: app.theme,
      color: colors.surface,
      icon: Icon(switch (app.theme) {
        ThemeMode.system => Icons.brightness_auto_outlined,
        ThemeMode.light => Icons.light_mode_outlined,
        ThemeMode.dark => Icons.dark_mode_outlined,
      }, color: colors.accent),
      onSelected: (mode) => app.savePreferences(newTheme: mode),
      itemBuilder: (_) => [
        for (final mode in ThemeMode.values)
          CheckedPopupMenuItem(
            key: ValueKey('flight-theme-${mode.name}'),
            value: mode,
            checked: app.theme == mode,
            child: Text(switch (mode) {
              ThemeMode.system => 'Как в системе',
              ThemeMode.light => 'Светлая тема',
              ThemeMode.dark => 'Тёмная тема',
            }, style: TextStyle(color: colors.text)),
          ),
      ],
    );
  }
}

enum FlightControlStyle { primary, tile, choice, quiet }

/// One flight control with a visible focus ring and a single semantics action.
class FlightControl extends StatefulWidget {
  const FlightControl({
    super.key,
    required this.label,
    required this.onTap,
    this.style = FlightControlStyle.choice,
    this.description,
    this.icon,
    this.selected = false,
    this.semanticLabel,
    this.semanticHint,
  });
  final String label;
  final String? description, semanticLabel, semanticHint;
  final IconData? icon;
  final VoidCallback? onTap;
  final FlightControlStyle style;
  final bool selected;
  @override
  State<FlightControl> createState() => _FlightControlState();
}

class _FlightControlState extends State<FlightControl> {
  bool pressed = false, focused = false;

  @override
  Widget build(BuildContext context) {
    final colors = FlightPalette.of(context);
    final enabled = widget.onTap != null;
    final primary = widget.style == FlightControlStyle.primary;
    final quiet = widget.style == FlightControlStyle.quiet;
    final tile = widget.style == FlightControlStyle.tile;
    final choice = widget.style == FlightControlStyle.choice;
    final fill = primary
        ? (enabled ? colors.accent : colors.inset)
        : widget.selected || pressed && enabled
        ? colors.selected
        : quiet
        ? Colors.transparent
        : colors.surface;
    final foreground = primary
        ? (enabled ? colors.onAccent : colors.secondary)
        : quiet
        ? colors.accent
        : colors.text;
    final border = primary && focused
        ? colors.onAccent
        : (focused || widget.selected || pressed && enabled)
        ? colors.accent
        : quiet || primary
        ? Colors.transparent
        : colors.control;
    final radius = BorderRadius.circular(tile ? 12 : 16);
    final reduced = MediaQuery.disableAnimationsOf(context);

    return Semantics(
      button: true,
      enabled: enabled,
      selected: choice ? widget.selected : null,
      label:
          widget.semanticLabel ??
          [widget.label, ?widget.description].join(', '),
      hint: widget.semanticHint,
      onTap: enabled ? widget.onTap : null,
      child: ExcludeSemantics(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            canRequestFocus: enabled,
            borderRadius: radius,
            onTap: widget.onTap,
            onHighlightChanged: enabled
                ? (value) => setState(() => pressed = value)
                : null,
            onFocusChange: (value) => setState(() => focused = value),
            splashFactory: reduced ? NoSplash.splashFactory : null,
            child: AnimatedContainer(
              duration: reduced
                  ? Duration.zero
                  : const Duration(milliseconds: 120),
              constraints: BoxConstraints(
                minWidth: 48,
                minHeight: primary ? 52 : 48,
              ),
              padding: EdgeInsets.symmetric(
                horizontal: tile ? 13 : 14,
                vertical: 11,
              ),
              decoration: BoxDecoration(
                color: fill,
                borderRadius: radius,
                border: Border.all(color: border, width: 2),
                boxShadow: tile && enabled && !pressed
                    ? [
                        BoxShadow(
                          color: colors.line,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : const [],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: choice
                    ? MainAxisAlignment.start
                    : MainAxisAlignment.center,
                children: [
                  if (widget.icon != null) ...[
                    Icon(widget.icon, size: 20, color: foreground),
                    const SizedBox(width: 8),
                  ],
                  Flexible(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: choice
                          ? CrossAxisAlignment.start
                          : CrossAxisAlignment.center,
                      children: [
                        Text(
                          widget.label,
                          textAlign: choice
                              ? TextAlign.start
                              : TextAlign.center,
                          style: TextStyle(
                            color: foreground,
                            fontSize: tile ? 17 : 16,
                            fontWeight: FontWeight.w700,
                            height: 1.19,
                          ),
                        ),
                        if (widget.description case final detail?)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              detail,
                              style: TextStyle(
                                color: colors.secondary,
                                fontSize: 14,
                                height: 1.25,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (choice) ...[
                    const SizedBox(width: 8),
                    Icon(
                      widget.selected
                          ? Icons.check_circle
                          : Icons.circle_outlined,
                      color: widget.selected ? colors.accent : colors.control,
                      size: 19,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
