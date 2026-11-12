import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Original KVESMOS vector illustrations. Their silhouettes and details are
/// authored here and shared by all five courses.
class PictureArt extends StatelessWidget {
  final String id;
  const PictureArt(this.id, {super.key});

  static const counts = {
    'one': 1,
    'two': 2,
    'three': 3,
    'four': 4,
    'five': 5,
    'ten': 10,
  };
  static const descriptions = {
    'book': 'Переплёт и раскрытые страницы',
    'table': 'Горизонтальная поверхность на ножках',
    'house': 'Небольшое здание с крышей и трубой',
    'bag': 'Предмет с ручками, в котором носят вещи',
    'bicycle': 'Два колеса, рама и педали',
    'car': 'Легковое транспортное средство',
    'phone': 'Карманный экран с кнопками звонка',
    'apple': 'Круглый плод с листиком на черешке',
    'water': 'Прозрачная голубая жидкость в стакане',
    'tea': 'Янтарный напиток с пакетиком',
    'coffee': 'Тёмный напиток и обжаренные зёрна',
    'train': 'Локомотив на рельсах',
    'bus': 'Длинный дорожный транспорт с пассажирскими окнами',
    'ticket': 'Отрывной прямоугольный талон',
    'key': 'Металлический предмет с зубцами для замка',
    'window': 'Рама со стёклами и подоконником',
    'shirt': 'Одежда с рукавами, воротником и пуговицами',
    'room': 'Помещение в разрезе, внутри кровать и лампа',
    'door': 'Высокая створка с ручкой в проёме',
    'chair': 'Сиденье на ножках со спинкой',
    'park': 'Дорожка среди деревьев и скамейка',
    'hotel': 'Многоэтажное здание для приезжих, значок кровати у входа',
    'clock': 'Циферблат и две стрелки',
    'rain': 'Облако, из которого падают капли',
  };

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label:
        descriptions[id] ?? List.filled(counts[id] ?? 1, 'звезда').join(', '),
    child: AspectRatio(
      aspectRatio: 1.65,
      child: CustomPaint(
        painter: _PicturePainter(id, Theme.of(context).colorScheme),
      ),
    ),
  );
}

class _PicturePainter extends CustomPainter {
  final String id;
  final ColorScheme colors;
  _PicturePainter(this.id, this.colors);

  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(size.width / 160, size.height / 100);
    canvas.save();
    canvas.translate(
      (size.width - scale * 160) / 2,
      (size.height - scale * 100) / 2,
    );
    canvas.scale(scale);
    const ink = Color(0xff172b51),
        blue = Color(0xff4596d2),
        mint = Color(0xff42b7a2),
        gold = Color(0xfff4bc62),
        coral = Color(0xffed7c77),
        cream = Color(0xffffeac4),
        purple = Color(0xff9273ca),
        glass = Color(0xffbfe8fb),
        white = Color(0xfff8fbff);
    Paint fill(Color color) => Paint()..color = color;
    void line(
      double x,
      double y,
      double u,
      double v, [
      Color color = ink,
      double width = 3,
    ]) => canvas.drawLine(
      Offset(x, y),
      Offset(u, v),
      fill(color)
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round,
    );
    void rect(
      double x,
      double y,
      double w,
      double h,
      Color color, [
      double radius = 4,
    ]) => canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, w, h),
        Radius.circular(radius),
      ),
      fill(color),
    );
    void circle(double x, double y, double r, Color color) =>
        canvas.drawCircle(Offset(x, y), r, fill(color));
    void ellipse(double x, double y, double w, double h, Color color) =>
        canvas.drawOval(Rect.fromLTWH(x, y, w, h), fill(color));
    void poly(List<Offset> points, Color color) {
      final path = Path()..addPolygon(points, true);
      canvas.drawPath(path, fill(color));
    }

    void star(double x, double y, double radius) {
      poly(
        List.generate(10, (i) {
          final a = i * math.pi / 5 - math.pi / 2;
          final r = i.isEven ? radius : radius * .45;
          return Offset(x + math.cos(a) * r, y + math.sin(a) * r);
        }),
        gold,
      );
    }

    void cup(Color liquid, bool tag) {
      ellipse(44, 77, 74, 11, glass);
      circle(105, 55, 13, cream);
      circle(105, 55, 8, colors.primaryContainer);
      rect(51, 41, 50, 37, cream, 10);
      ellipse(51, 34, 50, 15, ink);
      ellipse(55, 37, 42, 9, liquid);
      if (tag) {
        line(81, 43, 85, 64, white, 1.5);
        rect(80, 62, 12, 10, mint, 2);
      }
    }

    void windows(double x, double y, int count) {
      for (var i = 0; i < count; i++) {
        rect(x + i * 14, y, 10, 12, glass, 1);
      }
    }

    void tree(double x, double y) {
      line(x, y, x, y + 24, ink, 4);
      circle(x, y, 13, mint);
      circle(x - 7, y + 3, 8, mint);
    }

    rect(0, 0, 160, 100, colors.primaryContainer, 12);
    circle(19, 19, 2, colors.primary);
    circle(141, 22, 1.8, colors.primary);
    final count = PictureArt.counts[id];
    if (count != null) {
      final columns = math.min(count, 5);
      for (var i = 0; i < count; i++) {
        star(
          80 + ((i % columns) - (columns - 1) / 2) * 22,
          count <= 5 ? 50 : 37 + (i ~/ 5) * 26,
          9,
        );
      }
    } else {
      ellipse(23, 83, 114, 10, colors.primary.withValues(alpha: .17));
      switch (id) {
        case 'book':
          rect(35, 25, 90, 54, purple, 6);
          poly(const [
            Offset(39, 21),
            Offset(65, 20),
            Offset(80, 26),
            Offset(80, 73),
            Offset(63, 67),
            Offset(39, 68),
          ], cream);
          poly(const [
            Offset(80, 26),
            Offset(96, 20),
            Offset(121, 21),
            Offset(121, 68),
            Offset(96, 67),
            Offset(80, 73),
          ], white);
          for (final y in [34.0, 43.0, 52.0]) {
            line(47, y, 68, y, blue, 2);
            line(91, y, 112, y, blue, 2);
          }
        case 'table':
          rect(43, 48, 7, 36, ink);
          rect(110, 48, 7, 36, ink);
          rect(50, 50, 60, 10, coral);
          rect(34, 40, 92, 12, gold);
        case 'house':
          rect(47, 43, 66, 42, cream);
          rect(96, 22, 10, 22, coral, 1);
          poly(const [Offset(36, 47), Offset(80, 15), Offset(124, 47)], purple);
          rect(76, 61, 18, 24, blue);
          rect(53, 54, 16, 16, glass, 2);
          line(61, 55, 61, 69);
        case 'bag':
          canvas.drawArc(
            const Rect.fromLTWH(62, 19, 36, 42),
            math.pi,
            math.pi,
            false,
            fill(ink)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 5,
          );
          rect(48, 39, 64, 45, coral, 9);
          rect(60, 51, 40, 20, gold, 4);
          circle(80, 59, 3, ink);
        case 'bicycle':
          for (final x in [41.0, 116.0]) {
            circle(x, 67, 19, ink);
            circle(x, 67, 15, glass);
            circle(x, 67, 3, ink);
          }
          line(41, 67, 65, 39, mint, 4);
          line(65, 39, 80, 67, mint, 4);
          line(80, 67, 41, 67, mint, 4);
          line(65, 39, 105, 42, mint, 4);
          line(80, 67, 105, 42, mint, 4);
          line(116, 67, 101, 30, ink, 4);
          line(101, 30, 112, 27);
          line(57, 35, 70, 35);
          circle(80, 67, 6, gold);
        case 'car':
          rect(30, 50, 100, 25, coral, 10);
          poly(const [
            Offset(47, 51),
            Offset(61, 33),
            Offset(99, 33),
            Offset(116, 51),
          ], blue);
          rect(65, 37, 34, 13, glass, 2);
          circle(51, 73, 11, ink);
          circle(112, 73, 11, ink);
          circle(51, 73, 4, glass);
          circle(112, 73, 4, glass);
        case 'phone':
          rect(57, 14, 47, 71, ink, 9);
          rect(62, 22, 37, 52, glass, 3);
          circle(81, 79, 3, white);
          for (final y in [30.0, 43.0, 56.0]) {
            rect(68, y, 8, 8, mint, 2);
            rect(82, y, 8, 8, blue, 2);
          }
        case 'apple':
          circle(66, 57, 23, coral);
          circle(92, 57, 23, coral);
          ellipse(53, 48, 55, 36, coral);
          line(79, 38, 83, 24, ink, 4);
          ellipse(84, 22, 22, 9, mint);
          ellipse(56, 45, 8, 15, cream);
        case 'water':
          poly(const [
            Offset(57, 32),
            Offset(103, 32),
            Offset(97, 82),
            Offset(63, 82),
          ], glass);
          poly(const [
            Offset(61, 49),
            Offset(99, 49),
            Offset(95, 78),
            Offset(65, 78),
          ], blue);
          ellipse(57, 28, 46, 8, white);
          line(64, 38, 68, 70, white, 3);
          circle(82, 20, 5, blue);
        case 'tea':
          cup(gold, true);
          ellipse(27, 54, 18, 7, mint);
          ellipse(29, 63, 16, 7, mint);
        case 'coffee':
          cup(const Color(0xff654331), false);
          for (final p in [const Offset(33, 65), const Offset(43, 74)]) {
            ellipse(p.dx, p.dy, 14, 8, const Color(0xff654331));
            line(p.dx + 4, p.dy + 4, p.dx + 10, p.dy + 4, cream, 1);
          }
        case 'train':
          line(26, 84, 137, 84, ink, 4);
          rect(33, 53, 94, 21, blue);
          rect(71, 27, 49, 42, purple, 7);
          rect(82, 34, 26, 16, glass);
          rect(41, 36, 11, 20, ink, 2);
          rect(31, 63, 15, 11, gold);
          for (final x in [52.0, 80.0, 109.0]) {
            circle(x, 75, 9, ink);
            circle(x, 75, 4, glass);
          }
        case 'bus':
          rect(26, 32, 108, 43, gold, 9);
          windows(35, 40, 6);
          rect(110, 55, 18, 18, coral, 2);
          circle(45, 75, 10, ink);
          circle(113, 75, 10, ink);
          circle(45, 75, 4, cream);
          circle(113, 75, 4, cream);
        case 'ticket':
          rect(32, 28, 96, 46, gold, 5);
          circle(32, 51, 7, colors.primaryContainer);
          circle(128, 51, 7, colors.primaryContainer);
          star(58, 51, 11);
          line(76, 39, 111, 39, ink, 2);
          line(76, 47, 111, 47, ink, 2);
          line(76, 55, 103, 55, ink, 2);
          for (final y in [34.0, 43.0, 52.0, 61.0]) {
            circle(70, y, 1.3, ink);
          }
        case 'key':
          circle(51, 49, 20, gold);
          circle(51, 49, 8, colors.primaryContainer);
          rect(64, 44, 60, 11, gold, 3);
          rect(103, 51, 8, 14, gold, 2);
          rect(117, 51, 7, 11, gold, 2);
        case 'window':
          rect(47, 18, 66, 65, ink, 4);
          rect(53, 24, 54, 53, glass, 1);
          line(80, 25, 80, 76, ink, 4);
          line(54, 51, 106, 51, ink, 4);
          line(59, 43, 71, 31, white, 2);
          rect(40, 79, 80, 7, purple, 2);
        case 'shirt':
          poly(const [
            Offset(63, 22),
            Offset(39, 32),
            Offset(27, 57),
            Offset(46, 66),
            Offset(54, 53),
            Offset(54, 85),
            Offset(106, 85),
            Offset(106, 53),
            Offset(115, 66),
            Offset(134, 56),
            Offset(122, 31),
            Offset(97, 22),
          ], blue);
          poly(const [
            Offset(63, 22),
            Offset(80, 36),
            Offset(97, 22),
            Offset(90, 42),
            Offset(80, 36),
            Offset(70, 42),
          ], cream);
          line(80, 38, 80, 84, ink, 2);
          for (final y in [48.0, 59.0, 70.0]) {
            circle(84, y, 2, white);
          }
        case 'room':
          rect(36, 23, 88, 61, cream, 5);
          poly(const [
            Offset(36, 69),
            Offset(124, 69),
            Offset(124, 84),
            Offset(36, 84),
          ], purple);
          rect(48, 56, 54, 17, blue);
          rect(49, 49, 20, 13, white);
          rect(48, 48, 5, 32, ink);
          rect(98, 66, 5, 14, ink);
          line(112, 44, 112, 67, ink);
          poly(const [
            Offset(102, 47),
            Offset(107, 36),
            Offset(117, 36),
            Offset(122, 47),
          ], gold);
        case 'door':
          rect(54, 15, 52, 72, ink, 4);
          rect(61, 20, 38, 65, coral, 2);
          rect(66, 25, 28, 21, gold, 2);
          circle(91, 58, 3, ink);
        case 'chair':
          rect(54, 22, 12, 42, ink);
          rect(54, 25, 45, 23, mint);
          rect(54, 56, 58, 11, gold);
          line(60, 65, 55, 85, ink, 5);
          line(106, 65, 110, 85, ink, 5);
          line(95, 47, 95, 58, ink, 4);
        case 'park':
          ellipse(24, 62, 113, 24, mint);
          tree(49, 45);
          tree(117, 39);
          poly(const [
            Offset(66, 86),
            Offset(79, 56),
            Offset(89, 56),
            Offset(101, 86),
          ], cream);
          rect(87, 54, 32, 6, gold);
          rect(87, 62, 32, 6, gold);
          line(90, 67, 90, 74);
          line(116, 67, 116, 74);
        case 'hotel':
          rect(44, 19, 73, 65, purple, 4);
          windows(51, 28, 4);
          windows(51, 45, 4);
          rect(70, 62, 22, 22, cream);
          rect(54, 13, 52, 14, ink);
          line(67, 18, 67, 24, white, 2);
          line(67, 22, 91, 22, white, 3);
          circle(72, 19, 2, white);
        case 'clock':
          circle(80, 51, 33, purple);
          circle(80, 51, 27, cream);
          for (var i = 0; i < 12; i++) {
            final a = i * math.pi / 6;
            circle(80 + math.cos(a) * 23, 51 + math.sin(a) * 23, 1.5, ink);
          }
          line(80, 51, 70, 42, ink);
          line(80, 51, 88, 34, ink);
          circle(80, 51, 3, coral);
        case 'rain':
          circle(62, 41, 17, glass);
          circle(83, 31, 23, glass);
          circle(105, 42, 16, glass);
          rect(45, 40, 76, 17, glass, 7);
          for (final p in [
            const Offset(54, 64),
            const Offset(72, 71),
            const Offset(91, 64),
            const Offset(110, 70),
          ]) {
            line(p.dx, p.dy, p.dx - 5, p.dy + 11, blue, 4);
          }
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PicturePainter oldDelegate) =>
      oldDelegate.id != id || oldDelegate.colors != colors;
}
