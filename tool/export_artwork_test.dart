// Run: flutter test tool/export_artwork_test.dart
// Rasterizes our own Flutter vector mascot for native launcher icon sizes.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbitwords/ui/design.dart';

void main() {
  testWidgets('Export original Orbi artwork', (tester) async {
    tester.view.physicalSize = const Size(256, 256);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final key = GlobalKey();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: RepaintBoundary(
          key: key,
          child: const ColoredBox(
            color: space,
            child: Center(child: OrbitRobot(size: 216)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 4);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = png!.buffer.asUint8List();
      image.dispose();
      Future<void> save(String path, int size) async {
        final codec = await ui.instantiateImageCodec(
          bytes,
          targetWidth: size,
          targetHeight: size,
        );
        final frame = await codec.getNextFrame();
        final data = await frame.image.toByteData(
          format: ui.ImageByteFormat.png,
        );
        final file = File(path);
        await file.parent.create(recursive: true);
        await file.writeAsBytes(data!.buffer.asUint8List());
        frame.image.dispose();
        codec.dispose();
      }

      await save('assets/branding/orbi-icon.png', 1024);
      for (final density in {
        'mdpi': 48,
        'hdpi': 72,
        'xhdpi': 96,
        'xxhdpi': 144,
        'xxxhdpi': 192,
      }.entries) {
        await save(
          'android/app/src/main/res/mipmap-${density.key}/ic_launcher.png',
          density.value,
        );
      }
      final contents = jsonDecode(
        await File(
          'ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json',
        ).readAsString(),
      );
      for (final icon in contents['images']) {
        if (icon['filename'] == null) continue;
        final points = double.parse((icon['size'] as String).split('x').first);
        final scale = double.parse(
          (icon['scale'] as String).replaceAll('x', ''),
        );
        await save(
          'ios/Runner/Assets.xcassets/AppIcon.appiconset/${icon['filename']}',
          (points * scale).round(),
        );
      }
    });
  });
}
