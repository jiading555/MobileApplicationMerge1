import 'package:flutter/material.dart';

class MetricCard extends StatelessWidget {
  const MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    this.trend,
    this.color = const Color(0xFF0867D9),
    super.key,
  });

  final String label;
  final String value;
  final IconData icon;
  final String? trend;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 21),
            ),
            const SizedBox(height: 14),
            Text(label, style: const TextStyle(color: Color(0xFF667085))),
            const SizedBox(height: 5),
            Text(value, style: Theme.of(context).textTheme.titleLarge),
            if (trend != null) ...[
              const SizedBox(height: 4),
              Text(
                trend!,
                style: TextStyle(
                  color: trend!.trimLeft().startsWith('-')
                      ? const Color(0xFFD14343)
                      : const Color(0xFF159A62),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
