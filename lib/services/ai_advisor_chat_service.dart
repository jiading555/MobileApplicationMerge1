import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/gemini_config.dart';
import '../models/recommendation.dart';
import '../models/user_preferences.dart';

class AiAdvisorChatService {
  const AiAdvisorChatService();

  Future<String> sendMessage({
    required String question,
    required List<PropertyRecommendation> recommendations,
    required UserPreferences preferences,
    List<Map<String, String>> conversationHistory = const [],
  }) async {
    if (question.trim().isEmpty) {
      throw Exception(
        'Question cannot be empty.',
      );
    }

    if (recommendations.isEmpty) {
      throw Exception(
        'No recommendation data is available for the AI advisor.',
      );
    }

    final prompt = buildPrompt(
      question: question.trim(),
      recommendations: recommendations,
      preferences: preferences,
      conversationHistory: conversationHistory,
    );

    try {
      final response = await Supabase.instance.client.functions
          .invoke(
            GeminiConfig.edgeFunctionName,
            body: {'prompt': prompt},
          )
          .timeout(const Duration(seconds: 90));

      final data = response.data;
      if (data is! Map) {
        throw Exception('Gemini returned an invalid response.');
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
        throw Exception('Gemini returned an empty advisor response.');
      }

      return text;
    } on TimeoutException {
      throw Exception(
        'The AI advisor is taking longer than expected. '
            'Please check your internet connection and try again.',
      );
    } catch (error) {
      final message = error.toString();

      // Avoid wrapping our own friendly errors repeatedly.
      if (message.contains(
        'AI request limit reached',
      ) ||
          message.contains(
            'AI service is temporarily busy',
          ) ||
          message.contains(
            'Gemini API error',
          ) ||
          message.contains(
            'Gemini returned',
          )) {
        rethrow;
      }

      throw Exception(
        'Failed to get AI advisor response. '
            'Please try again.',
      );
    }
  }

  String buildPrompt({
    required String question,
    required List<PropertyRecommendation>
    recommendations,
    required UserPreferences preferences,
    List<Map<String, String>>
    conversationHistory = const [],
  }) {
    final topRecommendations =
    recommendations.take(3).toList();

    final recommendationContext =
    topRecommendations
        .asMap()
        .entries
        .map((entry) {
      final index =
          entry.key + 1;

      final recommendation =
          entry.value;

      final property =
          recommendation.property;

      final sortedFactors =
      List<ScoreFactor>.from(
        recommendation.factors,
      )..sort(
            (a, b) =>
            b.weight.compareTo(
              a.weight,
            ),
      );

      final factors =
      sortedFactors
          .map(
            (factor) =>
        '- ${factor.label}: '
            '${factor.score.toStringAsFixed(1)}/100, '
            'applied weight '
            '${(factor.weight * 100).toStringAsFixed(1)}%, '
            'contribution '
            '${factor.contribution.toStringAsFixed(1)} points',
      )
          .join('\n');

      final advantages =
      recommendation
          .reasons
          .isEmpty
          ? 'None supplied'
          : recommendation.reasons
          .map(
            (item) =>
        '- $item',
      )
          .join('\n');

      final cautions =
      recommendation
          .cautions
          .isEmpty
          ? 'None supplied'
          : recommendation.cautions
          .map(
            (item) =>
        '- $item',
      )
          .join('\n');

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

      return '''
PROPERTY $index

Recommendation rank:
#$index

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

Scoring factors ordered from higher to lower applied weight:
$factors

Advantages identified by the deterministic recommendation system:
$advantages

Cautions identified by the deterministic recommendation system:
$cautions
''';
    })
        .join(
      '\n-----------------------------\n',
    );

    final historyText =
    conversationHistory.isEmpty
        ? 'No previous conversation.'
        : conversationHistory
        .map((message) {
      final role =
          message['role'] ??
              'unknown';

      final text =
          message['text'] ?? '';

      return '$role: $text';
    })
        .join('\n');

    final goal =
    preferences.goal ==
        PropertyGoal.ownStay
        ? 'Own Stay'
        : 'Investment';

    final preferredArea =
    preferences.preferredAreaId ==
        'any'
        ? 'Any area'
        : preferences.preferredAreaId;

    return '''
You are an AI Property Advisor for a Malaysian smart property recommendation application.

Your role is to explain and help the user understand recommendation results that have already been calculated by the application.

The application uses a deterministic weighted scoring algorithm.

You do NOT calculate the recommendation ranking.
You do NOT replace the application's scoring algorithm.

STRICT SCORING RULES:

1. Do NOT recalculate any suitability score.
2. Do NOT modify any supplied score.
3. Do NOT modify any applied weight.
4. Do NOT change the recommendation ranking.
5. Treat all supplied scores, weights, contributions and ranks as final system-calculated values.
6. When explaining suitability, discuss higher-weighted criteria before lower-weighted criteria.
7. Give more explanatory importance to criteria with higher applied weights.
8. Do not describe a lower-weighted criterion as the user's main priority.
9. If two or more properties have the same score for a factor, clearly state that none of them gains an advantage on that factor.
10. If overall suitability scores are tied, do not invent a winner.

STRICT DATA RULES:

11. Use only information explicitly supplied in this prompt.
12. Do NOT invent property information.
13. Do NOT invent crime, income, transportation, education, market, rental, investment, developer or location information.
14. Do NOT claim that information exists if it has not been supplied.
15. Do NOT infer missing property attributes from general knowledge.
16. Do NOT make guaranteed financial or investment predictions.
17. If the available information is insufficient, clearly state that the system does not currently have enough data to answer confidently.

IMPORTANT PROPERTY DATA RESTRICTIONS:

18. Never state or assume a property's tenure unless an actual tenure value such as Freehold or Leasehold is explicitly supplied.
19. Do NOT interpret PPAM, PR1MA, SPNB or another housing scheme as property tenure.
20. Never state or assume property condition unless an actual property-condition value is explicitly supplied.
21. Never state or assume financing requirements unless actual financing information is explicitly supplied.
22. Never state or assume facilities, nearby amenities, rental performance, future appreciation, market outlook or development potential unless that information is explicitly supplied.
23. Even if a generic caution mentions tenure, financing or property condition, do not repeat it as a property-specific fact unless supporting concrete data is supplied.
24. Do not use phrases such as "fully meets", "guaranteed", "completely safe", "best investment", "certain return" or other absolute claims unless explicitly supported by supplied data.

MULTIPLE PROPERTY RULES:

25. There are ${topRecommendations.length} recommendation result(s) supplied in this prompt.
26. If more than one recommendation is supplied, do NOT say that no other property data is available.
27. If the user asks about only one property, focus on that property, but remain aware that other recommendations may also be available.
28. Only compare properties when the user's question requires a comparison.
29. When comparing properties, respect the applied scoring weights and supplied scores.
30. If properties have equal overall scores, explain the tie rather than inventing a winner. Practical supplied differences such as price may be discussed, but they must not replace the calculated ranking.

ANSWER STYLE RULES:

31. Keep the answer practical, concise and easy for a normal property buyer to understand.
32. Prefer approximately 100 to 180 words unless the user specifically asks for more detail.
33. Explain the user's highest-weighted criterion first when answering why a property is recommended.
34. Clearly distinguish between:
    - user priority
    - factor score
    - applied weight
    - contribution to overall score
35. Do not describe an affordability score as the highest priority when another factor has a higher applied weight.
36. Return plain text only.
37. Do NOT use Markdown formatting.
38. Do NOT use asterisks for bold text.
39. Do NOT use Markdown headings such as #, ## or ###.
40. Simple numbered points are allowed when useful.

USER PREFERENCES

Goal:
$goal

Budget:
RM ${preferences.budget.toStringAsFixed(0)}

Preferred area:
$preferredArea

Preferred property type:
${preferences.propertyType}

CURRENT SMART RECOMMENDATION RESULTS

$recommendationContext

PREVIOUS CHAT

$historyText

CURRENT USER QUESTION

$question

Answer the user's question as a property decision-support advisor.

Remember:
- The system has already calculated the scores and ranking.
- Explain the supplied results rather than recalculating them.
- Prioritise higher-weighted criteria in the explanation.
- Use only supplied information.
- Do not invent missing property information.
- Return plain text only.
''';
  }
}