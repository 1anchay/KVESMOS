import 'dart:math';

// Fixed draw for isolated QA fixtures only. Production still uses Random.secure.
class RareFrameRandom implements Random {
  @override
  double nextDouble() => .8;
  @override
  int nextInt(int max) => 1 % max;
  @override
  bool nextBool() => true;
}
