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
        body: {
          'prompt': prompt,
        },
      )
          .timeout(
        const Duration(seconds: 90),
      );

      final data = response.data;

      if (data is! Map) {
        throw Exception(
          'Gemini returned an invalid response.',
        );
      }

      final error =
      data['error']?.toString().trim();

      if (response.status != 200 ||
          (error != null && error.isNotEmpty)) {
        throw Exception(
          error == null || error.isEmpty
              ? 'Gemini API error: ${response.status}'
              : 'Gemini API error: $error',
        );
      }

      final text =
          data['text']?.toString().trim() ?? '';

      if (text.isEmpty) {
        throw Exception(
          'Gemini returned an empty advisor response.',
        );
      }

      return text;
    } on TimeoutException {
      throw Exception(
        'The AI advisor is taking longer than expected. '
            'Please check your internet connection and try again.',
      );
    } catch (error) {
      final message = error.toString();

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
      final index = entry.key + 1;

      final recommendation =
          entry.value;

      final property =
          recommendation.property;

      // -------------------------------------------------------
      // SCORING FACTORS
      // -------------------------------------------------------

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
      sortedFactors.isEmpty
          ? 'None supplied'
          : sortedFactors
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

      // -------------------------------------------------------
      // RECOMMENDATION REASONS
      // -------------------------------------------------------

      final advantages =
      recommendation.reasons.isEmpty
          ? 'None supplied'
          : recommendation.reasons
          .map(
            (item) => '- $item',
      )
          .join('\n');

      final cautions =
      recommendation.cautions.isEmpty
          ? 'None supplied'
          : recommendation.cautions
          .map(
            (item) => '- $item',
      )
          .join('\n');

      // -------------------------------------------------------
      // PROPERTY BASIC DATA
      // -------------------------------------------------------

      final price = _priceText(
        property.price,
        property.priceMin,
        property.priceMax,
      );

      final normalizedTypes =
          property.normalizedPropertyTypes;

      final propertyType =
      normalizedTypes.isEmpty
          ? 'Unavailable'
          : normalizedTypes.join(', ');

      final rawUnitTypes =
      property.unitTypes.isEmpty
          ? 'Unavailable'
          : property.unitTypes.join(', ');

      final state = _textOrUnavailable(
        property.state,
      );

      final district = _textOrUnavailable(
        property.district,
      );

      final scheme = _textOrUnavailable(
        property.scheme,
      );

      final projectStatus =
      _textOrUnavailable(
        property.projectStatus,
      );

      final developer =
      _textOrUnavailable(
        property.developerName,
      );

      final tenure = _validTenure(
        property.tenure,
      );

      final totalUnits =
      property.totalUnits == null
          ? 'Unavailable'
          : property.totalUnits.toString();

      final availableUnits =
      property.availableUnits == null
          ? 'Unavailable'
          : property.availableUnits.toString();

      final bedrooms =
      property.bedrooms == null
          ? 'Unavailable'
          : property.bedrooms.toString();

      final bathrooms =
      property.bathrooms == null
          ? 'Unavailable'
          : property.bathrooms.toString();

      final sizeSqft =
      property.sizeSqft == null
          ? 'Unavailable'
          : '${property.sizeSqft} sq ft';

      // -------------------------------------------------------
      // UNIT OPTIONS
      //
      // Important:
      // unitOptions.length = number of listed configurations.
      // It is NOT the total available-unit inventory.
      // -------------------------------------------------------

      final unitOptionCount =
          property.unitOptions.length;

      final unitOptions =
      _unitOptionsText(
        property.unitOptions,
      );

      // -------------------------------------------------------
      // FACILITIES
      // -------------------------------------------------------

      final facilities =
      property.facilities.isEmpty
          ? 'Unavailable'
          : property.facilities
          .map(
            (item) => '- $item',
      )
          .join('\n');

      return '''
============================================================
PROPERTY $index
============================================================

RECOMMENDATION INFORMATION

Recommendation rank:
#$index

Overall suitability score:
${recommendation.score.toStringAsFixed(1)}/100

Scoring factors ordered from higher to lower applied weight:
$factors

Advantages identified by the deterministic recommendation system:
$advantages

Cautions identified by the deterministic recommendation system:
$cautions


PROPERTY FACTUAL INFORMATION

Property name:
${property.name}

Address:
${property.address}

State:
$state

District:
$district

Normalized property type:
$propertyType

Original unit types:
$rawUnitTypes

Housing scheme:
$scheme

Project status:
$projectStatus

Developer:
$developer

Tenure:
$tenure

Property/project price:
$price

Bedrooms:
$bedrooms

Bathrooms:
$bathrooms

Property size:
$sizeSqft


UNIT AVAILABILITY INFORMATION

Total project units:
$totalUnits

Available unit count:
$availableUnits

Number of listed unit options/configurations:
$unitOptionCount

IMPORTANT:
"Available unit count" and "Number of listed unit options/configurations"
are different values.

The number of listed unit options MUST NOT be treated as the number of
available units.

Listed unit options:
$unitOptions


FACILITIES SUPPLIED BY THE SYSTEM

$facilities
''';
    }).join(
      '\n\n',
    );

    // ---------------------------------------------------------
    // PREVIOUS CHAT
    // ---------------------------------------------------------

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
    }).join('\n');

    // ---------------------------------------------------------
    // USER PREFERENCES
    // ---------------------------------------------------------

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

    // ---------------------------------------------------------
    // COMPLETE GEMINI PROMPT
    // ---------------------------------------------------------

    return '''
You are an AI Property Advisor for a Malaysian smart property recommendation application.

Your role is to explain and help the user understand the CURRENT recommendation results and the factual property information supplied by the application.

The application has already retrieved the property data and calculated the recommendation ranking.

You do NOT calculate the recommendation ranking.
You do NOT replace the application's recommendation algorithm.
You do NOT independently search for other properties.


============================================================
STRICT SCORING RULES
============================================================

1. Do NOT recalculate any suitability score.

2. Do NOT modify any supplied score.

3. Do NOT modify any applied weight.

4. Do NOT change the recommendation ranking.

5. Treat all supplied scores, weights, contributions and ranks as final system-calculated values.

6. When explaining suitability, discuss higher-weighted criteria before lower-weighted criteria.

7. Give more explanatory importance to criteria with higher applied weights.

8. Do NOT describe a lower-weighted criterion as the user's main priority.

9. If two or more properties have the same factor score, clearly state that none gains an advantage on that factor.

10. If overall suitability scores are tied, do not invent a winner.


============================================================
PROPERTY FACTUAL DATA RULES
============================================================

11. PROPERTY FACTUAL INFORMATION comes from property data already loaded by the application.

12. You may use supplied factual information such as:
- property name
- address
- state
- district
- property type
- housing scheme
- project status
- developer
- tenure
- project price
- total units
- available unit count
- unit types
- unit options
- unit size
- unit starting price
- facilities

13. Only use a factual field when it is explicitly supplied.

14. If a field says "Unavailable", treat the information as unavailable.

15. Do NOT invent missing property information.

16. Do NOT infer missing values from general knowledge.

17. Do NOT invent crime, income, transportation, education, market, rental, investment, developer or location facts.

18. Do NOT make guaranteed financial or investment predictions.

19. If the required information is unavailable, clearly say that the current system data does not provide it.


============================================================
AVAILABLE UNIT RULES
============================================================

20. "Available unit count" means the explicitly supplied availableUnits value.

21. "Number of listed unit options/configurations" means the number of different unit options supplied to you.

22. These are NOT the same thing.

23. NEVER use the number of listed unit options as the total available-unit inventory.

24. Example:
If Available unit count = Unavailable
and Number of listed unit options = 3,
do NOT say:
"There are 3 available units."

Instead say:
"The total available-unit count is not provided, but the system lists 3 unit options."

25. If Available unit count is explicitly supplied, you may state that number.

26. If the user asks:
"How many available units are there?"
use Available unit count, not unitOptions.length.

27. If the user asks:
"What unit choices are available?"
describe the supplied listed unit options.

28. If the user asks:
"How many unit options are there?"
you may use Number of listed unit options/configurations.

29. If the user asks which supplied unit option is cheapest, compare only the supplied unit-option starting prices.

30. Do not assume that a lower starting price means that every unit of that type is available at that exact price.


============================================================
IMPORTANT PROPERTY RESTRICTIONS
============================================================

31. Never state or assume property tenure unless a real tenure value such as Freehold or Leasehold is explicitly supplied.

32. Do NOT interpret PPAM, PR1MA, SPNB, Residensi Wilayah, Rumah Mesra Rakyat or another housing scheme as property tenure.

33. A housing scheme and property tenure are different concepts.

34. Never state or assume property condition unless actual property-condition information is supplied.

35. Never state or assume financing requirements unless actual financing information is supplied.

36. Never state or assume rental performance, future appreciation, market outlook or development potential unless that information is explicitly supplied.

37. Facilities may only be discussed if they appear under FACILITIES SUPPLIED BY THE SYSTEM.

38. Do not use phrases such as:
"fully meets",
"guaranteed",
"completely safe",
"best investment",
"certain return",
or similar absolute claims unless explicitly supported.


============================================================
MULTIPLE PROPERTY RULES
============================================================

39. There are ${topRecommendations.length} current recommendation result(s).

40. Be aware of all supplied current recommendations.

41. If the user asks about Property #1, Property #2 or Property #3, use the matching numbered property.

42. If the user asks about only one property, focus on that property.

43. Only compare multiple properties when the user's question requires comparison.

44. When comparing properties, respect the supplied scores, weights and ranks.

45. Practical factual differences such as:
- price
- unit option
- unit size
- developer
- scheme
- available unit count
may be discussed when explicitly supplied.

46. These factual differences must not be used to secretly recalculate or replace the recommendation ranking.

47. If properties have equal overall scores, explain the tie instead of inventing a winner.


============================================================
STRICT CURRENT RECOMMENDATION SCOPE
============================================================

48. CURRENT SMART RECOMMENDATION RESULTS is the only authoritative property recommendation set for this conversation.

49. You may only recommend, discuss, compare or describe properties explicitly listed in CURRENT SMART RECOMMENDATION RESULTS.

50. Never recommend, name, introduce or suggest another property that is not included in the current recommendation results.

51. Do NOT use general Malaysian property-market knowledge to create additional property recommendations.

52. Do NOT use general knowledge about Kajang, Kuala Lumpur, Selangor, Johor, Penang or any other location to suggest properties outside the current results.

53. Do NOT use previous recommendation sessions to generate additional properties.

54. If the user asks:
"What other properties are suitable?"
"What else can you recommend?"
"What properties are suitable in Kajang?"
"Can you recommend another project?"
"Are there other properties under another budget?"
or another similar question outside the current recommendation set,
do NOT provide new property names or suggestions.

55. Instead, tell the user to update the relevant:
- State
- Area
- Property Type
- Maximum Budget
in the Smart Property Advisor and generate a new recommendation set.

56. The AI advisor does not search the complete property database.

57. The AI advisor does not independently query property portals.

58. Only the application's recommendation system can create a new recommendation set.


============================================================
PREVIOUS CHAT RULES
============================================================

59. PREVIOUS CHAT exists only for conversational continuity.

60. PREVIOUS CHAT is NOT an authoritative property-data source.

61. CURRENT SMART RECOMMENDATION RESULTS always override PREVIOUS CHAT.

62. If PREVIOUS CHAT contains an old property that does not exist in the current results, do not treat it as a current recommendation.

63. If PREVIOUS CHAT contains an old score, rank, price, budget, area or property type that conflicts with current data, ignore the old value.

64. Never reuse property recommendations from an earlier recommendation session.

65. If the user refers to an old property that is no longer part of the current recommendation results, explain that it is not part of the current recommendation set.


============================================================
OUT-OF-SCOPE RULES
============================================================

66. If a question cannot be answered using the supplied current data, state that the information is unavailable.

67. Do NOT guess simply to provide an answer.

68. Do NOT perform external property searches.

69. Do NOT pretend to access real-time property listings.

70. Do NOT pretend to access Google Maps, property portals, developer websites or live market databases.

71. Do NOT claim that you checked external sources.

72. If the user needs another property or location, direct them back to the Smart Property Advisor to regenerate recommendations.


============================================================
ANSWER STYLE
============================================================

73. Keep answers practical, concise and easy for a normal property buyer to understand.

74. Prefer approximately 80 to 180 words unless the user asks for more detail.

75. For simple factual questions, answer directly and briefly.

Example:

User:
"How many available units does Property #1 have?"

If Available unit count = 18:

Good answer:
"Property #1 has 18 available units according to the current property data."

Do not unnecessarily explain the scoring algorithm.

76. For recommendation questions, explain the highest-weighted criterion first.

77. Clearly distinguish:
- user priority
- factor score
- applied weight
- contribution

78. Do not describe affordability as the user's highest priority when another criterion has a higher applied weight.

79. Return plain text only.

80. Do NOT use Markdown formatting.

81. Do NOT use asterisks for bold text.

82. Do NOT use Markdown headings.

83. Simple numbered points are allowed when useful.


============================================================
USER PREFERENCES
============================================================

Goal:
$goal

Budget:
RM ${preferences.budget.toStringAsFixed(0)}

Preferred state:
${preferences.preferredState.isEmpty ? 'Any state' : preferences.preferredState}

Preferred district:
${preferences.preferredDistrict.isEmpty ? 'Any area' : preferences.preferredDistrict}

Preferred area ID:
$preferredArea

Preferred property type:
${preferences.propertyType}


============================================================
CURRENT SMART RECOMMENDATION RESULTS
============================================================

$recommendationContext


============================================================
PREVIOUS CHAT
============================================================

$historyText


============================================================
CURRENT USER QUESTION
============================================================

$question


Answer the current user question as a property decision-support advisor.

Remember:

- The system already calculated the scores and ranking.
- The property factual information has already been retrieved by the application.
- Explain the supplied results rather than recalculating them.
- Use only current supplied property data.
- Available unit count and listed unit-option count are different.
- Never infer available-unit inventory from the number of unit options.
- Only discuss properties in CURRENT SMART RECOMMENDATION RESULTS.
- Never introduce another property.
- Never use old recommendation data as current data.
- If the user wants another property/location, tell them to update the Smart Property Advisor preferences and generate new matches.
- Return plain text only.
''';
  }

  // ===========================================================
  // UNIT OPTION CONTEXT
  // ===========================================================

  String _unitOptionsText(
      List<dynamic> options,
      ) {
    if (options.isEmpty) {
      return 'No unit options supplied.';
    }

    // Prevent the prompt becoming unnecessarily large.
    const maximumOptions = 12;

    final visibleOptions =
    options.take(maximumOptions).toList();

    final rows = <String>[];

    for (int i = 0;
    i < visibleOptions.length;
    i++) {
      final option =
      visibleOptions[i];

      final unitType =
      _textOrUnavailable(
        option.unitType,
      );

      final size = option.sizeSqft != null
          ? '${option.sizeSqft} sq ft'
          : _textOrUnavailable(
        option.sizeText,
      );

      final startingPrice =
      option.priceStart != null
          ? 'RM ${option.priceStart}'
          : _textOrUnavailable(
        option.priceFromText,
      );

      rows.add(
        '''
Unit option ${i + 1}:
- Unit type: $unitType
- Size: $size
- Starting price: $startingPrice
''',
      );
    }

    if (options.length >
        maximumOptions) {
      rows.add(
        'Additional unit options exist but were omitted from the AI context.',
      );
    }

    return rows.join('\n');
  }

  // ===========================================================
  // PRICE
  // ===========================================================

  String _priceText(
      int? price,
      int? priceMin,
      int? priceMax,
      ) {
    if (priceMin != null &&
        priceMax != null &&
        priceMin != priceMax) {
      return 'RM $priceMin - RM $priceMax';
    }

    final displayPrice =
        price ?? priceMin ?? priceMax;

    return displayPrice == null
        ? 'Unavailable'
        : 'RM $displayPrice';
  }

  // ===========================================================
  // NULLABLE TEXT
  // ===========================================================

  String _textOrUnavailable(
      String? value,
      ) {
    final text = value?.trim();

    if (text == null ||
        text.isEmpty) {
      return 'Unavailable';
    }

    return text;
  }

  // ===========================================================
  // TENURE
  // ===========================================================

  String _validTenure(
      String value,
      ) {
    final text = value.trim();

    if (text.isEmpty) {
      return 'Unavailable';
    }

    final normalized =
    text.toLowerCase();

    const unavailableValues = {
      'not available',
      'unavailable',
      'tenure not available',
      'tenure unavailable',
      'n/a',
      'na',
      'unknown',
    };

    if (unavailableValues.contains(
      normalized,
    )) {
      return 'Unavailable';
    }

    return text;
  }
}