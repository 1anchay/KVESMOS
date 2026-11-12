import 'semantic_colors.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/controller.dart';
import '../domain/rewards.dart';
import 'collection_components.dart';

class ProfileLook extends StatelessWidget {
  final AppController app;
  final Cosmetic? preview;
  final bool showCustomizeButton;
  const ProfileLook(
    this.app, {
    super.key,
    this.preview,
    this.showCustomizeButton = true,
  });
  @override
  Widget build(BuildContext context) {
    final colors = KvColors.of(context);
    final gear = {...app.inventory.equipped};
    if (preview != null) gear[preview!.slot] = preview!.id;
    Cosmetic? item(String slot) =>
        app.rewards.catalog.items.where((i) => i.id == gear[slot]).firstOrNull;
    final background = item('background'),
        frame = item('frame'),
        avatar = item('avatar');
    final big = MediaQuery.textScalerOf(context).scale(16) > 24;
    final portrait = SizedBox(
      width: 132,
      height: 146,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 112,
            height: 112,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.text.withValues(alpha: .08),
              border: Border.all(color: colors.accent.withValues(alpha: .5)),
            ),
          ),
          ClipOval(
            child: CollectionArt(
              avatar?.asset ?? 'assets/kvesmos/orbi_logo.png',
              label: avatar?.name ?? 'Орби',
              size: frame == null ? 116 : 89,
            ),
          ),
          if (frame != null)
            IgnorePointer(
              child: ClipPath(
                clipper: const _FrameRing(),
                child: CollectionArt(frame.asset, label: frame.name, size: 132),
              ),
            ),
          Positioned(
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
              decoration: BoxDecoration(
                color: colors.accent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'LV ${app.globalProgress.level.toString().padLeft(2, '0')}',
                style: TextStyle(
                  color: colors.dark ? const Color(0xFF142F3B) : Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
    final identity = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ИССЛЕДОВАТЕЛЬ',
          style: TextStyle(
            color: colors.accent,
            fontSize: 10,
            letterSpacing: 1.4,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          app.name,
          style: TextStyle(
            color: colors.text,
            fontSize: big ? 25 : 21,
            fontWeight: FontWeight.w800,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          '${app.globalProgress.xp} XP всех языков · уровень ${app.globalProgress.level}',
          style: TextStyle(color: colors.muted, fontSize: 12),
        ),
        const SizedBox(height: 7),
        LinearProgressIndicator(
          value: (app.globalProgress.xp % 250) / 250,
          minHeight: 5,
          color: colors.accent,
          backgroundColor: colors.stroke,
        ),
        const SizedBox(height: 5),
        Text(
          'Ещё ${250 - app.globalProgress.xp % 250} XP до уровня ${app.globalProgress.level + 1}',
          style: TextStyle(color: colors.muted, fontSize: 11),
        ),
      ],
    );
    return Semantics(
      label: preview == null
          ? 'Оформление профиля ${app.name}'
          : 'Примерка: ${preview!.name}',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Container(
          decoration: BoxDecoration(
            color: colors.hero,
            image: background == null
                ? null
                : DecorationImage(
                    image: ResizeImage(
                      AssetImage(background.asset),
                      width: 900,
                    ),
                    fit: BoxFit.cover,
                    onError: (_, _) {},
                    colorFilter: ColorFilter.mode(
                      (colors.dark ? Colors.black : Colors.white).withValues(
                        alpha: .84,
                      ),
                      colors.dark ? BlendMode.darken : BlendMode.lighten,
                    ),
                  ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: LayoutBuilder(
              builder: (context, constraints) => Column(
                children: [
                  if (big || constraints.maxWidth < 320) ...[
                    portrait,
                    const SizedBox(height: 16),
                    identity,
                  ] else
                    Row(
                      children: [
                        portrait,
                        const SizedBox(width: 16),
                        Expanded(child: identity),
                      ],
                    ),
                  if (item('accessory') != null || item('emote') != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          for (final slot in ['accessory', 'emote'])
                            if (item(slot) != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: colors.text.withValues(alpha: .09),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CollectionArt(
                                      item(slot)!.asset,
                                      label: item(slot)!.name,
                                      size: 35,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      slot == 'accessory'
                                          ? 'Эмблема'
                                          : 'Эмоция',
                                      style: TextStyle(
                                        color: colors.text,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                        ],
                      ),
                    ),
                  if (showCustomizeButton) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: colors.text,
                          side: BorderSide(
                            color: colors.text.withValues(alpha: .3),
                          ),
                          minimumSize: const Size(48, 44),
                        ),
                        onPressed: () => context.go('/inventory'),
                        icon: Icon(Icons.tune_rounded, size: 18),
                        label: Text('Настроить профиль'),
                      ),
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

/// Approved frame art includes a painted centre. A display-only ring mask lets
/// the real equipped avatar remain visible; source PNGs are never modified.
class _FrameRing extends CustomClipper<Path> {
  const _FrameRing();
  @override
  Path getClip(Size size) => Path()
    ..fillType = PathFillType.evenOdd
    ..addOval(Offset.zero & size)
    ..addOval(
      Rect.fromCircle(
        center: size.center(Offset.zero),
        radius: size.width * .29,
      ),
    );
  @override
  bool shouldReclip(_FrameRing old) => false;
}
