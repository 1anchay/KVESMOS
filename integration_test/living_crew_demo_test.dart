import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:orbitwords/core/controller.dart';
import 'package:orbitwords/data/database.dart';
import 'package:orbitwords/data/repository.dart';
import 'package:orbitwords/services/learning_audio.dart';
import 'package:orbitwords/ui/app.dart';
import 'package:orbitwords/ui/character_animation_catalog.dart';
import 'package:orbitwords/ui/character_moment.dart';
import 'package:orbitwords/ui/design.dart';
import 'package:go_router/go_router.dart';

Future<void> marker(String text) =>
    Process.run('/system/bin/log', ['-t', 'KVESMOS11', text]);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Android renders real crew poses and persists profile theme', (
    tester,
  ) async {
    Future<void> capture(String file) async {
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await marker('CAPTURE:$file');
      await Future<void>.delayed(const Duration(milliseconds: 820));
    }

    for (final theme in [Brightness.light, Brightness.dark]) {
      for (final (index, id) in CharacterAnimationCatalog.cast.indexed) {
        final hue = theme.name;
        final motion = ValueNotifier(CharacterState.idle);
        final name = CharacterVoiceProfile.forId(id).name;
        if (index == 0) {
          await marker(
            'VIDEO_START:${theme == Brightness.light ? 'en' : 'zh'}',
          );
        }
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: orbitTheme(theme),
            home: Scaffold(
              appBar: AppBar(title: const Text('Команда KVESMOS')),
              body: Center(
                child: ValueListenableBuilder(
                  valueListenable: motion,
                  builder: (_, state, _) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      CharacterMoment(characterId: id, size: 220, state: state),
                      Text(switch (state) {
                        CharacterState.idle => 'Ожидание',
                        CharacterState.greeting => 'Приветствие',
                        CharacterState.surprise => 'Удивление',
                        CharacterState.thinking => 'Размышление',
                        CharacterState.celebration => 'Радость',
                        _ => 'Поддержка',
                      }),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        final portrait = find.descendant(
          of: find.byType(CharacterMoment),
          matching: find.byType(Image),
        );
        final portraitContext = tester.element(portrait);
        await precacheImage(
          tester.widget<Image>(portrait).image,
          portraitContext,
        );
        await capture('$hue-${id.replaceAll('_', '-')}-neutral');
        motion.value = id == 'pixie'
            ? CharacterState.surprise
            : CharacterState.greeting;
        await tester.pump();
        await Future<void>.delayed(const Duration(milliseconds: 600));
        await capture('$hue-${id.replaceAll('_', '-')}-gesture');
        motion.value = CharacterState.thinking;
        await capture('$hue-${id.replaceAll('_', '-')}-thinking');
        motion.value = CharacterState.celebration;
        await capture('$hue-${id.replaceAll('_', '-')}-happy');
        await tester.pumpWidget(const SizedBox.shrink());
        motion.dispose();
      }
      await marker('VIDEO_DONE:${theme == Brightness.light ? 'en' : 'zh'}');
    }

    final repository = LearningRepository(AppDatabase(NativeDatabase.memory()));
    final app = AppController(repository);
    await app.initialize();
    await app.finishOnboarding();
    await app.savePreferences(newName: 'Путешественник по созвездиям');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appProvider.overrideWith((_) => app)],
        child: const OrbitApp(),
      ),
    );
    await tester.pumpAndSettle();
    GoRouter.of(tester.element(find.byType(OrbitShell))).go('/profile');
    await tester.pumpAndSettle();
    final themeButton = find.byKey(const Key('profile-theme'));
    for (final (label, mode) in [
      ('Светлая', ThemeMode.light),
      ('Тёмная', ThemeMode.dark),
      ('Как в системе', ThemeMode.system),
    ]) {
      await tester.tap(themeButton);
      await tester.pumpAndSettle();
      await tester.tap(find.text(label).last);
      await tester.pumpAndSettle();
      for (var tries = 0; tries < 30 && app.theme != mode; tries++) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await tester.pump();
      }
      expect(app.theme, mode);
      expect(await repository.setting('theme'), mode.name);
      expect(find.textContaining(RegExp(r'^LV\s')), findsNothing);
      await capture('profile-${mode.name}');
    }
    await marker('DONE');
    await tester.pumpWidget(const SizedBox.shrink());
    await repository.db.close();
  });
}
