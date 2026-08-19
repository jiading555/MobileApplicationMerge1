import 'package:flutter/material.dart';

class PropertyArt extends StatelessWidget {
  const PropertyArt({
    required this.palette,
    this.height = 180,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
    super.key,
  });

  final int palette;
  final double height;
  final BorderRadius borderRadius;

  static const palettes = [
    [Color(0xFFB8DDFC), Color(0xFF366D95), Color(0xFF173D5F)],
    [Color(0xFFE7C9A9), Color(0xFF9A6544), Color(0xFF513728)],
    [Color(0xFFC5E0C6), Color(0xFF5B8E61), Color(0xFF244D39)],
    [Color(0xFFB8E4E9), Color(0xFF367F8D), Color(0xFF174D64)],
    [Color(0xFFF4DAB5), Color(0xFFAF744A), Color(0xFF5E412C)],
    [Color(0xFFD1CBEA), Color(0xFF756B9A), Color(0xFF3D385E)],
    [Color(0xFFD4E7B6), Color(0xFF74944D), Color(0xFF3D5527)],
    [Color(0xFFC2DDF5), Color(0xFF527BA5), Color(0xFF284A6C)],
    [Color(0xFFE2D2B8), Color(0xFF8A6D4E), Color(0xFF4D3929)],
    [Color(0xFFC4DDD8), Color(0xFF54837A), Color(0xFF28534D)],
  ];

  @override
  Widget build(BuildContext context) {
    final colors = palettes[palette % palettes.length];
    return ClipRRect(
      borderRadius: borderRadius,
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(painter: _PropertyPainter(colors)),
      ),
    );
  }
}

class _PropertyPainter extends CustomPainter {
  const _PropertyPainter(this.colors);

  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final sky = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [colors[0], Colors.white],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, sky);

    final cloud = Paint()..color = Colors.white.withValues(alpha: 0.68);
    canvas.drawCircle(Offset(size.width * 0.17, size.height * 0.20), 18, cloud);
    canvas.drawCircle(Offset(size.width * 0.25, size.height * 0.18), 25, cloud);
    canvas.drawCircle(Offset(size.width * 0.34, size.height * 0.21), 17, cloud);

    final ground = Paint()..color = colors[1].withValues(alpha: 0.30);
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 0.78, size.width, size.height * 0.22),
      ground,
    );

    final building = Paint()..color = colors[2];
    final wing = Paint()..color = colors[1];
    final glass = Paint()..color = const Color(0xFFDDF4FF);
    final trunk = Paint()..color = const Color(0xFF75543B);
    final leaves = Paint()..color = const Color(0xFF2F8153);
    final baseY = size.height * 0.82;
    final tower = Rect.fromLTRB(
      size.width * 0.31,
      size.height * 0.22,
      size.width * 0.69,
      baseY,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(tower, const Radius.circular(4)),
      building,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(
          size.width * 0.16,
          size.height * 0.45,
          size.width * 0.34,
          baseY,
        ),
        const Radius.circular(4),
      ),
      wing,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(
          size.width * 0.66,
          size.height * 0.39,
          size.width * 0.84,
          baseY,
        ),
        const Radius.circular(4),
      ),
      wing,
    );
    for (var row = 0; row < 5; row++) {
      for (var column = 0; column < 4; column++) {
        final left = size.width * (0.35 + column * 0.075);
        final top = size.height * (0.29 + row * 0.09);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(left, top, size.width * 0.045, size.height * 0.045),
            const Radius.circular(1.5),
          ),
          glass,
        );
      }
    }
    for (final x in [0.09, 0.9]) {
      canvas.drawRect(
        Rect.fromLTWH(
          size.width * x,
          size.height * 0.68,
          4,
          size.height * 0.18,
        ),
        trunk,
      );
      canvas.drawCircle(
        Offset(size.width * x + 2, size.height * 0.64),
        16,
        leaves,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PropertyPainter oldDelegate) =>
      oldDelegate.colors != colors;
}
