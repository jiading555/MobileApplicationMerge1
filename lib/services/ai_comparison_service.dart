import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/config/gemini_config.dart';
import '../models/recommendation.dart';
import '../models/user_preferences.dart';

class AiComparisonService {
  const AiComparisonService();

  Future<String> generateComparisonSummary({
    required List<PropertyRecommendation> recommendations,
    required PropertyGoal goal,
  }) async {
    if (!GeminiConfig.isConfigured) {
      throw Exception(
        'Gemini API key is not configured.',
      );
    }

    if (recommendations.length < 2 ||
        recommendations.length > 3) {
      throw Exception(
        'Please compare between 2 and 3 properties.',
      );
    }

    final prompt = buildPrompt(
      recommendations: recommendations,
      goal: goal,
    );

    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/'
          'v1beta/models/${GeminiConfig.model}:generateContent',
    );

    for (int attempt = 0; attempt < 3; attempt++) {
      try {
        final response = await http
            .post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'x-goog-api-key':
            GeminiConfig.apiKey,
          },
          body: jsonEncode({
            'contents': [
              {
                'parts': [
                  {
                    'text': prompt,
                  },
                ],
              },
            ],
            'generationConfig': {
              'temperature': 0.3,
              'maxOutputTokens': 400,
            },
          }),
        )
            .timeout(
          const Duration(seconds: 90),
        );

        if (response.statusCode == 503 &&
            attempt < 2) {
          await Future.delayed(
            Duration(
              seconds: 2 * (attempt + 1),
            ),
          );

          continue;
        }

        if (response.statusCode == 503) {
          throw Exception(
            'AI service is temporarily busy. '
                'Please try again later.',
          );
        }

        if (response.statusCode == 429) {
          throw Exception(
            'AI request limit reached. '
                'Please try again later.',
          );
        }

        if (response.statusCode != 200) {
          throw Exception(
            'Gemini API error: '
                '${response.statusCode}',
          );
        }

        final data =
        jsonDecode(response.body)
        as Map<String, dynamic>;

        final candidates =
        data['candidates']
        as List<dynamic>?;

        if (candidates == null ||
            candidates.isEmpty) {
          throw Exception(
            'Gemini returned no comparison.',
          );
        }

        final first =
        candidates.first
        as Map<String, dynamic>;

        final content =
        first['content']
        as Map<String, dynamic>?;

        final parts =
        content?['parts']
        as List<dynamic>?;

        if (parts == null ||
            parts.isEmpty) {
          throw Exception(
            'Gemini returned empty content.',
          );
        }

        final text = parts
            .map((part) {
          final item =
          part
          as Map<String, dynamic>;

          return item['text']
              ?.toString() ??
              '';
        })
            .join()
            .trim();

        if (text.isEmpty) {
          throw Exception(
            'Gemini returned an empty comparison.',
          );
        }

        return text;
      } on TimeoutException {
        throw Exception(
          'AI comparison is taking longer than expected. '
              'Please check your internet connection and try again.',
        );
      }
    }

    throw Exception(
      'Unable to generate comparison.',
    );
  }

  String buildPrompt({
    required List<PropertyRecommendation>
    recommendations,
    required PropertyGoal goal,
  }) {
    final firstFactors =
        recommendations.first.factors;

    if (firstFactors.isEmpty) {
      throw Exception(
        'No scoring factors are available '
            'for comparison.',
      );
    }

    final sortedWeights =
    List<ScoreFactor>.from(
      firstFactors,
    )..sort(
          (a, b) =>
          b.weight.compareTo(a.weight),
    );

    final highestFactor =
        sortedWeights.first;

    final appliedWeights =
    sortedWeights
        .map(
          (factor) =>
      '${factor.label}: '
          '${(factor.weight * 100).toStringAsFixed(1)}%',
    )
        .join('\n');

    final propertyText =
    recommendations
        .asMap()
        .entries
        .map((entry) {
      final index =
          entry.key + 1;

      final recommendation =
          entry.value;

      final property =
          recommendation.property;

      final price =
      property.price == null
          ? 'Unavailable'
          : 'RM ${property.price}';

      final normalizedTypes =
          property
              .normalizedPropertyTypes;

      final propertyType =
      normalizedTypes.isEmpty
          ? 'Unavailable'
          : normalizedTypes.join(
        ', ',
      );

      final factors =
      recommendation.factors
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

      final advantages =
      recommendation.reasons
          .map(
            (item) =>
        '- $item',
      )
          .join('\n');

      final cautions =
      recommendation.cautions
          .map(
            (item) =>
        '- $item',
      )
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
}