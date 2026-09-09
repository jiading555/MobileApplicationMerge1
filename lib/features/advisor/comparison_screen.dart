import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/page_container.dart';
import '../../core/widgets/property_art.dart';
import '../../models/recommendation.dart';

class ComparisonScreen extends StatelessWidget {
  const ComparisonScreen({required this.recommendations, super.key});

  final List<PropertyRecommendation> recommendations;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Compare recommendations')),
      body: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: recommendations.length * 300 + 40,
          child: SingleChildScrollView(
            child: PageContainer(
              maxWidth: double.infinity,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: recommendations
                    .map(
                      (item) => Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 14),
                          child: _ComparisonColumn(recommendation: item),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ComparisonColumn extends StatelessWidget {
  const _ComparisonColumn({required this.recommendation});

  final PropertyRecommendation recommendation;

  @override
  Widget build(BuildContext context) {
    final property = recommendation.property;
    final area = AppScope.of(context).areaFor(property.areaId);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PropertyArt(palette: property.palette, height: 170),
          Padding(
            padding: const EdgeInsets.all(17),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  property.name,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  property.address,
                  style: const TextStyle(color: AppTheme.muted, fontSize: 12),
                ),
                const SizedBox(height: 10),
                Text(
                  formatRinggit(property.price!),
                  style: const TextStyle(
                    color: AppTheme.green,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 14),
                _Row(
                  label: 'Overall score',
                  value: '${recommendation.score.round()}/100',
                  highlight: true,
                ),
                _Row(
                  label: 'Price psf',
                  value: property.pricePerSqft == null
                      ? 'Unavailable'
                      : formatRinggit(property.pricePerSqft!.round()),
                ),
                _Row(label: 'Safety', value: _scoreText(area.safetyScore)),
                _Row(
                  label: 'Infrastructure',
                  value: _scoreText(area.infrastructureScore),
                ),
                _Row(
                  label: 'Price growth',
                  value: _percentText(area.priceGrowth),
                ),
                _Row(
                  label: 'Rental yield',
                  value: _percentText(area.rentalYield),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Score breakdown',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                ...recommendation.factors.map(
                  (factor) => Padding(
                    padding: const EdgeInsets.only(bottom: 9),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                factor.label,
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                            Text(
                              '${factor.score.round()}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        LinearProgressIndicator(
                          value: factor.score / 100,
                          minHeight: 6,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Watch out for',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                ...recommendation.cautions.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Text(
                      '- $item',
                      style: const TextStyle(
                        color: AppTheme.muted,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _scoreText(double? value) {
  return value == null ? 'N/A' : '${value.round()}/100';
}

String _percentText(double? value) {
  return value == null ? 'Not available' : '${value.toStringAsFixed(1)}%';
}

class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: AppTheme.muted, fontSize: 12),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: highlight ? AppTheme.blue : AppTheme.ink,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
