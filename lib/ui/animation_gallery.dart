import 'package:flutter/material.dart';
import 'character_animation_catalog.dart';
import 'character_moment.dart';

/// Preview the same character poses used during lessons and reward reveals.
class AnimationGallery extends StatefulWidget {
  const AnimationGallery({super.key});
  @override
  State<AnimationGallery> createState() => _AnimationGalleryState();
}

class _AnimationGalleryState extends State<AnimationGallery> {
  String character = 'orbi';
  CharacterState action = CharacterState.idle;
  bool animate = true;
  @override
  Widget build(BuildContext context) {
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
          DropdownButtonFormField<CharacterState>(
            initialValue: action,
            decoration: const InputDecoration(labelText: 'Действие'),
            items: [
              for (final item in CharacterState.values)
                DropdownMenuItem(value: item, child: Text(item.name)),
            ],
            onChanged: (value) => setState(() => action = value!),
          ),
          SwitchListTile(
            title: const Text('Анимация'),
            value: animate,
            onChanged: (value) => setState(() => animate = value),
          ),
          const SizedBox(height: 24),
          Center(
            child: CharacterMoment(
              characterId: character,
              size: 220,
              animate: animate,
              state: action,
            ),
          ),
        ],
      ),
    );
  }
}
