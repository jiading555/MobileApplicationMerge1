import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AdvisorBrand extends StatelessWidget {
  const AdvisorBrand({this.compact = false, this.light = false, super.key});

  final bool compact;
  final bool light;

  @override
  Widget build(BuildContext context) {
    final foreground = light ? Colors.white : AppTheme.ink;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const _AdvisorMark(),
        if (!compact) ...[
          const SizedBox(width: 10),
          Flexible(
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  color: foreground,
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
                children: const [
                  TextSpan(text: 'Smart'),
                  TextSpan(
                    text: 'Advisor',
                    style: TextStyle(color: AppTheme.blue),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _AdvisorMark extends StatelessWidget {
  const _AdvisorMark();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 42,
      height: 42,
      child: CustomPaint(painter: _AdvisorPainter()),
    );
  }
}

class _AdvisorPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final background = Paint()..color = const Color(0xFFE5F0FF);
    final primary = Paint()..color = AppTheme.blue;
    final navy = Paint()..color = AppTheme.navy;
    final secondary = Paint()..color = AppTheme.teal;
    final white = Paint()..color = Colors.white;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(8)),
      background,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * 0.17,
          size.height * 0.46,
          size.width * 0.22,
          size.height * 0.31,
        ),
        const Radius.circular(3),
      ),
      primary,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * 0.40,
          size.height * 0.30,
          size.width * 0.23,
          size.height * 0.47,
        ),
        const Radius.circular(3),
      ),
      navy,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * 0.64,
          size.height * 0.38,
          size.width * 0.19,
          size.height * 0.39,
        ),
        const Radius.circular(3),
      ),
      secondary,
    );
    for (final point in [
      Offset(size.width * 0.25, size.height * 0.55),
      Offset(size.width * 0.25, size.height * 0.66),
      Offset(size.width * 0.49, size.height * 0.42),
      Offset(size.width * 0.49, size.height * 0.54),
      Offset(size.width * 0.49, size.height * 0.66),
      Offset(size.width * 0.71, size.height * 0.50),
      Offset(size.width * 0.71, size.height * 0.62),
    ]) {
      canvas.drawCircle(point, 1.8, white);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
