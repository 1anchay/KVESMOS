import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

enum ActorAction {
  idle,
  blink,
  breathing,
  greeting,
  walk,
  talking,
  listening,
  thinking,
  happy,
  support,
  surprise,
  celebration,
  goodbye,
  interaction,
}

/// Independent head, torso and four jointed limbs over a shared texture atlas.
class CutoutActor extends StatefulWidget {
  final String character;
  final ActorAction action;
  final bool animate;
  final double size;
  const CutoutActor({
    super.key,
    required this.character,
    this.action = ActorAction.idle,
    this.animate = true,
    this.size = 100,
  });
  @override
  State<CutoutActor> createState() => _CutoutActorState();
}

class _CutoutActorState extends State<CutoutActor>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..addStatusListener(_status);
  ImageStream? stream;
  ImageStreamListener? listener;
  ImageInfo? texture;
  Timer? pause;
  bool resumed = true;
  bool get moving =>
      widget.animate &&
      resumed &&
      TickerMode.valuesOf(context).enabled &&
      !MediaQuery.disableAnimationsOf(context);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  void _status(AnimationStatus status) {
    if (status != AnimationStatus.completed || !moving) return;
    // Reactions are one performance. Ambient activities may resume after rest.
    if (!const {
      ActorAction.idle,
      ActorAction.blink,
      ActorAction.breathing,
      ActorAction.walk,
      ActorAction.talking,
      ActorAction.listening,
      ActorAction.thinking,
      ActorAction.interaction,
    }.contains(widget.action)) {
      return;
    }
    // Short rests also avoid a ticker on a completely unchanged pose.
    pause?.cancel();
    pause = Timer(
      Duration(milliseconds: widget.character == 'miko' ? 900 : 1400),
      () {
        if (mounted && moving) controller.forward(from: 0);
      },
    );
  }

  void _play() {
    pause?.cancel();
    if (moving) {
      controller.forward(from: 0);
    } else {
      controller.stop();
      controller.value = 0;
    }
  }

  void _load() {
    if (listener != null) stream?.removeListener(listener!);
    stream = AssetImage(
      'assets/kvesmos/rigs/${widget.character}.webp',
    ).resolve(createLocalImageConfiguration(context));
    listener = ImageStreamListener((value, _) {
      if (!mounted) return;
      setState(() {
        texture?.dispose();
        texture = value.clone();
      });
    });
    stream!.addListener(listener!);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
    _play();
  }

  @override
  void didUpdateWidget(CutoutActor old) {
    super.didUpdateWidget(old);
    if (old.character != widget.character) _load();
    if (old.action != widget.action || old.animate != widget.animate) _play();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    resumed = state == AppLifecycleState.resumed;
    _play();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    pause?.cancel();
    if (listener != null) stream?.removeListener(listener!);
    texture?.dispose();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label:
        '${widget.character == 'orbi' ? 'Орби' : 'Мико'} · ${switch (widget.action) {
          ActorAction.idle => 'рядом',
          ActorAction.blink => 'моргает',
          ActorAction.breathing => 'дышит',
          ActorAction.greeting => 'приветствует',
          ActorAction.walk => 'идёт',
          ActorAction.talking => 'говорит',
          ActorAction.listening => 'слушает',
          ActorAction.thinking => 'размышляет',
          ActorAction.happy => 'радуется',
          ActorAction.support => 'поддерживает',
          ActorAction.surprise => 'удивляется',
          ActorAction.celebration => 'празднует',
          ActorAction.goodbye => 'прощается',
          ActorAction.interaction => 'работает с пультом',
        }}',
    child: SizedBox(
      width: widget.size,
      height: widget.size * 1.25,
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: controller,
          builder: (_, _) => texture == null
              ? const SizedBox.shrink()
              : CustomPaint(
                  painter: _ActorPainter(
                    texture!.image,
                    widget.character,
                    widget.action,
                    moving ? controller.value : 0,
                  ),
                ),
        ),
      ),
    ),
  );
}

class _ActorPainter extends CustomPainter {
  final ui.Image atlas;
  final String character;
  final ActorAction action;
  final double time;
  const _ActorPainter(this.atlas, this.character, this.action, this.time);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 120, size.height / 150);
    final phase = time * math.pi * 2;
    final motion = math.sin(phase);
    final breath = math.sin(phase) * (character == 'miko' ? 1.1 : .65);
    final envelope = math.pow(math.sin(math.pi * time), 2).toDouble();
    final wave = math.sin(phase * (character == 'miko' ? 3 : 2));
    // Shoulder rotations are distinct gestures, not whole-image transforms.
    final (leftArm, rightArm) = switch (action) {
      ActorAction.greeting => (.08 * motion, envelope * (-1.8 + .25 * wave)),
      ActorAction.goodbye => (envelope * (1.7 + .2 * wave), .05 * motion),
      ActorAction.happy => (envelope * .75, envelope * -.75),
      ActorAction.celebration => (
        envelope * (1.6 + .15 * wave),
        envelope * (-1.6 + .15 * wave),
      ),
      ActorAction.support => (envelope * .55, envelope * -.2),
      ActorAction.surprise => (envelope * 1.05, envelope * -1.05),
      ActorAction.thinking => (.03 * motion, envelope * .6),
      ActorAction.listening => (envelope * .2, envelope * -.4),
      ActorAction.talking => (.1 + .16 * motion, -.1 + .12 * wave),
      ActorAction.interaction => (
        character == 'miko' ? .35 + .15 * wave : .12 * motion,
        character == 'miko' ? -.8 + .12 * motion : -.45 + .2 * wave,
      ),
      ActorAction.walk => (.2 * motion, -.2 * motion),
      _ => (.035 * motion, -.035 * motion),
    };
    final leg = action == ActorAction.walk ? motion * .3 : 0.0;
    final head =
        (action == ActorAction.blink && time > .15 && time < .22) ||
            (time > .63 && time < .7)
        ? 1
        : (action == ActorAction.talking && math.sin(phase * 4) > 0) ||
              (action == ActorAction.surprise && envelope > .3)
        ? 2
        : 0;

    void part(int cell, Rect dest, Offset joint, double rotation) {
      canvas.save();
      canvas.translate(joint.dx, joint.dy);
      canvas.rotate(rotation);
      canvas.translate(-joint.dx, -joint.dy);
      canvas.drawImageRect(
        atlas,
        Rect.fromLTWH(
          (cell % 4) * atlas.width / 4,
          (cell ~/ 4) * atlas.height / 2,
          atlas.width / 4,
          atlas.height / 2,
        ),
        dest,
        Paint()..filterQuality = FilterQuality.medium,
      );
      canvas.restore();
    }

    // Back-to-front drawing. Joint positions stay fixed while limbs rotate.
    part(6, const Rect.fromLTWH(34, 102, 28, 47), const Offset(48, 106), leg);
    part(7, const Rect.fromLTWH(60, 102, 28, 47), const Offset(72, 106), -leg);
    part(4, const Rect.fromLTWH(10, 65, 34, 60), const Offset(37, 74), leftArm);
    part(
      3,
      Rect.fromLTWH(30, 65 - breath, 60, 57 + breath),
      const Offset(60, 110),
      0,
    );
    part(
      5,
      const Rect.fromLTWH(77, 65, 34, 60),
      const Offset(83, 74),
      rightArm,
    );
    final nod = switch (action) {
      ActorAction.thinking => -.08 * envelope,
      ActorAction.listening => .045 * motion,
      ActorAction.support => .06 * envelope,
      ActorAction.surprise => -.04 * envelope,
      _ => motion * .015,
    };
    part(
      head,
      Rect.fromLTWH(13, 0 - breath, 94, 86),
      const Offset(60, 75),
      nod,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ActorPainter old) =>
      old.atlas != atlas ||
      old.time != time ||
      old.action != action ||
      old.character != character;
}
