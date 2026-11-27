import 'package:flutter/material.dart';

class JourneyPlanet extends StatelessWidget {
  final int index;
  const JourneyPlanet(this.index, {super.key});

  @override
  Widget build(BuildContext context) => Image.asset(
    'assets/kvesmos/scenes/world_${index % 6}.webp',
    fit: BoxFit.contain,
    excludeFromSemantics: true,
  );
}
