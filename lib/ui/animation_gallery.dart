import 'package:flutter/material.dart';
import 'character_animation_catalog.dart';
import 'character_moment.dart';
import 'cutout_actor.dart';

/// QA surface. Legacy poses remain visibly identified until their rigs ship.
class AnimationGallery extends StatefulWidget {
  const AnimationGallery({super.key});
  @override
  State<AnimationGallery> createState() => _AnimationGalleryState();
}

class _AnimationGalleryState extends State<AnimationGallery> {
  String character = 'orbi';
  ActorAction action = ActorAction.idle;
  bool animate = true;
  @override
  Widget build(BuildContext context) {
    final rigged = character == 'orbi' || character == 'miko';
    return Scaffold(
      appBar: AppBar(title: const Text('Animation Gallery · QA')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          DropdownButtonFormField<String>(
            initialValue: character,
            decoration: const InputDecoration(labelText: 'Персонаж'),
            items: [
              for (final id in ['orbi', ...CharacterAnimationCatalog.cast])
                DropdownMenuItem(value: id, child: Text(id)),
            ],
            onChanged: (value) => setState(() => character = value!),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<ActorAction>(
            initialValue: action,
            decoration: const InputDecoration(labelText: 'Действие'),
            items: [
              for (final item in ActorAction.values)
                DropdownMenuItem(value: item, child: Text(item.name)),
            ],
            onChanged: (value) => setState(() => action = value!),
          ),
          SwitchListTile(
            title: const Text('Анимация'),
            value: animate,
            onChanged: (value) => setState(() => animate = value),
          ),
          Text(
            rigged
                ? 'Прототип суставной анимации · художественная приёмка открыта'
                : 'Прежние позы · суставной риг ещё не подготовлен',
          ),
          const SizedBox(height: 24),
          Center(
            child: rigged
                ? CutoutActor(
                    key: ValueKey((character, action)),
                    character: character,
                    action: action,
                    animate: animate,
                    size: 240,
                  )
                : CharacterMoment(
                    characterId: character,
                    size: 220,
                    animate: animate,
                    state: switch (action) {
                      ActorAction.talking => CharacterState.talking,
                      ActorAction.happy => CharacterState.correct,
                      ActorAction.thinking => CharacterState.thinking,
                      ActorAction.support => CharacterState.support,
                      ActorAction.surprise => CharacterState.surprise,
                      ActorAction.celebration => CharacterState.celebration,
                      _ => CharacterState.idle,
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
