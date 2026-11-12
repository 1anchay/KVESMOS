import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbitwords/domain/course.dart';
import 'package:orbitwords/domain/intro_activity.dart';
import 'package:orbitwords/services/learning_audio.dart';
import 'package:orbitwords/ui/design.dart';
import 'package:orbitwords/ui/lesson_introduction.dart';
import 'audio_settings_test.dart' show loadPreviewFonts, capturePreview;
import 'learning_audio_test.dart' show FakeTts;

void main() {
  for (final small in [false, true]) {
    for (final dark in [false, true]) {
      for (final id in [
        'en-a1-40',
        'en-a1-41',
        'es-a1-19',
        'de-a1-19',
        'fr-a1-13',
        'zh-a1-13',
        'en-a1-61',
        'es-a1-31',
        'de-a1-31',
        'fr-a1-21',
        'zh-a1-21',
      ]) {
        testWidgets(
          'interactive intro $id ${small ? 320 : 390} ${dark ? 'dark' : 'light'}',
          (tester) async {
            tester.view.physicalSize = Size(small ? 320 : 390, 844);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            final boundary = GlobalKey();
            final lesson = Lesson.fromJson(
              jsonDecode(File('assets/courses/$id.json').readAsStringSync()),
            );
            final audio = LearningAudio(
              (_) async => null,
              (_, _) async {},
              backend: FakeTts()..installed = [],
            );
            IntroDraft? saved;
            await tester.runAsync(() async {
              await Directory('test-output/v015').create(recursive: true);
              await loadPreviewFonts();
            });
            await tester.pumpWidget(
              MaterialApp(
                theme: orbitTheme(dark ? Brightness.dark : Brightness.light),
                home: MediaQuery(
                  data: MediaQueryData(
                    textScaler: TextScaler.linear(small ? 2 : 1),
                    disableAnimations: true,
                  ),
                  child: RepaintBoundary(
                    key: boundary,
                    child: LessonIntroduction(
                      lesson: lesson,
                      audio: audio,
                      onDraft: (draft) async {
                        saved = draft;
                      },
                      onStart: () async {},
                      onClose: () {},
                    ),
                  ),
                ),
              ),
            );
            await tester.runAsync(() async {
              for (final image in tester.widgetList<Image>(
                find.byType(Image),
              )) {
                await precacheImage(image.image, boundary.currentContext!);
              }
            });
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            expect(
              find.byKey(const Key('teaching-next')).hitTestable(),
              findsOneWidget,
            );
            final first = lesson.guidedIntroduction.first;
            final option = find.byKey(
              ValueKey('intro-option-${first.options.indexOf(first.answer)}'),
            );
            if (!small) expect(option.hitTestable(), findsOneWidget);
            await tester.runAsync(
              () => capturePreview(
                boundary,
                'v015/intro-$id-${dark ? 'dark' : 'light'}-${small ? 320 : 390}',
              ),
            );
            await tester.ensureVisible(option);
            await tester.pumpAndSettle();
            await tester.tap(option);
            await tester.pumpAndSettle();
            expect(saved!.actions[first.id]['answer'], first.answer);
            await tester.tap(find.byTooltip('Справочник'));
            await tester.pumpAndSettle();
            expect(find.text('Справочник'), findsOneWidget);
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }
}
