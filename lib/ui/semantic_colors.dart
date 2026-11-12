import 'package:flutter/material.dart';

/// Shared semantic colors for ordinary surfaces AND reward/profile ceremonies.
/// Artwork retains its original palette; text always follows the active theme.
class KvColors {
  final bool dark;
  const KvColors(this.dark);
  factory KvColors.of(BuildContext context) =>
      KvColors(Theme.of(context).brightness == Brightness.dark);
  Color get canvas => dark ? const Color(0xFF101E29) : const Color(0xFFF7F8F4);
  Color get panel => dark ? const Color(0xFF1D3540) : Colors.white;
  Color get hero => dark ? const Color(0xFF142F3B) : const Color(0xFFE7F4EE);
  Color get text => dark ? const Color(0xFFF0F7F5) : const Color(0xFF142B38);
  Color get muted => dark ? const Color(0xFFB7D0D1) : const Color(0xFF48616A);
  Color get accent => dark ? const Color(0xFF82E6CD) : const Color(0xFF08736B);
  Color get stroke => dark ? const Color(0xFF3D5964) : const Color(0xFFC4D8D0);
  Color get success => dark ? const Color(0xFF8DE5CB) : const Color(0xFF176846);
  Color get error => dark ? const Color(0xFFFFC3BD) : const Color(0xFF9F2929);
  Color rarity(String? value) => switch (value) {
    'legendary' => dark ? const Color(0xFFF6CA72) : const Color(0xFF875800),
    'epic' => dark ? const Color(0xFFD6AFFF) : const Color(0xFF7142A2),
    'rare' => dark ? const Color(0xFF85DFFF) : const Color(0xFF086A85),
    _ => accent,
  };
}
