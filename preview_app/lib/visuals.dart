// Navin Journal · Android design-preview visuals.
// Matches the approved Stage 3 A+C / Midnight Archive semantic tokens.
// Original programmatic artwork; no user photographs or external downloads.
import 'package:flutter/material.dart';

class JournalColors {
  final bool dark;
  const JournalColors(this.dark);

  Color get canvas => dark ? const Color(0xFF15191C) : const Color(0xFFF8F5EE);
  Color get paper => dark ? const Color(0xFF1D2226) : const Color(0xFFFFFCF7);
  Color get subtle => dark ? const Color(0xFF272D31) : const Color(0xFFEFE8DE);
  Color get ink => dark ? const Color(0xFFF1EDE4) : const Color(0xFF282923);
  Color get secondary => dark ? const Color(0xFFB9C0B9) : const Color(0xFF56594F);
  Color get action => dark ? const Color(0xFFAEBF9B) : const Color(0xFF475A43);
  Color get onAction => dark ? const Color(0xFF15191C) : const Color(0xFFF8F5EE);
  Color get clay => dark ? const Color(0xFFD9A289) : const Color(0xFFA45E42);
  Color get stroke => dark ? const Color(0xFF3B4142) : const Color(0xFFDAD6CB);
  Color get success => dark ? const Color(0xFFA7D9B0) : const Color(0xFF3F6848);
}

TextStyle editorial(JournalColors c, double size, {FontWeight weight = FontWeight.w400}) =>
    TextStyle(
      fontFamily: 'serif',
      fontSize: size,
      height: 1.18,
      letterSpacing: -0.5,
      fontWeight: weight,
      color: c.ink,
    );

class FoldedPageMark extends StatelessWidget {
  final double size;
  const FoldedPageMark({super.key, this.size = 42});

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Folded Page journal emblem',
        image: true,
        child: CustomPaint(size: Size.square(size), painter: _FoldedPagePainter()),
      );
}

class _FoldedPagePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 128, size.height / 128);
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(0, 0, 128, 128), const Radius.circular(31)),
      Paint()..color = const Color(0xFF475A43),
    );
    final left = Path()
      ..moveTo(25, 37)
      ..cubicTo(39, 30, 51, 32, 63, 39)
      ..lineTo(63, 94)
      ..cubicTo(51, 87, 38, 87, 25, 93)
      ..close();
    canvas.drawPath(left, Paint()..color = const Color(0xFFFFFCF7));
    final right = Path()
      ..moveTo(65, 39)
      ..cubicTo(77, 32, 89, 30, 103, 37)
      ..lineTo(103, 93)
      ..cubicTo(90, 87, 77, 87, 65, 94)
      ..close();
    canvas.drawPath(right, Paint()..color = const Color(0xFFEFE8DE));
    canvas.drawLine(const Offset(64, 39), const Offset(64, 96),
        Paint()..color = const Color(0xFFD6CFBD)..strokeWidth = 2.5..strokeCap = StrokeCap.round);
    final lines = Paint()
      ..color = const Color(0xFFA8AA97)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (final y in [48.0, 58.0]) {
      canvas.drawPath(
        Path()..moveTo(36, y)..cubicTo(43, y - 2, 50, y - 1, 55, y + 2), lines);
    }
    for (final y in [50.0, 60.0]) {
      canvas.drawPath(
        Path()..moveTo(74, y)..cubicTo(80, y - 3, 87, y - 4, 93, y - 2), lines);
    }
    final bookmark = Path()
      ..moveTo(83, 30)..lineTo(95, 30)..lineTo(95, 49)
      ..lineTo(89, 45)..lineTo(83, 49)..close();
    canvas.drawPath(bookmark, Paint()..color = const Color(0xFFC58B6D));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// A quiet drawn landscape, consistent with the Stage 3 CSS scenic cards.
class ScenicArt extends StatelessWidget {
  final int variation;
  final double height;
  final BorderRadiusGeometry radius;
  const ScenicArt({
    super.key,
    required this.variation,
    this.height = 152,
    this.radius = const BorderRadius.all(Radius.circular(16)),
  });

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: radius,
    child: SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _ScenicPainter(variation),
        child: const SizedBox.expand(),
      ),
    ),
  );
}

class _ScenicPainter extends CustomPainter {
  final int variation;
  _ScenicPainter(this.variation);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final colors = switch (variation % 3) {
      1 => [const Color(0xFFDBC2BA), const Color(0xFFB7837B), const Color(0xFF657B6A)],
      2 => [const Color(0xFF263747), const Color(0xFF526471), const Color(0xFF263842)],
      _ => [const Color(0xFFE7CCAB), const Color(0xFFDC9F79), const Color(0xFF627B64)],
    };
    canvas.drawRect(rect, Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        stops: const [0, 0.53, 1],
        colors: colors,
      ).createShader(rect));
    final circle = Offset(size.width * .72, size.height * .29);
    canvas.drawCircle(circle, size.height * .11,
        Paint()..color = variation % 3 == 2 ? const Color(0xFFE3DFCD) : const Color(0xFFFBE2B5));
    final rear = Path()
      ..moveTo(0, size.height * .75)
      ..quadraticBezierTo(size.width * .2, size.height * .5, size.width * .51, size.height * .73)
      ..quadraticBezierTo(size.width * .75, size.height * .88, size.width, size.height * .6)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(rear, Paint()..color = variation % 3 == 2
        ? const Color(0xFF344955) : const Color(0xFF718776));
    final front = Path()
      ..moveTo(0, size.height * .83)
      ..quadraticBezierTo(size.width * .4, size.height * .64, size.width * .75, size.height * .84)
      ..quadraticBezierTo(size.width * .9, size.height * .89, size.width, size.height * .76)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(front, Paint()..color = variation % 3 == 2
        ? const Color(0xFF243742) : const Color(0xFF415849));
  }

  @override
  bool shouldRepaint(covariant _ScenicPainter oldDelegate) => oldDelegate.variation != variation;
}

class BookCover extends StatelessWidget {
  final int variation;
  final double width;
  final double height;
  const BookCover({super.key, this.variation = 0, this.width = 58, this.height = 78});

  @override
  Widget build(BuildContext context) {
    final tones = <List<Color>>[
      [const Color(0xFF99836D), const Color(0xFF4F473B)],
      [const Color(0xFF90A3A0), const Color(0xFF45636D)],
      [const Color(0xFFBCA184), const Color(0xFFA86755)],
      [const Color(0xFF969B7B), const Color(0xFF4B604B)],
    ][variation % 4];
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: tones, begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: const BorderRadius.horizontal(left: Radius.circular(5), right: Radius.circular(10)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .14), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Stack(
        children: [
          Positioned(left: 6, top: 0, bottom: 0,
            child: Container(width: 3, color: Colors.black.withValues(alpha: .14))),
          Center(
            child: Icon(variation.isEven ? Icons.auto_stories_outlined : Icons.spa_outlined,
              size: width * .36, color: const Color(0xFFF1E8D9)),
          ),
        ],
      ),
    );
  }
}
