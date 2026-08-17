import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class SimpleLineChart extends StatelessWidget {
  const SimpleLineChart({
    required this.values,
    this.height = 190,
    this.color = AppTheme.blue,
    super.key,
  });

  final List<double> values;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _LineChartPainter(values: values, color: color),
      ),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  const _LineChartPainter({required this.values, required this.color});

  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const left = 8.0;
    const top = 12.0;
    const bottom = 24.0;
    final chartHeight = size.height - top - bottom;
    final chartWidth = size.width - left - 8;
    final grid = Paint()
      ..color = const Color(0xFFE7ECF3)
      ..strokeWidth = 1;
    for (var row = 0; row < 4; row++) {
      final y = top + chartHeight * row / 3;
      canvas.drawLine(Offset(left, y), Offset(left + chartWidth, y), grid);
    }
    if (values.length < 2) {
      return;
    }
    final minimum = values.reduce(math.min);
    final maximum = values.reduce(math.max);
    final range = math.max(1, maximum - minimum);
    final points = <Offset>[];
    for (var index = 0; index < values.length; index++) {
      final x = left + chartWidth * index / (values.length - 1);
      final normalized = (values[index] - minimum) / range;
      final y = top + chartHeight * (1 - normalized * 0.86);
      points.add(Offset(x, y));
    }
    final fillPath = Path()..moveTo(points.first.dx, top + chartHeight);
    for (final point in points) {
      fillPath.lineTo(point.dx, point.dy);
    }
    fillPath
      ..lineTo(points.last.dx, top + chartHeight)
      ..close();
    final fill = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withValues(alpha: 0.26), color.withValues(alpha: 0.01)],
      ).createShader(Rect.fromLTWH(left, top, chartWidth, chartHeight));
    canvas.drawPath(fillPath, fill);
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var index = 1; index < points.length; index++) {
      final previous = points[index - 1];
      final current = points[index];
      final midpoint = (previous.dx + current.dx) / 2;
      path.cubicTo(
        midpoint,
        previous.dy,
        midpoint,
        current.dy,
        current.dx,
        current.dy,
      );
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
    final dot = Paint()..color = color;
    for (final point in points) {
      canvas.drawCircle(point, 3.5, dot);
      canvas.drawCircle(point, 1.7, Paint()..color = Colors.white);
    }
    final labels = ['2018', '2019', '2020', '2021', '2022', '2023', '2024'];
    for (var index = 0; index < values.length; index++) {
      if (index.isOdd && index != values.length - 1) {
        continue;
      }
      final painter = TextPainter(
        text: TextSpan(
          text: index < labels.length ? labels[index] : '${index + 1}',
          style: const TextStyle(color: AppTheme.muted, fontSize: 9),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(
        canvas,
        Offset(points[index].dx - painter.width / 2, size.height - 15),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.color != color;
}
