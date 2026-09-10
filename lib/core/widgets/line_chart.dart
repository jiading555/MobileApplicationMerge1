import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class SimpleLineChart extends StatefulWidget {
  const SimpleLineChart({
    required this.values,
    this.height = 190,
    this.color = AppTheme.blue,
    this.labels = const [],
    super.key,
  });

  final List<double> values;
  final double height;
  final Color color;
  final List<String> labels;

  @override
  State<SimpleLineChart> createState() => _SimpleLineChartState();
}

class _SimpleLineChartState extends State<SimpleLineChart> {
  int? selectedIndex;

  @override
  void didUpdateWidget(covariant SimpleLineChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.values != widget.values ||
        oldWidget.labels != widget.labels) {
      selectedIndex = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: LayoutBuilder(
        builder: (context, constraints) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: widget.values.length < 2
              ? null
              : (details) {
                  const horizontalPadding = 8.0;
                  final chartWidth = math.max(
                    1.0,
                    constraints.maxWidth - horizontalPadding * 2,
                  );
                  final ratio =
                      ((details.localPosition.dx - horizontalPadding) /
                              chartWidth)
                          .clamp(0.0, 1.0);
                  final index = (ratio * (widget.values.length - 1))
                      .round()
                      .clamp(0, widget.values.length - 1)
                      .toInt();
                  setState(() => selectedIndex = index);
                },
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _LineChartPainter(
                    values: widget.values,
                    color: widget.color,
                    labels: widget.labels,
                    selectedIndex: selectedIndex,
                  ),
                ),
              ),
              if (selectedIndex != null)
                Positioned(
                  top: 4,
                  left: 12,
                  right: 12,
                  child: Center(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppTheme.ink,
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        child: Text(
                          '${_labelAt(selectedIndex!)} · '
                          'RM ${_formatValue(widget.values[selectedIndex!])}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _labelAt(int index) {
    return widget.labels.length == widget.values.length
        ? widget.labels[index]
        : '${index + 1}';
  }

  String _formatValue(double value) {
    final digits = value.round().toString();
    return digits.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
  }
}

class _LineChartPainter extends CustomPainter {
  const _LineChartPainter({
    required this.values,
    required this.color,
    required this.labels,
    required this.selectedIndex,
  });

  final List<double> values;
  final Color color;
  final List<String> labels;
  final int? selectedIndex;

  @override
  void paint(Canvas canvas, Size size) {
    const left = 8.0;
    const top = 40.0;
    const bottom = 24.0;
    final chartHeight = size.height - top - bottom;
    final chartWidth = size.width - left - 8;
    if (chartHeight <= 0 || chartWidth <= 0) return;

    final grid = Paint()
      ..color = const Color(0xFFE7ECF3)
      ..strokeWidth = 1;
    for (var row = 0; row < 4; row++) {
      final y = top + chartHeight * row / 3;
      canvas.drawLine(Offset(left, y), Offset(left + chartWidth, y), grid);
    }
    if (values.length < 2) return;

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

    for (var index = 0; index < points.length; index++) {
      final selected = selectedIndex == index;
      if (selected) {
        canvas.drawCircle(
          points[index],
          8,
          Paint()..color = color.withValues(alpha: 0.22),
        );
      }
      canvas.drawCircle(
        points[index],
        selected ? 5 : 3.5,
        Paint()..color = color,
      );
      canvas.drawCircle(
        points[index],
        selected ? 2.4 : 1.7,
        Paint()..color = Colors.white,
      );
    }

    final displayLabels = labels.length == values.length
        ? labels
        : List.generate(values.length, (index) => '${index + 1}');
    for (var index = 0; index < values.length; index++) {
      if (values.length > 5 && index.isOdd && index != values.length - 1) {
        continue;
      }
      final painter = TextPainter(
        text: TextSpan(
          text: displayLabels[index],
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
      oldDelegate.values != values ||
      oldDelegate.color != color ||
      oldDelegate.labels != labels ||
      oldDelegate.selectedIndex != selectedIndex;
}
