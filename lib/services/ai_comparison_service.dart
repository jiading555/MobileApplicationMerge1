import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/gemini_config.dart';
import '../core/utils/network_error_mapper.dart';
import '../models/recommendation.dart';
import '../models/user_preferences.dart';

class AiComparisonService {
  const AiComparisonService();

  Future<String> generateComparisonSummary({
    required List<PropertyRecommendation> recommendations,
    required PropertyGoal goal,
  }) async {
    if (recommendations.length < 2 || recommendations.length > 3) {
      throw Exception('Please compare between 2 and 3 properties.');
    }

    final prompt = buildPrompt(recommendations: recommendations, goal: goal);

    try {
      final response = await Supabase.instance.client.functions
          .invoke(GeminiConfig.edgeFunctionName, body: {'prompt': prompt})
          .timeout(const Duration(seconds: 90));

      final data = response.data;
      if (data is! Map) {
        throw Exception('Gemini returned an invalid comparison response.');
      }

      final error = data['error']?.toString().trim();
      if (response.status != 200 || (error != null && error.isNotEmpty)) {
        throw Exception(
          error == null || error.isEmpty
              ? 'Gemini API error: ${response.status}'
              : 'Gemini API error: $error',
        );
      }

      final text = data['text']?.toString().trim() ?? '';
      if (text.isEmpty) {
        throw Exception('Gemini returned an empty comparison.');
      }

      return text;
    } on TimeoutException {
      throw Exception(NetworkErrorMapper.offlineMessage);
    } catch (error) {
      if (NetworkErrorMapper.isNetworkError(error)) {
        throw Exception(NetworkErrorMapper.offlineMessage);
      }
      throw Exception(NetworkErrorMapper.aiFailureMessage);
    }
  }

  String buildPrompt({
    required List<PropertyRecommendation> recommendations,
    required PropertyGoal goal,
  }) {
    final firstFactors = recommendations.first.factors;

    if (firstFactors.isEmpty) {
      throw Exception(
        'No scoring factors are available '
        'for comparison.',
      );
    }

    final sortedWeights = List<ScoreFactor>.from(firstFactors)
      ..sort((a, b) => b.weight.compareTo(a.weight));

    final highestFactor = sortedWeights.first;

    final appliedWeights = sortedWeights
        .map(
          (factor) =>
              '${factor.label}: '
              '${(factor.weight * 100).toStringAsFixed(1)}%',
        )
        .join('\n');

    final propertyText = recommendations
        .asMap()
        .entries
        .map((entry) {
          final index = entry.key + 1;

          final recommendation = entry.value;

          final property = recommendation.property;

          final price = _priceText(
            property.price,
            property.priceMin,
            property.priceMax,
          );

          final normalizedTypes = property.normalizedPropertyTypes;

          final propertyType = normalizedTypes.isEmpty
              ? 'Unavailable'
              : normalizedTypes.join(', ');

          final factors = recommendation.factors
              .map(
                (factor) =>
                    '${factor.label}: '
                    '${factor.score.toStringAsFixed(1)}/100, '
                    'weight '
                    '${(factor.weight * 100).toStringAsFixed(1)}%, '
                    'contribution '
                    '${factor.contribution.toStringAsFixed(1)} points',
              )
              .join('\n');

          final advantages = recommendation.reasons
              .map((item) => '- $item')
              .join('\n');

          final cautions = recommendation.cautions
              .map((item) => '- $item')
              .join('\n');

          return '''
PROPERTY $index

Name:
${property.name}

Location:
${property.address}

Property type:
$propertyType

Price:
$price

Overall suitability score:
${recommendation.score.toStringAsFixed(1)}/100

Factors:
$factors

Advantages:
$advantages

Cautions:
$cautions
''';
        })
        .join('\n');

    return '''
You are a property decision-support assistant for Malaysia.

The application has already calculated all suitability scores and applied weights.

Do NOT:
- recalculate scores
- change scores
- change weights
- invent property data
- invent external facts

User goal:
${goal == PropertyGoal.ownStay ? 'Own Stay' : 'Investment'}

The user's HIGHEST PRIORITY criterion is:
${highestFactor.label}

Highest applied weight:
${(highestFactor.weight * 100).toStringAsFixed(1)}%

Applied scoring weights:
$appliedWeights

Compare these properties:

$propertyText

Generate a concise comparison of about 120 to 180 words.

IMPORTANT COMPARISON RULES:

1. Compare the properties according to the APPLIED WEIGHTS.
2. Give the highest-weighted criterion the greatest influence in the explanation.
3. Clearly state whether the properties differ on the user's highest-priority criterion.
4. If the properties have the same score for the highest-priority criterion, explicitly say that neither property gains an advantage on that criterion.
5. Lower-weighted criteria should receive less emphasis.
6. Do not describe a low-weight criterion as the main deciding factor.
7. If overall suitability scores are equal, do not invent a winner.
8. If scores are equal, explain the tie and describe practical differences such as supplied price, location, advantages or cautions.
9. Use only information supplied here.
10. Do not change the calculated ranking or scores.
11. Do not make financial guarantees.

Finish with a recommendation that respects the user's selected priorities.
''';
  }

  String _priceText(int? price, int? priceMin, int? priceMax) {
    if (priceMin != null && priceMax != null && priceMin != priceMax) {
      return 'RM $priceMin - RM $priceMax';
    }
    final displayPrice = price ?? priceMin ?? priceMax;
    return displayPrice == null ? 'Unavailable' : 'RM $displayPrice';
  }
}
