import 'package:flutter/material.dart';

import 'ai_comparison_card.dart';
import '../../app/app_scope.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/page_container.dart';
import '../../core/widgets/property_art.dart';
import '../../models/recommendation.dart';
import '../../models/user_preferences.dart';

class ComparisonScreen extends StatelessWidget {
  const ComparisonScreen({
    required this.recommendations,
    super.key,
  });

  final List<PropertyRecommendation> recommendations;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final goal = state.preferences.goal;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Compare recommendations'),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                16,
                12,
                16,
                4,
              ),
              child: AiComparisonCard(
                recommendations: recommendations,
                goal: goal,
              ),
            ),

            const SizedBox(height: 8),

            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: recommendations.length * 310 + 30,
                child: PageContainer(
                  maxWidth: double.infinity,
                  child: Row(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: recommendations
                        .map(
                          (item) => SizedBox(
                        width: 300,
                        child: Padding(
                          padding:
                          const EdgeInsets.only(
                            right: 14,
                          ),
                          child: _ComparisonColumn(
                            recommendation: item,
                            goal: goal,
                          ),
                        ),
                      ),
                    )
                        .toList(),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _ComparisonColumn extends StatelessWidget {
  const _ComparisonColumn({
    required this.recommendation,
    required this.goal,
  });

  final PropertyRecommendation recommendation;
  final PropertyGoal goal;

  @override
  Widget build(BuildContext context) {
    final property = recommendation.property;
    final price = property.price;
    final pricePerSqft = property.pricePerSqft;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stack(
            children: [
              PropertyArt(
                palette: property.palette,
                height: 170,
              ),

              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.blue,
                    borderRadius:
                    BorderRadius.circular(6),
                  ),
                  child: Text(
                    goal == PropertyGoal.ownStay
                        ? 'OWN STAY'
                        : 'INVESTMENT',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ),

          Padding(
            padding: const EdgeInsets.all(17),
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  property.name,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge,
                ),

                const SizedBox(height: 4),

                Text(
                  property.address,
                  style: const TextStyle(
                    color: AppTheme.muted,
                    fontSize: 12,
                  ),
                ),

                const SizedBox(height: 10),

                Text(
                  price == null
                      ? 'Price unavailable'
                      : formatRinggit(price),
                  style: TextStyle(
                    color: price == null
                        ? AppTheme.muted
                        : AppTheme.green,
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                  ),
                ),

                const SizedBox(height: 14),

                _Row(
                  label: 'Overall score',
                  value:
                  '${recommendation.score.round()}/100',
                  highlight: true,
                ),

                _Row(
                  label: 'Price psf',
                  value: pricePerSqft == null
                      ? 'Unavailable'
                      : formatRinggit(
                    pricePerSqft.round(),
                  ),
                ),

                _Row(
                  label: 'Property type',
                  value: property.type,
                ),

                _Row(
                  label: 'Tenure',
                  value: property.tenure,
                ),

                const SizedBox(height: 16),

                Text(
                  goal == PropertyGoal.ownStay
                      ? 'Own-stay indicators'
                      : 'Investment indicators',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 8),

                ...recommendation.factors.map(
                      (factor) => _Row(
                    label: factor.label,
                    value:
                    '${factor.score.round()}/100',
                  ),
                ),

                const SizedBox(height: 16),

                const Divider(),

                const SizedBox(height: 8),

                const Text(
                  'Score breakdown',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 4),

                const Text(
                  'Each indicator contributes to the final score according to its assigned weight.',
                  style: TextStyle(
                    color: AppTheme.muted,
                    fontSize: 10,
                  ),
                ),

                const SizedBox(height: 12),

                ...recommendation.factors.map(
                      (factor) => _FactorBreakdown(
                    factor: factor,
                  ),
                ),

                const SizedBox(height: 10),

                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.blue.withValues(
                      alpha: 0.06,
                    ),
                    borderRadius:
                    BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Final weighted score',
                          style: TextStyle(
                            fontWeight:
                            FontWeight.w800,
                          ),
                        ),
                      ),
                      Text(
                        '${recommendation.score.toStringAsFixed(1)}/100',
                        style: const TextStyle(
                          color: AppTheme.blue,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                const Text(
                  'Advantages',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 7),

                ...recommendation.reasons.map(
                      (item) => _BulletItem(
                    text: item,
                    positive: true,
                  ),
                ),

                const SizedBox(height: 14),

                const Text(
                  'Watch out for',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 7),

                ...recommendation.cautions.map(
                      (item) => _BulletItem(
                    text: item,
                    positive: false,
                  ),
                ),

                if (property.source.isNotEmpty) ...[
                  const SizedBox(height: 16),

                  const Divider(),

                  const SizedBox(height: 8),

                  const Text(
                    'Data source',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                    ),
                  ),

                  const SizedBox(height: 5),

                  Text(
                    property.source,
                    style: const TextStyle(
                      color: AppTheme.muted,
                      fontSize: 10,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FactorBreakdown extends StatelessWidget {
  const _FactorBreakdown({
    required this.factor,
  });

  final ScoreFactor factor;

  @override
  Widget build(BuildContext context) {
    final weightPercent =
        factor.weight * 100;

    final contribution =
        factor.contribution;

    return Padding(
      padding: const EdgeInsets.only(
        bottom: 13,
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  factor.label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight:
                    FontWeight.w600,
                  ),
                ),
              ),

              Text(
                '${factor.score.round()} × '
                    '${weightPercent.round()}%',
                style: const TextStyle(
                  color: AppTheme.muted,
                  fontSize: 10,
                ),
              ),
            ],
          ),

          const SizedBox(height: 5),

          LinearProgressIndicator(
            value: (factor.score / 100)
                .clamp(0.0, 1.0),
            minHeight: 6,
            borderRadius:
            BorderRadius.circular(6),
          ),

          const SizedBox(height: 4),

          Align(
            alignment:
            Alignment.centerRight,
            child: Text(
              'Contribution: '
                  '${contribution.toStringAsFixed(1)} pts',
              style: const TextStyle(
                color: AppTheme.muted,
                fontSize: 9,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BulletItem extends StatelessWidget {
  const _BulletItem({
    required this.text,
    required this.positive,
  });

  final String text;
  final bool positive;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        bottom: 6,
      ),
      child: Row(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Icon(
            positive
                ? Icons
                .check_circle_outline_rounded
                : Icons.warning_amber_rounded,
            size: 16,
            color: positive
                ? AppTheme.green
                : const Color(
              0xFFB7791F,
            ),
          ),

          const SizedBox(width: 6),

          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppTheme.muted,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
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
      padding: const EdgeInsets.symmetric(
        vertical: 7,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppTheme.muted,
                fontSize: 12,
              ),
            ),
          ),

          const SizedBox(width: 8),

          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: highlight
                    ? AppTheme.blue
                    : AppTheme.ink,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}