import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbitwords/core/controller.dart';
import 'package:orbitwords/ui/course_answer_field.dart';

import 'support.dart';

void main() {
  setUpAll(setupSqlite);
  for (final (lang, region, character) in [
    ('en', 'US', 'a'),
    ('es', 'ES', 'ñ'),
    ('de', 'DE', 'ß'),
    ('fr', 'FR', 'ç'),
    ('zh', 'CN', '好'),
  ]) {
    testWidgets('$lang input uses the course locale and inserts at selection', (
      tester,
    ) async {
      final repository = memoryRepository();
      final app = AppController(repository);
      await tester.runAsync(() async {
        await app.initialize();
        await app.selectCourse('ru-$lang');
      });
      final input = TextEditingController(text: 'aXa');
      addTearDown(input.dispose);
      String? draft;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appProvider.overrideWith((_) => app)],
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: CourseAnswerField(
                  controller: input,
                  decoration: const InputDecoration(labelText: 'Ответ'),
                  accepted: const ['你好'],
                  onChanged: (value) => draft = value,
                ),
              ),
            ),
          ),
        ),
      );
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.hintLocales, [Locale(lang, region)]);
      if (lang != 'en') {
        await tester.tap(find.text('Символы и клавиатура'));
        await tester.pumpAndSettle();
        input.selection = const TextSelection(baseOffset: 1, extentOffset: 2);
        final button = find.widgetWithText(OutlinedButton, character);
        await tester.ensureVisible(button);
        await tester.tap(button);
        expect(input.text, 'a${character}a');
        expect(
          input.selection,
          TextSelection.collapsed(offset: 1 + character.length),
        );
        expect(draft, input.text);
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(repository.db.close);
    });
  }
}
