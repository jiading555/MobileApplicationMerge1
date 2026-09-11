import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/location_normalizer.dart';
import '../../core/utils/network_error_mapper.dart';
import '../../core/utils/responsive_layout.dart';
import '../../core/widgets/app_feedback.dart';
import '../../core/widgets/page_container.dart';
import '../../core/widgets/property_art.dart';
import '../../models/property.dart';
import '../../models/recommendation.dart';
import '../../models/user_preferences.dart';
import '../../services/recommendation_service.dart';
import '../../services/saved_recommendation_service.dart';
import '../search/property_detail_screen.dart';
import 'ai_advisor_chat_screen.dart';
import 'comparison_screen.dart';
import 'saved_recommendations_screen.dart';

List<Property> _advisorProperties(AppState state) {
  return state.properties.toList();
}

int? _advisorComparablePrice(Property property) {
  return property.price ?? property.priceMin ?? property.priceMax;
}

String? _advisorDisplayState(Property property) {
  return LocationNormalizer.nullableDisplayStateName(property.state);
}

String? _advisorDisplayDistrict(Property property) {
  return LocationNormalizer.nullableDisplayDistrictName(property.district);
}

String _advisorLocalityAreaId(Property property) {
  final displayState = _advisorDisplayState(property);
  final displayDistrict = _advisorDisplayDistrict(property);

  if (displayState == null || displayDistrict == null) {
    return '';
  }

  return LocationNormalizer.canonicalAreaId(displayState, displayDistrict);
}

List<String> _advisorStateOptions(Iterable<Property> properties) {
  final states =
      properties
          .map(_advisorDisplayState)
          .whereType<String>()
          .where((value) => value.isNotEmpty)
          .toSet()
          .toList()
        ..sort();

  return states;
}

List<Property> _advisorPropertiesForPreferences(
  Iterable<Property> properties,
  UserPreferences preferences,
) {
  return properties.where((property) {
    final displayState = _advisorDisplayState(property);
    final displayDistrict = _advisorDisplayDistrict(property);

    if (preferences.preferredState.isNotEmpty) {
      if (displayState == null ||
          !LocationNormalizer.stateMatches(
            displayState,
            preferences.preferredState,
          )) {
        return false;
      }
    }

    if (preferences.preferredDistrict.isNotEmpty) {
      if (displayDistrict == null ||
          !LocationNormalizer.districtMatches(
            displayDistrict,
            preferences.preferredDistrict,
            state: displayState,
          )) {
        return false;
      }
    }

    return true;
  }).toList();
}

List<_AdvisorAreaOption> _advisorAreaOptions(
  Iterable<Property> properties,
  String selectedState,
) {
  if (selectedState == 'any') {
    return const [];
  }

  final labelsById = <String, String>{};

  for (final property in properties) {
    final displayState = _advisorDisplayState(property);
    final displayDistrict = _advisorDisplayDistrict(property);
    final localityAreaId = _advisorLocalityAreaId(property);

    if (displayState == null ||
        displayDistrict == null ||
        localityAreaId.isEmpty ||
        !LocationNormalizer.stateMatches(displayState, selectedState)) {
      continue;
    }

    labelsById.putIfAbsent(localityAreaId, () => displayDistrict);
  }

  final options =
      labelsById.entries
          .map(
            (entry) => _AdvisorAreaOption(value: entry.key, label: entry.value),
          )
          .toList()
        ..sort((left, right) => left.label.compareTo(right.label));

  return options;
}

class _AdvisorAreaOption {
  const _AdvisorAreaOption({required this.value, required this.label});

  final String value;
  final String label;
}

class AdvisorScreen extends StatefulWidget {
  const AdvisorScreen({super.key});

  @override
  State<AdvisorScreen> createState() => _AdvisorScreenState();
}

class _AdvisorScreenState extends State<AdvisorScreen> {
  bool seeded = false;
  bool showResults = false;
  bool scoringLocked = false;

  late PropertyGoal goal;
  late double budget;
  late String selectedState;
  late String areaId;
  late String propertyType;

  late double ownStaySafetyPriority;
  late double ownStayEducationPriority;
  late double ownStayTransportPriority;

  late double investmentIncomePriority;
  late double investmentTransportPriority;
  late double investmentAffordabilityPriority;

  List<double> appliedWeights = [];
  List<Property> _cachedAdvisorProperties = const [];

  final Set<String> selectedComparisonIds = {};

  final SavedRecommendationService _savedRecommendationService =
      const SavedRecommendationService();

  bool _isSavingRecommendation = false;
  bool _recommendationSaved = false;

  final PageController _recommendationPageController = PageController(
    viewportFraction: 0.90,
  );

  int _recommendationPageIndex = 0;

  @override
  void dispose() {
    _recommendationPageController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!seeded) {
      final appState = AppScope.of(context);
      final preferences = appState.preferences;
      _cachedAdvisorProperties = _advisorProperties(appState);

      goal = preferences.goal;

      final savedMaximumBudget = preferences.maximumBudget > 0
          ? preferences.maximumBudget
          : preferences.budget;

      budget = savedMaximumBudget.clamp(350000.0, 1600000.0).toDouble();

      final availableStates = _advisorStateOptions(_cachedAdvisorProperties);
      final savedState = LocationNormalizer.nullableDisplayStateName(
        preferences.preferredState,
      );

      selectedState = savedState != null && availableStates.contains(savedState)
          ? savedState
          : 'any';

      areaId = 'any';
      propertyType = 'Any';

      if (selectedState != 'any' &&
          preferences.preferredDistrict.trim().isNotEmpty) {
        final areaOptions = _advisorAreaOptions(
          _cachedAdvisorProperties,
          selectedState,
        );

        final savedAreaId = LocationNormalizer.canonicalAreaId(
          selectedState,
          preferences.preferredDistrict.trim(),
        );

        if (areaOptions.any((option) => option.value == savedAreaId)) {
          areaId = savedAreaId;
        }
      }

      if (areaId == 'any' &&
          selectedState != 'any' &&
          preferences.preferredAreaId != 'any') {
        for (final area in appState.areas) {
          if (!LocationNormalizer.areaIdMatches(
            area.id,
            preferences.preferredAreaId,
          )) {
            continue;
          }

          final legacyAreaId = LocationNormalizer.canonicalAreaId(
            selectedState,
            area.name,
          );

          final areaOptions = _advisorAreaOptions(
            _cachedAdvisorProperties,
            selectedState,
          );

          if (areaOptions.any((option) => option.value == legacyAreaId)) {
            areaId = legacyAreaId;
          }

          break;
        }
      }

      final initialAvailableTypes = _availablePropertyTypes(
        state: appState,
        targetBudget: budget,
        targetState: selectedState,
        targetAreaId: areaId,
      );

      if (preferences.propertyType == 'Any' ||
          initialAvailableTypes.contains(preferences.propertyType)) {
        propertyType = preferences.propertyType;
      }

      ownStaySafetyPriority = preferences.ownStaySafetyPriority;
      ownStayEducationPriority = preferences.ownStayEducationPriority;
      ownStayTransportPriority = preferences.ownStayTransportPriority;

      investmentIncomePriority = preferences.investmentIncomePriority;
      investmentTransportPriority = preferences.investmentTransportPriority;
      investmentAffordabilityPriority =
          preferences.investmentAffordabilityPriority;

      showResults = false;
      scoringLocked = false;
      appliedWeights = [];
      selectedComparisonIds.clear();

      seeded = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final compactLandscape = ResponsiveLayout.isCompactLandscapePhone(context);

    final recommendations = showResults
        ? const RecommendationService().rank(
            properties: _advisorPropertiesForPreferences(
              _cachedAdvisorProperties,
              state.preferences,
            ),
            areas: state.areas,
            preferences: state.preferences,
          )
        : const <PropertyRecommendation>[];

    final visibleRecommendations = recommendations.take(3).toList();

    final selectedRecommendations = visibleRecommendations
        .where((item) => selectedComparisonIds.contains(item.property.id))
        .toList();

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: compactLandscape ? 44 : null,
        title: const FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text('Smart property advisor'),
        ),
        actions: [
          IconButton(
            tooltip: 'Saved Recommendations',
            icon: const Icon(Icons.bookmarks_outlined),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const SavedRecommendationsScreen(),
                ),
              );
            },
          ),
          IconButton(
            onPressed: () => _showMethod(context),
            tooltip: 'How scoring works',
            icon: const Icon(Icons.info_outline_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.only(bottom: compactLandscape ? 24 : 0),
        child: PageContainer(
          maxWidth: 1100,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _AdvisorIntro(goal: goal),

              const SizedBox(height: 22),

              _PreferencePanel(
                goal: goal,
                budget: budget,
                selectedState: selectedState,
                areaId: areaId,
                propertyType: propertyType,
                advisorProperties: _cachedAdvisorProperties,

                scoringLocked: scoringLocked,

                appliedWeights: appliedWeights,

                ownStaySafetyPriority: ownStaySafetyPriority,

                ownStayEducationPriority: ownStayEducationPriority,

                ownStayTransportPriority: ownStayTransportPriority,

                investmentIncomePriority: investmentIncomePriority,

                investmentTransportPriority: investmentTransportPriority,

                investmentAffordabilityPriority:
                    investmentAffordabilityPriority,

                onGoalChanged: _changeGoal,

                onBudgetChanged: (value) {
                  final appState = AppScope.of(context);

                  setState(() {
                    budget = value;

                    final availableTypes = _availablePropertyTypes(
                      state: appState,
                      targetBudget: value,
                      targetState: selectedState,
                      targetAreaId: areaId,
                    );

                    if (propertyType != 'Any' &&
                        !availableTypes.contains(propertyType)) {
                      propertyType = 'Any';
                    }

                    _resetScoringAfterPreferenceChange();
                  });
                },

                onStateChanged: (value) {
                  final appState = AppScope.of(context);

                  setState(() {
                    selectedState = value;
                    areaId = 'any';

                    final availableTypes = _availablePropertyTypes(
                      state: appState,
                      targetBudget: budget,
                      targetState: selectedState,
                      targetAreaId: areaId,
                    );

                    if (propertyType != 'Any' &&
                        !availableTypes.contains(propertyType)) {
                      propertyType = 'Any';
                    }

                    _resetScoringAfterPreferenceChange();
                  });
                },

                onAreaChanged: (value) {
                  final appState = AppScope.of(context);

                  setState(() {
                    areaId = value;

                    final availableTypes = _availablePropertyTypes(
                      state: appState,
                      targetBudget: budget,
                      targetState: selectedState,
                      targetAreaId: areaId,
                    );

                    if (propertyType != 'Any' &&
                        !availableTypes.contains(propertyType)) {
                      propertyType = 'Any';
                    }

                    _resetScoringAfterPreferenceChange();
                  });
                },

                onTypeChanged: (value) {
                  setState(() {
                    propertyType = value;

                    _resetScoringAfterPreferenceChange();
                  });
                },

                onOwnStaySafetyChanged: (value) {
                  if (!scoringLocked) ownStaySafetyPriority = value;
                },

                onOwnStayEducationChanged: (value) {
                  if (!scoringLocked) ownStayEducationPriority = value;
                },

                onOwnStayTransportChanged: (value) {
                  if (!scoringLocked) ownStayTransportPriority = value;
                },

                onInvestmentIncomeChanged: (value) {
                  if (!scoringLocked) investmentIncomePriority = value;
                },

                onInvestmentTransportChanged: (value) {
                  if (!scoringLocked) investmentTransportPriority = value;
                },

                onInvestmentAffordabilityChanged: (value) {
                  if (!scoringLocked) investmentAffordabilityPriority = value;
                },

                onResetWeights: _resetPriorities,

                onGenerate: _generate,
              ),

              if (showResults) ...[
                const SizedBox(height: 30),

                Text(
                  'Top matches from your preferences',
                  style: Theme.of(context).textTheme.titleLarge,
                ),

                const SizedBox(height: 4),

                Text(
                  '${recommendations.length} matches ranked with a transparent weighted score',
                  style: const TextStyle(color: AppTheme.muted),
                ),

                const SizedBox(height: 16),

                if (recommendations.isEmpty)
                  const _NoMatches()
                else ...[
                  _RecommendationActionBar(
                    recommendationCount: visibleRecommendations.length,
                    selectedCount: selectedComparisonIds.length,
                    isSaving: _isSavingRecommendation,
                    isSaved: _recommendationSaved,
                    canCompare:
                        selectedRecommendations.length >= 2 &&
                        selectedRecommendations.length <= 3,
                    onSave: () => _saveCurrentRecommendationSession(
                      recommendations: visibleRecommendations,
                      preferences: state.preferences,
                    ),
                    onCompare: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => ComparisonScreen(
                            recommendations: selectedRecommendations,
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 14),

                  const Row(
                    children: [
                      Icon(Icons.swipe_rounded, size: 18, color: AppTheme.blue),
                      SizedBox(width: 7),
                      Text(
                        'Swipe to view your Top 3 matches',
                        style: TextStyle(color: AppTheme.muted, fontSize: 12),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  SizedBox(
                    height: 510,
                    child: PageView.builder(
                      controller: _recommendationPageController,
                      padEnds: false,
                      itemCount: visibleRecommendations.length,
                      onPageChanged: (index) {
                        setState(() {
                          _recommendationPageIndex = index;
                        });
                      },
                      itemBuilder: (context, index) {
                        final item = visibleRecommendations[index];

                        return Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: _RecommendationSwipeCard(
                            recommendation: item,
                            rank: index + 1,
                            selected: selectedComparisonIds.contains(
                              item.property.id,
                            ),
                            onComparisonChanged: () {
                              _toggleComparison(item);
                            },
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 10),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(visibleRecommendations.length, (
                      index,
                    ) {
                      final active = index == _recommendationPageIndex;

                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: active ? 20 : 7,
                        height: 7,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          color: active
                              ? AppTheme.blue
                              : AppTheme.muted.withValues(alpha: 0.30),
                          borderRadius: BorderRadius.circular(20),
                        ),
                      );
                    }),
                  ),

                  const SizedBox(height: 16),

                  const SizedBox(height: 14),

                  _AiAdvisorEntryCard(
                    recommendationCount: visibleRecommendations.length,
                    onOpen: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => AiAdvisorChatScreen(
                            recommendations: visibleRecommendations,
                            preferences: state.preferences,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _changeGoal(PropertyGoal value) {
    setState(() {
      goal = value;

      scoringLocked = false;
      appliedWeights = [];
      selectedComparisonIds.clear();
      _recommendationSaved = false;

      showResults = false;

      if (value == PropertyGoal.investment) {
        investmentIncomePriority = 20;
        investmentTransportPriority = 15;
        investmentAffordabilityPriority = 15;
      }

      if (value == PropertyGoal.ownStay) {
        ownStaySafetyPriority = 30;
        ownStayEducationPriority = 25;
        ownStayTransportPriority = 20;
      }
    });
  }

  void _resetScoringAfterPreferenceChange() {
    if (goal == PropertyGoal.ownStay) {
      ownStaySafetyPriority = 30;
      ownStayEducationPriority = 25;
      ownStayTransportPriority = 20;
    } else {
      investmentIncomePriority = 20;
      investmentTransportPriority = 15;
      investmentAffordabilityPriority = 15;
    }

    appliedWeights = [];
    scoringLocked = false;
    selectedComparisonIds.clear();
    _recommendationSaved = false;
    showResults = false;
  }

  bool _areaHasPropertyWithinBudget({
    required AppState state,
    required String targetAreaId,
    required double targetBudget,
  }) {
    return _cachedAdvisorProperties.any((property) {
      final price = _advisorComparablePrice(property);

      if (price == null || price > targetBudget) {
        return false;
      }

      return _advisorLocalityAreaId(property) == targetAreaId;
    });
  }

  List<String> _availablePropertyTypes({
    required AppState state,
    required double targetBudget,
    required String targetState,
    required String targetAreaId,
  }) {
    final types =
        _cachedAdvisorProperties
            .where((property) {
              final price = _advisorComparablePrice(property);

              if (price == null || price > targetBudget) {
                return false;
              }

              final displayState = _advisorDisplayState(property);
              final localityAreaId = _advisorLocalityAreaId(property);

              if (targetAreaId != 'any') {
                return localityAreaId == targetAreaId;
              }

              if (targetState != 'any') {
                return displayState != null &&
                    LocationNormalizer.stateMatches(displayState, targetState);
              }

              return true;
            })
            .expand((property) => property.normalizedPropertyTypes)
            .toSet()
            .toList()
          ..sort();

    return types;
  }

  void _generate() {
    final state = AppScope.of(context);

    if (areaId != 'any' &&
        !_areaHasPropertyWithinBudget(
          state: state,
          targetAreaId: areaId,
          targetBudget: budget,
        )) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No property is available in the selected area within this budget.',
          ),
        ),
      );
      return;
    }

    final availableTypes = _availablePropertyTypes(
      state: state,
      targetBudget: budget,
      targetState: selectedState,
      targetAreaId: areaId,
    );

    final effectivePropertyType =
        propertyType == 'Any' || availableTypes.contains(propertyType)
        ? propertyType
        : 'Any';

    final effectiveAreaId = areaId;

    final priorities = goal == PropertyGoal.ownStay
        ? [
            ownStaySafetyPriority,
            ownStayEducationPriority,
            ownStayTransportPriority,
          ]
        : [
            investmentIncomePriority,
            investmentTransportPriority,
            investmentAffordabilityPriority,
          ];

    final totalPriority = priorities.fold<double>(
      0,
      (sum, value) => sum + value,
    );

    if (totalPriority <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please set at least one scoring priority.'),
        ),
      );

      return;
    }

    final normalisedWeights = _normalisePriorities(priorities);

    String currentDistrict = '';

    if (effectiveAreaId != 'any' && selectedState != 'any') {
      final areaOptions = _advisorAreaOptions(
        _cachedAdvisorProperties,
        selectedState,
      );

      for (final option in areaOptions) {
        if (option.value == effectiveAreaId) {
          currentDistrict = option.label;
          break;
        }
      }
    }

    state.updatePreferences(
      state.preferences.copyWith(
        goal: goal,
        budget: budget,
        preferredAreaId: 'any',
        propertyType: effectivePropertyType,

        preferredState: selectedState == 'any' ? '' : selectedState,
        preferredDistrict: currentDistrict,

        ownStaySafetyPriority: ownStaySafetyPriority,

        ownStayEducationPriority: ownStayEducationPriority,

        ownStayTransportPriority: ownStayTransportPriority,

        investmentIncomePriority: investmentIncomePriority,

        investmentTransportPriority: investmentTransportPriority,

        investmentAffordabilityPriority: investmentAffordabilityPriority,
      ),
    );

    setState(() {
      areaId = effectiveAreaId;
      propertyType = effectivePropertyType;
      appliedWeights = normalisedWeights;
      scoringLocked = true;
      selectedComparisonIds.clear();
      _recommendationSaved = false;
      showResults = true;
      _recommendationPageIndex = 0;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      if (_recommendationPageController.hasClients) {
        _recommendationPageController.jumpToPage(0);
      }
    });
  }

  List<double> _normalisePriorities(List<double> priorities) {
    final total = priorities.fold<double>(
      0,
      (sum, value) => sum + value.clamp(0, 100),
    );

    if (total <= 0) {
      final equal = 1.0 / priorities.length;

      return List<double>.filled(priorities.length, equal);
    }

    return priorities.map((value) => value.clamp(0, 100) / total).toList();
  }

  void _resetPriorities() {
    setState(() {
      if (goal == PropertyGoal.ownStay) {
        ownStaySafetyPriority = 30;
        ownStayEducationPriority = 25;
        ownStayTransportPriority = 20;
      } else {
        investmentIncomePriority = 20;
        investmentTransportPriority = 15;
        investmentAffordabilityPriority = 15;
      }

      appliedWeights = [];
      scoringLocked = false;
      selectedComparisonIds.clear();
      _recommendationSaved = false;
      showResults = false;
    });
  }

  Future<void> _saveCurrentRecommendationSession({
    required List<PropertyRecommendation> recommendations,
    required UserPreferences preferences,
  }) async {
    if (_isSavingRecommendation ||
        _recommendationSaved ||
        recommendations.isEmpty) {
      return;
    }

    setState(() {
      _isSavingRecommendation = true;
    });

    try {
      await _savedRecommendationService.saveRecommendationSession(
        recommendations: recommendations,
        preferences: preferences,
        appliedWeights: appliedWeights,
      );

      if (!mounted) return;

      setState(() {
        _recommendationSaved = true;
      });

      showAppSnackBar(
        context,
        message: 'Recommendation session saved successfully.',
        type: AppFeedbackType.success,
      );
    } catch (error) {
      if (!mounted) return;

      final message = NetworkErrorMapper.cleanMessage(
        error,
        fallback: 'Could not save the recommendation session.',
      );

      showAppSnackBar(context, message: message, type: AppFeedbackType.error);
    } finally {
      if (mounted) {
        setState(() {
          _isSavingRecommendation = false;
        });
      }
    }
  }

  void _toggleComparison(PropertyRecommendation recommendation) {
    final id = recommendation.property.id;

    setState(() {
      if (selectedComparisonIds.contains(id)) {
        selectedComparisonIds.remove(id);
        return;
      }

      if (selectedComparisonIds.length >= 3) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You can compare a maximum of 3 properties.'),
          ),
        );

        return;
      }

      selectedComparisonIds.add(id);
    });
  }

  void _showMethod(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        return FractionallySizedBox(
          heightFactor: 0.90,
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Transparent recommendation method',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),

                  const SizedBox(height: 8),

                  const Text(
                    'The system uses property data and area-level government '
                    'data to calculate a weighted recommendation score.',
                    style: TextStyle(
                      color: AppTheme.muted,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),

                  const SizedBox(height: 22),

                  const _MethodSectionTitle(
                    icon: Icons.home_rounded,
                    title: 'Own Stay',
                  ),

                  const SizedBox(height: 12),

                  const _MethodDataItem(
                    icon: Icons.shield_outlined,
                    title: 'Safety',
                    dataUsed: 'District crime statistics',
                    explanation:
                        'Crime data is converted into the area safety score '
                        'before recommendation scoring. A lower crime level '
                        'represents a stronger safety result.',
                  ),

                  const _MethodDataItem(
                    icon: Icons.school_outlined,
                    title: 'Education facilities',
                    dataUsed: 'Number of schools / education institutions',
                    explanation:
                        'The number of education facilities in the matched '
                        'area is compared with other available areas and '
                        'normalised into a 0–100 education score.',
                  ),

                  const _MethodDataItem(
                    icon: Icons.directions_transit_outlined,
                    title: 'Transportation',
                    dataUsed: 'Area transportation accessibility data',
                    explanation:
                        'The recommendation uses the transport score from the '
                        'matched area profile. A higher score represents '
                        'stronger transportation accessibility.',
                  ),

                  const SizedBox(height: 18),

                  const _MethodSectionTitle(
                    icon: Icons.trending_up_rounded,
                    title: 'Investment',
                  ),

                  const SizedBox(height: 12),

                  const _MethodDataItem(
                    icon: Icons.payments_outlined,
                    title: 'Income / Economic indicator',
                    dataUsed: 'Median household income',
                    explanation:
                        'Median household income is compared with other '
                        'available areas and normalised into a 0–100 '
                        'economic indicator score.',
                  ),

                  const _MethodDataItem(
                    icon: Icons.directions_transit_outlined,
                    title: 'Transportation',
                    dataUsed: 'Area transportation accessibility data',
                    explanation:
                        'The same matched-area transportation score is used '
                        'to represent accessibility for investment analysis.',
                  ),

                  const _MethodDataItem(
                    icon: Icons.account_balance_wallet_outlined,
                    title: 'Property affordability',
                    dataUsed: 'Property price + selected maximum budget',
                    explanation:
                        'The property price is compared with the user\'s '
                        'selected maximum budget. A property that uses a '
                        'smaller portion of the budget receives a higher '
                        'affordability score.',
                  ),

                  const SizedBox(height: 18),

                  const Divider(),

                  const SizedBox(height: 14),

                  const Text(
                    'How the weighted score works',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                  ),

                  const SizedBox(height: 9),

                  const _MethodStep(
                    number: '1',
                    text:
                        'The user adjusts the three priority sliders for the '
                        'selected goal.',
                  ),

                  const _MethodStep(
                    number: '2',
                    text:
                        'When Generate Matches is pressed, the priority values '
                        'are normalised into percentages that total 100%.',
                  ),

                  const _MethodStep(
                    number: '3',
                    text:
                        'Each available data score is multiplied by its '
                        'applied weight and the contributions are combined '
                        'into the final recommendation score.',
                  ),

                  const SizedBox(height: 10),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: AppTheme.blue.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          color: AppTheme.blue,
                          size: 19,
                        ),
                        SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            'Safety uses the processed area safety score in '
                            'the recommendation algorithm; the underlying '
                            'source is district-level crime data.',
                            style: TextStyle(
                              color: AppTheme.muted,
                              fontSize: 10,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: AppTheme.green.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.psychology_alt_outlined,
                          color: AppTheme.green,
                          size: 19,
                        ),
                        SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            'AI does not calculate, change or reorder the '
                            'scores. It only explains the recommendation '
                            'results already produced by the scoring system.',
                            style: TextStyle(
                              color: AppTheme.muted,
                              fontSize: 10,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MethodSectionTitle extends StatelessWidget {
  const _MethodSectionTitle({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 19, color: AppTheme.blue),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
        ),
      ],
    );
  }
}

class _MethodDataItem extends StatelessWidget {
  const _MethodDataItem({
    required this.icon,
    required this.title,
    required this.dataUsed,
    required this.explanation,
  });

  final IconData icon;
  final String title;
  final String dataUsed;
  final String explanation;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.blue.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.blue.withValues(alpha: 0.10)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.blue.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 19, color: AppTheme.blue),
          ),

          const SizedBox(width: 11),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),

                const SizedBox(height: 3),

                Text(
                  'Data used: $dataUsed',
                  style: const TextStyle(
                    color: AppTheme.blue,
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  explanation,
                  style: const TextStyle(
                    color: AppTheme.muted,
                    fontSize: 10,
                    height: 1.4,
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

class _MethodStep extends StatelessWidget {
  const _MethodStep({required this.number, required this.text});

  final String number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppTheme.blue.withValues(alpha: 0.09),
              shape: BoxShape.circle,
            ),
            child: Text(
              number,
              style: const TextStyle(
                color: AppTheme.blue,
                fontWeight: FontWeight.w900,
                fontSize: 10,
              ),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                text,
                style: const TextStyle(
                  color: AppTheme.muted,
                  fontSize: 10,
                  height: 1.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdvisorIntro extends StatelessWidget {
  const _AdvisorIntro({required this.goal});

  final PropertyGoal goal;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.navy, AppTheme.blue, AppTheme.teal],
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: AppTheme.blue,
              size: 30,
            ),
          ),

          const SizedBox(width: 17),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  goal == PropertyGoal.ownStay
                      ? 'Find a home that fits your life'
                      : 'Explore investment potential',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 5),

                const Text(
                  'Set your goal and adjust what matters most to you.',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PreferencePanel extends StatelessWidget {
  const _PreferencePanel({
    required this.goal,
    required this.budget,
    required this.selectedState,
    required this.areaId,
    required this.propertyType,
    required this.advisorProperties,

    required this.scoringLocked,
    required this.appliedWeights,

    required this.ownStaySafetyPriority,
    required this.ownStayEducationPriority,
    required this.ownStayTransportPriority,

    required this.investmentIncomePriority,
    required this.investmentTransportPriority,
    required this.investmentAffordabilityPriority,

    required this.onGoalChanged,
    required this.onBudgetChanged,
    required this.onStateChanged,
    required this.onAreaChanged,
    required this.onTypeChanged,

    required this.onOwnStaySafetyChanged,
    required this.onOwnStayEducationChanged,
    required this.onOwnStayTransportChanged,

    required this.onInvestmentIncomeChanged,
    required this.onInvestmentTransportChanged,
    required this.onInvestmentAffordabilityChanged,

    required this.onResetWeights,
    required this.onGenerate,
  });

  final PropertyGoal goal;
  final double budget;
  final String selectedState;
  final String areaId;
  final String propertyType;
  final List<Property> advisorProperties;

  final bool scoringLocked;
  final List<double> appliedWeights;

  final double ownStaySafetyPriority;
  final double ownStayEducationPriority;
  final double ownStayTransportPriority;

  final double investmentIncomePriority;
  final double investmentTransportPriority;
  final double investmentAffordabilityPriority;

  final ValueChanged<PropertyGoal> onGoalChanged;

  final ValueChanged<double> onBudgetChanged;

  final ValueChanged<String> onStateChanged;

  final ValueChanged<String> onAreaChanged;

  final ValueChanged<String> onTypeChanged;

  final ValueChanged<double> onOwnStaySafetyChanged;

  final ValueChanged<double> onOwnStayEducationChanged;

  final ValueChanged<double> onOwnStayTransportChanged;

  final ValueChanged<double> onInvestmentIncomeChanged;

  final ValueChanged<double> onInvestmentTransportChanged;

  final ValueChanged<double> onInvestmentAffordabilityChanged;

  final VoidCallback onResetWeights;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    final availableStates = _advisorStateOptions(advisorProperties);

    final effectiveSelectedState =
        selectedState == 'any' || availableStates.contains(selectedState)
        ? selectedState
        : 'any';

    final availableAreas = _advisorAreaOptions(
      advisorProperties,
      effectiveSelectedState,
    );

    final availableAreaIds = availableAreas
        .map((option) => option.value)
        .toSet();

    final effectiveAreaId = areaId != 'any' && availableAreaIds.contains(areaId)
        ? areaId
        : 'any';

    final availablePropertyTypes =
        advisorProperties
            .where((property) {
              final price = _advisorComparablePrice(property);

              if (price == null || price > budget) {
                return false;
              }

              final displayState = _advisorDisplayState(property);
              final localityAreaId = _advisorLocalityAreaId(property);

              if (effectiveAreaId != 'any') {
                return localityAreaId == effectiveAreaId;
              }

              if (effectiveSelectedState != 'any') {
                return displayState != null &&
                    LocationNormalizer.stateMatches(
                      displayState,
                      effectiveSelectedState,
                    );
              }

              return true;
            })
            .expand((property) => property.normalizedPropertyTypes)
            .toSet()
            .toList()
          ..sort();

    final effectivePropertyType =
        propertyType == 'Any' || availablePropertyTypes.contains(propertyType)
        ? propertyType
        : 'Any';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your property goal',
              style: Theme.of(context).textTheme.titleMedium,
            ),

            const SizedBox(height: 11),

            SegmentedButton<PropertyGoal>(
              segments: const [
                ButtonSegment(
                  value: PropertyGoal.ownStay,
                  icon: Icon(Icons.home_rounded),
                  label: Text('Own stay'),
                ),
                ButtonSegment(
                  value: PropertyGoal.investment,
                  icon: Icon(Icons.trending_up_rounded),
                  label: Text('Investment'),
                ),
              ],
              selected: {goal},
              onSelectionChanged: (values) {
                onGoalChanged(values.first);
              },
            ),

            const SizedBox(height: 24),

            _AdvisorBudgetControl(value: budget, onChangeEnd: onBudgetChanged),

            const SizedBox(height: 10),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    key: ValueKey(
                      'state-$effectiveSelectedState-${budget.round()}',
                    ),
                    initialValue: effectiveSelectedState,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'State'),
                    items: [
                      const DropdownMenuItem(
                        value: 'any',
                        child: Text(
                          'Any state',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      ...availableStates.map(
                        (stateName) => DropdownMenuItem(
                          value: stateName,
                          child: Text(
                            stateName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      onStateChanged(value ?? 'any');
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    key: ValueKey(
                      'area-$effectiveAreaId-$effectiveSelectedState-${budget.round()}',
                    ),
                    initialValue: effectiveAreaId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Area'),
                    items: [
                      DropdownMenuItem(
                        value: 'any',
                        child: Text(
                          effectiveSelectedState == 'any'
                              ? 'Select state first'
                              : 'Any area',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      ...availableAreas.map(
                        (item) => DropdownMenuItem<String>(
                          value: item.value,
                          child: Text(
                            item.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                    onChanged: effectiveSelectedState == 'any'
                        ? null
                        : (value) {
                            onAreaChanged(value ?? 'any');
                          },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            DropdownButtonFormField<String>(
              key: ValueKey(
                'type-$effectivePropertyType-$effectiveAreaId-'
                '$effectiveSelectedState-${budget.round()}',
              ),
              initialValue: effectivePropertyType,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Property type'),
              items: [
                const DropdownMenuItem(
                  value: 'Any',
                  child: Text(
                    'Any property type',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                ...availablePropertyTypes.map(
                  (item) => DropdownMenuItem<String>(
                    value: item,
                    child: Text(
                      item,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
              onChanged: availablePropertyTypes.isEmpty
                  ? null
                  : (value) {
                      onTypeChanged(value ?? 'Any');
                    },
            ),

            const SizedBox(height: 24),

            Text(
              'Scoring priorities',
              style: Theme.of(context).textTheme.titleMedium,
            ),

            const SizedBox(height: 6),

            Text(
              scoringLocked
                  ? 'These percentages are the applied weights used for the current recommendation. Press Reset to default to adjust the priorities again.'
                  : 'Move each slider independently from low to high importance. Percentages are calculated after Generate matches.',
              style: const TextStyle(color: AppTheme.muted, fontSize: 12),
            ),

            const SizedBox(height: 14),

            _PrioritySliders(
              goal: goal,

              scoringLocked: scoringLocked,

              appliedWeights: appliedWeights,

              ownStaySafetyPriority: ownStaySafetyPriority,

              ownStayEducationPriority: ownStayEducationPriority,

              ownStayTransportPriority: ownStayTransportPriority,

              investmentIncomePriority: investmentIncomePriority,

              investmentTransportPriority: investmentTransportPriority,

              investmentAffordabilityPriority: investmentAffordabilityPriority,

              onOwnStaySafetyChanged: onOwnStaySafetyChanged,

              onOwnStayEducationChanged: onOwnStayEducationChanged,

              onOwnStayTransportChanged: onOwnStayTransportChanged,

              onInvestmentIncomeChanged: onInvestmentIncomeChanged,

              onInvestmentTransportChanged: onInvestmentTransportChanged,

              onInvestmentAffordabilityChanged:
                  onInvestmentAffordabilityChanged,

              onResetWeights: onResetWeights,
            ),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: scoringLocked ? null : onGenerate,

                icon: Icon(
                  scoringLocked
                      ? Icons.lock_outline_rounded
                      : Icons.auto_awesome_rounded,
                ),

                label: Text(
                  scoringLocked ? 'Scoring applied' : 'Generate matches',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdvisorBudgetControl extends StatefulWidget {
  const _AdvisorBudgetControl({required this.value, required this.onChangeEnd});

  final double value;
  final ValueChanged<double> onChangeEnd;

  @override
  State<_AdvisorBudgetControl> createState() => _AdvisorBudgetControlState();
}

class _AdvisorBudgetControlState extends State<_AdvisorBudgetControl> {
  late double _draftValue;

  @override
  void initState() {
    super.initState();
    _draftValue = widget.value;
  }

  @override
  void didUpdateWidget(covariant _AdvisorBudgetControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _draftValue = widget.value;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Text(
              'Maximum budget',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Spacer(),
            Text(
              formatRinggit(_draftValue),
              style: const TextStyle(
                color: AppTheme.blue,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        Slider(
          min: 350000,
          max: 1600000,
          divisions: 25,
          value: _draftValue,
          onChanged: (value) {
            setState(() => _draftValue = value);
            widget.onChangeEnd(value);
          },
        ),
      ],
    );
  }
}

class _PrioritySliders extends StatelessWidget {
  const _PrioritySliders({
    required this.goal,
    required this.scoringLocked,
    required this.appliedWeights,

    required this.ownStaySafetyPriority,
    required this.ownStayEducationPriority,
    required this.ownStayTransportPriority,

    required this.investmentIncomePriority,
    required this.investmentTransportPriority,
    required this.investmentAffordabilityPriority,

    required this.onOwnStaySafetyChanged,
    required this.onOwnStayEducationChanged,
    required this.onOwnStayTransportChanged,

    required this.onInvestmentIncomeChanged,
    required this.onInvestmentTransportChanged,
    required this.onInvestmentAffordabilityChanged,

    required this.onResetWeights,
  });

  final PropertyGoal goal;

  final bool scoringLocked;
  final List<double> appliedWeights;

  final double ownStaySafetyPriority;
  final double ownStayEducationPriority;
  final double ownStayTransportPriority;

  final double investmentIncomePriority;
  final double investmentTransportPriority;
  final double investmentAffordabilityPriority;

  final ValueChanged<double> onOwnStaySafetyChanged;

  final ValueChanged<double> onOwnStayEducationChanged;

  final ValueChanged<double> onOwnStayTransportChanged;

  final ValueChanged<double> onInvestmentIncomeChanged;

  final ValueChanged<double> onInvestmentTransportChanged;

  final ValueChanged<double> onInvestmentAffordabilityChanged;

  final VoidCallback onResetWeights;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.blue.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.blue.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          if (goal == PropertyGoal.ownStay) ...[
            _PrioritySlider(
              label: 'Safety',
              value: ownStaySafetyPriority,
              appliedWeight: _weightAt(0),
              locked: scoringLocked,
              onChanged: onOwnStaySafetyChanged,
            ),

            _PrioritySlider(
              label: 'Education facilities',
              value: ownStayEducationPriority,
              appliedWeight: _weightAt(1),
              locked: scoringLocked,
              onChanged: onOwnStayEducationChanged,
            ),

            _PrioritySlider(
              label: 'Transportation',
              value: ownStayTransportPriority,
              appliedWeight: _weightAt(2),
              locked: scoringLocked,
              onChanged: onOwnStayTransportChanged,
            ),
          ] else ...[
            _PrioritySlider(
              label: 'Income / economic indicator',
              value: investmentIncomePriority,
              appliedWeight: _weightAt(0),
              locked: scoringLocked,
              onChanged: onInvestmentIncomeChanged,
            ),

            _PrioritySlider(
              label: 'Transportation',
              value: investmentTransportPriority,
              appliedWeight: _weightAt(1),
              locked: scoringLocked,
              onChanged: onInvestmentTransportChanged,
            ),

            _PrioritySlider(
              label: 'Property affordability',
              value: investmentAffordabilityPriority,
              appliedWeight: _weightAt(2),
              locked: scoringLocked,
              onChanged: onInvestmentAffordabilityChanged,
            ),
          ],

          if (scoringLocked && appliedWeights.length >= 3) ...[
            const Divider(),

            const Row(
              children: [
                Text(
                  'Total weight',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                Spacer(),
                Text(
                  '100.0%',
                  style: TextStyle(
                    color: AppTheme.green,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ],

          const Divider(),

          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onResetWeights,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reset to default'),
            ),
          ),
        ],
      ),
    );
  }

  double? _weightAt(int index) {
    if (!scoringLocked || appliedWeights.length <= index) {
      return null;
    }

    return appliedWeights[index];
  }
}

class _PrioritySlider extends StatefulWidget {
  const _PrioritySlider({
    required this.label,
    required this.value,
    required this.appliedWeight,
    required this.locked,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double? appliedWeight;
  final bool locked;
  final ValueChanged<double> onChanged;

  @override
  State<_PrioritySlider> createState() => _PrioritySliderState();
}

class _PrioritySliderState extends State<_PrioritySlider> {
  late double _draftValue;

  @override
  void initState() {
    super.initState();
    _draftValue = widget.value;
  }

  @override
  void didUpdateWidget(covariant _PrioritySlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value ||
        oldWidget.locked != widget.locked ||
        oldWidget.appliedWeight != widget.appliedWeight) {
      _draftValue = widget.value;
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayValue = widget.locked && widget.appliedWeight != null
        ? widget.appliedWeight! * 100
        : _draftValue;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.analytics_outlined,
                size: 18,
                color: AppTheme.blue,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (widget.locked && widget.appliedWeight != null)
                Text(
                  '${(widget.appliedWeight! * 100).toStringAsFixed(1)}%',
                  style: const TextStyle(
                    color: AppTheme.blue,
                    fontWeight: FontWeight.w800,
                  ),
                )
              else
                Text(
                  _draftValue.round().toString(),
                  style: const TextStyle(
                    color: AppTheme.blue,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 2),
          Slider(
            min: 0,
            max: 100,
            divisions: 100,
            value: displayValue.clamp(0.0, 100.0).toDouble(),
            onChanged: widget.locked
                ? null
                : (value) {
                    setState(() => _draftValue = value);
                    widget.onChanged(value);
                  },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Low',
                    textAlign: TextAlign.left,
                    style: TextStyle(color: AppTheme.muted, fontSize: 9),
                  ),
                ),
                Expanded(
                  child: widget.locked
                      ? Text(
                          '${displayValue.toStringAsFixed(1)}%',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppTheme.blue,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
                const Expanded(
                  child: Text(
                    'High',
                    textAlign: TextAlign.right,
                    style: TextStyle(color: AppTheme.muted, fontSize: 9),
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

class _AiAdvisorEntryCard extends StatelessWidget {
  const _AiAdvisorEntryCard({
    required this.recommendationCount,
    required this.onOpen,
  });

  final int recommendationCount;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: AppTheme.blue.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.psychology_alt_rounded,
                    color: AppTheme.blue,
                  ),
                ),

                const SizedBox(width: 13),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI Property Advisor',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),

                      const SizedBox(height: 5),

                      Text(
                        'Ask questions about your current top $recommendationCount recommendations, scores and priorities.',
                        style: const TextStyle(
                          color: AppTheme.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            const Text(
              'The AI advisor explains the existing recommendation results. It does not recalculate the score or change the property ranking.',
              style: TextStyle(color: AppTheme.muted, fontSize: 11),
            ),

            const SizedBox(height: 14),

            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onOpen,
                icon: const Icon(Icons.chat_bubble_outline_rounded),
                label: const Text('Open AI Property Advisor'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecommendationActionBar extends StatelessWidget {
  const _RecommendationActionBar({
    required this.recommendationCount,
    required this.selectedCount,
    required this.isSaving,
    required this.isSaved,
    required this.canCompare,
    required this.onSave,
    required this.onCompare,
  });

  final int recommendationCount;
  final int selectedCount;
  final bool isSaving;
  final bool isSaved;
  final bool canCompare;
  final VoidCallback onSave;
  final VoidCallback onCompare;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.blue.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.blue.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppTheme.blue.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: AppTheme.blue,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Top $recommendationCount ready',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$selectedCount selected for comparison',
                      style: const TextStyle(
                        color: AppTheme.muted,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: isSaving || isSaved ? null : onSave,
                  icon: isSaving
                      ? const SizedBox(
                          width: 15,
                          height: 15,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          isSaved
                              ? Icons.check_rounded
                              : Icons.bookmark_add_outlined,
                          size: 18,
                        ),
                  label: Text(
                    isSaving
                        ? 'Saving'
                        : isSaved
                        ? 'Saved'
                        : 'Save',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: canCompare ? onCompare : null,
                  icon: const Icon(Icons.compare_arrows_rounded, size: 18),
                  label: const Text('Compare'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RecommendationSwipeCard extends StatelessWidget {
  const _RecommendationSwipeCard({
    required this.recommendation,
    required this.rank,
    required this.selected,
    required this.onComparisonChanged,
  });

  final PropertyRecommendation recommendation;
  final int rank;
  final bool selected;
  final VoidCallback onComparisonChanged;

  @override
  Widget build(BuildContext context) {
    final property = recommendation.property;
    final price = _advisorComparablePrice(property);

    final badgeText = rank == 1 ? 'HIGHEST MATCH' : 'MATCH #$rank';

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              PropertyArt(palette: property.palette, height: 165),
              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: rank == 1 ? AppTheme.green : AppTheme.blue,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    badgeText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '#$rank',
                    style: const TextStyle(
                      color: AppTheme.blue,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          property.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _ScoreBadge(score: recommendation.score),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    property.address,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppTheme.muted, fontSize: 11),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    price == null ? 'Price unavailable' : formatRinggit(price),
                    style: TextStyle(
                      color: price == null ? AppTheme.muted : AppTheme.green,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Why this matches you',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 7),
                  ...recommendation.reasons
                      .take(2)
                      .map(
                        (reason) => Padding(
                          padding: const EdgeInsets.only(bottom: 5),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.check_circle_outline_rounded,
                                size: 16,
                                color: AppTheme.green,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  reason,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 10),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: onComparisonChanged,
                      icon: Icon(
                        selected
                            ? Icons.check_box_rounded
                            : Icons.check_box_outline_blank_rounded,
                      ),
                      label: Text(
                        selected
                            ? 'Selected for comparison'
                            : 'Select for comparison',
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                PropertyDetailScreen(propertyId: property.id),
                          ),
                        );
                      },
                      child: const Text('View details'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreBadge extends StatelessWidget {
  const _ScoreBadge({required this.score});

  final double score;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 54,
      height: 54,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppTheme.blue.withValues(alpha: 0.09),
        shape: BoxShape.circle,
        border: Border.all(
          color: AppTheme.blue.withValues(alpha: 0.25),
          width: 2,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            score.round().toString(),
            style: const TextStyle(
              color: AppTheme.blue,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const Text(
            '/100',
            style: TextStyle(color: AppTheme.muted, fontSize: 8),
          ),
        ],
      ),
    );
  }
}

class _NoMatches extends StatelessWidget {
  const _NoMatches();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(28),
        child: Row(
          children: [
            Icon(Icons.filter_alt_off_rounded, color: AppTheme.muted),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'No listings with valid price data match this area, property type and budget. Try another filter.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
