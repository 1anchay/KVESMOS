import 'package:flutter/material.dart';
import 'character_moment.dart';
import 'galaxy_components.dart';
import 'flight_components.dart';

const space = Color(0xFF0F172A),
    cosmicBlue = Color(0xFF1D4ED8),
    turquoise = Color(0xFF22D3EE),
    coral = Color(0xFFFB7185),
    violet = Color(0xFF8B5CF6),
    starYellow = Color(0xFFFACC15),
    mintGlow = Color(0xFF34D399);
ThemeData orbitTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme =
      ColorScheme.fromSeed(
        seedColor: FlightTokens.signal,
        brightness: brightness,
      ).copyWith(
        primary: dark ? const Color(0xFF71D5CA) : FlightTokens.signal,
        secondary: violet,
        tertiary: coral,
        surface: dark ? FlightTokens.night : FlightTokens.paper,
      );
  return ThemeData(
    fontFamily: 'OrbitSans',
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      centerTitle: false,
      scrolledUnderElevation: 0,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      color: dark ? const Color(0xFF192C38) : Colors.white,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: dark ? const Color(0xFF2C4552) : const Color(0xFFDCE5DF),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? const Color(0xFF24304A) : Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.all(20),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        textStyle: const TextStyle(
          fontFamily: 'OrbitSans',
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: dark ? FlightTokens.night : Colors.white,
      indicatorColor: dark ? const Color(0xFF244950) : const Color(0xFFD9EEE8),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: scheme.primary,
      linearTrackColor: dark
          ? const Color(0xFF2A3D60)
          : const Color(0xFFDCE6FA),
      borderRadius: BorderRadius.circular(20),
    ),
    textTheme: TextTheme(
      headlineLarge: TextStyle(
        fontSize: 30,
        fontWeight: FontWeight.w800,
        letterSpacing: -1,
        color: dark ? Colors.white : space,
      ),
      headlineMedium: const TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.w800,
        letterSpacing: -.6,
      ),
      titleLarge: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
      titleMedium: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
      bodyLarge: const TextStyle(fontSize: 17, height: 1.35),
      bodyMedium: const TextStyle(fontSize: 15, height: 1.3),
    ),
  );
}

class OrbitRobot extends StatelessWidget {
  final double size;
  final String emotion;
  const OrbitRobot({super.key, this.size = 150, this.emotion = 'logo'});
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Орби — ваш космический спутник',
    image: true,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(size * .24),
      child: Image.asset(
        'assets/kvesmos/orbi_$emotion.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
        excludeFromSemantics: true,
      ),
    ),
  );
}

class CharacterPortrait extends StatelessWidget {
  final String id;
  final double size;
  const CharacterPortrait(this.id, {super.key, this.size = 100});
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(22),
    child: Image.asset(
      'assets/kvesmos/$id.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
    ),
  );
}

class SpaceBanner extends StatelessWidget {
  final String eyebrow, title, subtitle;
  final Widget? action;
  final bool animate;
  final bool showCharacter;
  const SpaceBanner({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    this.action,
    this.animate = true,
    this.showCharacter = true,
  });
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(28),
      gradient: const LinearGradient(
        colors: [Color(0xFF173D94), Color(0xFF30255E)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    clipBehavior: Clip.antiAlias,
    child: GalaxyField(
      deep: true,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: LayoutBuilder(
          builder: (context, constraints) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      eyebrow,
                      style: const TextStyle(
                        color: turquoise,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  const Icon(Icons.auto_awesome, color: starYellow, size: 20),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        height: 1.15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (showCharacter && constraints.maxWidth > 270)
                    CharacterMoment(
                      characterId: 'orbi',
                      animate: animate,
                      state: CharacterState.greeting,
                      size: constraints.maxWidth > 350 ? 150 : 104,
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Color(0xFFC5CDE0),
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
              if (action != null) ...[const SizedBox(height: 20), action!],
            ],
          ),
        ),
      ),
    ),
  );
}

class SectionTitle extends StatelessWidget {
  final String title;
  final String? subtitle;
  const SectionTitle(this.title, {super.key, this.subtitle});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 28, bottom: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    ),
  );
}

class Metric extends StatelessWidget {
  final String value, label;
  final IconData icon;
  final Color color;
  const Metric({
    super.key,
    required this.value,
    required this.label,
    required this.icon,
    this.color = violet,
  });
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 12),
          Text(value, style: Theme.of(context).textTheme.headlineMedium),
          Text(label),
        ],
      ),
    ),
  );
}

Widget pageBody(List<Widget> children) => SizedBox(
  child: Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 860),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: children,
      ),
    ),
  ),
);
void showMessage(BuildContext context, String message) => ScaffoldMessenger.of(
  context,
).showSnackBar(SnackBar(content: Text(message)));
