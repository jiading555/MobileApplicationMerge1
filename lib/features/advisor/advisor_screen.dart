import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/page_container.dart';
import '../../core/widgets/property_art.dart';
import '../../models/recommendation.dart';
import '../../models/user_preferences.dart';
import '../search/property_detail_screen.dart';
import 'ai_advisor_chat_screen.dart';
import 'comparison_screen.dart';
import 'saved_recommendations_screen.dart';

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

  final Set<String> selectedComparisonIds = {};

  final PageController _recommendationPageController =
  PageController(viewportFraction: 0.90);

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

      goal = preferences.goal;
      budget = preferences.budget;
      areaId = preferences.preferredAreaId;
      propertyType = preferences.propertyType;

      selectedState = 'any';
      if (areaId != 'any') {
        for (final area in appState.areas) {
          if (area.id == areaId) {
            selectedState = area.state;
            break;
          }
        }
      }

      ownStaySafetyPriority =
          preferences.ownStaySafetyPriority;

      ownStayEducationPriority =
          preferences.ownStayEducationPriority;

      ownStayTransportPriority =
          preferences.ownStayTransportPriority;

      investmentIncomePriority =
          preferences.investmentIncomePriority;

      investmentTransportPriority =
          preferences.investmentTransportPriority;

      investmentAffordabilityPriority =
          preferences.investmentAffordabilityPriority;

      seeded = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);

    final recommendations = state.recommendations;

    final visibleRecommendations =
    recommendations.take(3).toList();

    final selectedRecommendations =
    visibleRecommendations
        .where(
          (item) => selectedComparisonIds.contains(
        item.property.id,
      ),
    )
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Smart property advisor',
        ),
        actions: [
          IconButton(
            tooltip: 'Saved Recommendations',
            icon: const Icon(
              Icons.bookmarks_outlined,
            ),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                  const SavedRecommendationsScreen(),
                ),
              );
            },
          ),
          IconButton(
            onPressed: () => _showMethod(context),
            tooltip: 'How scoring works',
            icon: const Icon(
              Icons.info_outline_rounded,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        child: PageContainer(
          maxWidth: 1100,
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              _AdvisorIntro(
                goal: goal,
              ),

              const SizedBox(height: 22),

              _PreferencePanel(
                goal: goal,
                budget: budget,
                selectedState: selectedState,
                areaId: areaId,
                propertyType: propertyType,

                scoringLocked: scoringLocked,

                appliedWeights: appliedWeights,

                ownStaySafetyPriority:
                ownStaySafetyPriority,

                ownStayEducationPriority:
                ownStayEducationPriority,

                ownStayTransportPriority:
                ownStayTransportPriority,

                investmentIncomePriority:
                investmentIncomePriority,

                investmentTransportPriority:
                investmentTransportPriority,

                investmentAffordabilityPriority:
                investmentAffordabilityPriority,

                onGoalChanged: _changeGoal,

                onBudgetChanged: (value) {
                  final appState = AppScope.of(context);

                  setState(() {
                    budget = value;

                    final availableStates = _availableStates(
                      state: appState,
                      targetBudget: value,
                    );

                    if (selectedState != 'any' &&
                        !availableStates.contains(selectedState)) {
                      selectedState = 'any';
                      areaId = 'any';
                      propertyType = 'Any';
                    } else if (selectedState != 'any') {
                      if (areaId != 'any' &&
                          !_areaHasPropertyWithinBudget(
                            state: appState,
                            targetAreaId: areaId,
                            targetBudget: value,
                          )) {
                        areaId = 'any';
                        propertyType = 'Any';
                      } else if (areaId != 'any') {
                        final availableTypes =
                        _availablePropertyTypes(
                          state: appState,
                          targetBudget: value,
                          targetAreaId: areaId,
                        );

                        if (propertyType != 'Any' &&
                            !availableTypes.contains(propertyType)) {
                          propertyType = 'Any';
                        }
                      }
                    }

                    _resetScoringAfterPreferenceChange();
                  });
                },

                onStateChanged: (value) {
                  setState(() {
                    selectedState = value;
                    areaId = 'any';
                    propertyType = 'Any';

                    _resetScoringAfterPreferenceChange();
                  });
                },

                onAreaChanged: (value) {
                  final appState = AppScope.of(context);

                  setState(() {
                    areaId = value;

                    if (areaId == 'any') {
                      propertyType = 'Any';
                    } else {
                      final availableTypes =
                      _availablePropertyTypes(
                        state: appState,
                        targetBudget: budget,
                        targetAreaId: areaId,
                      );

                      if (propertyType != 'Any' &&
                          !availableTypes.contains(propertyType)) {
                        propertyType = 'Any';
                      }
                    }

                    _resetScoringAfterPreferenceChange();
                  });
                },

                onTypeChanged: (value) {
                  setState(() {
                    propertyType = value;

                    // Property Type is the final level of the cascade.
                    // Changing it must never reset State or Area.
                    _resetScoringAfterPreferenceChange();
                  });
                },

                onOwnStaySafetyChanged: (value) {
                  if (scoringLocked) return;

                  setState(() {
                    ownStaySafetyPriority = value;
                  });
                },

                onOwnStayEducationChanged: (value) {
                  if (scoringLocked) return;

                  setState(() {
                    ownStayEducationPriority = value;
                  });
                },

                onOwnStayTransportChanged: (value) {
                  if (scoringLocked) return;

                  setState(() {
                    ownStayTransportPriority = value;
                  });
                },

                onInvestmentIncomeChanged: (value) {
                  if (scoringLocked) return;

                  setState(() {
                    investmentIncomePriority = value;
                  });
                },

                onInvestmentTransportChanged:
                    (value) {
                  if (scoringLocked) return;

                  setState(() {
                    investmentTransportPriority =
                        value;
                  });
                },

                onInvestmentAffordabilityChanged:
                    (value) {
                  if (scoringLocked) return;

                  setState(() {
                    investmentAffordabilityPriority =
                        value;
                  });
                },

                onResetWeights: _resetPriorities,

                onGenerate: _generate,
              ),

              if (showResults) ...[
                const SizedBox(height: 30),

                Text(
                  'Top matches from your preferences',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge,
                ),

                const SizedBox(height: 4),

                Text(
                  '${recommendations.length} matches ranked with a transparent weighted score',
                  style: const TextStyle(
                    color: AppTheme.muted,
                  ),
                ),

                const SizedBox(height: 16),

                if (recommendations.isEmpty)
                  const _NoMatches()
                else ...[
                  _ComparisonSelectionBar(
                    selectedCount:
                    selectedComparisonIds.length,

                    canCompare:
                    selectedRecommendations.length >= 2 &&
                        selectedRecommendations.length <= 3,

                    onCompare: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              ComparisonScreen(
                                recommendations:
                                selectedRecommendations,
                              ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 14),

                  const Row(
                    children: [
                      Icon(
                        Icons.swipe_rounded,
                        size: 18,
                        color: AppTheme.blue,
                      ),
                      SizedBox(width: 7),
                      Text(
                        'Swipe to view your Top 3 matches',
                        style: TextStyle(
                          color: AppTheme.muted,
                          fontSize: 12,
                        ),
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
                    children: List.generate(
                      visibleRecommendations.length,
                          (index) {
                        final active =
                            index == _recommendationPageIndex;

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
                      },
                    ),
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

                const SizedBox(height: 10),

                const _DecisionNotice(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _changeGoal(
      PropertyGoal value,
      ) {
    setState(() {
      goal = value;

      scoringLocked = false;
      appliedWeights = [];
      selectedComparisonIds.clear();

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
    showResults = false;
  }

  bool _areaHasPropertyWithinBudget({
    required AppState state,
    required String targetAreaId,
    required double targetBudget,
  }) {
    final validAreaIds = state.areas.map((area) => area.id).toSet();

    return state.properties.any((property) {
      final price = property.price;

      if (price == null) {
        return false;
      }

      if (!validAreaIds.contains(property.areaId)) {
        return false;
      }

      return property.areaId == targetAreaId &&
          price <= targetBudget;
    });
  }

  List<String> _availableStates({
    required AppState state,
    required double targetBudget,
  }) {
    final validAreaIds = state.areas.map((area) => area.id).toSet();

    final areaIdsWithProperties = state.properties
        .where((property) {
      final price = property.price;

      return price != null &&
          price <= targetBudget &&
          validAreaIds.contains(property.areaId);
    })
        .map((property) => property.areaId)
        .toSet();

    final states = state.areas
        .where((area) => areaIdsWithProperties.contains(area.id))
        .map((area) => area.state.trim())
        .where((stateName) => stateName.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    return states;
  }

  List<String> _availablePropertyTypes({
    required AppState state,
    required double targetBudget,
    required String targetAreaId,
  }) {
    if (targetAreaId == 'any') {
      return const [];
    }

    final types = state.properties
        .where((property) {
      final price = property.price;

      if (price == null || price > targetBudget) {
        return false;
      }

      return property.areaId == targetAreaId;
    })
        .expand((property) => property.normalizedPropertyTypes)
        .toSet()
        .toList()
      ..sort();

    return types;
  }

  void _generate() {
    final state = AppScope.of(context);

    if (selectedState != 'any' && areaId == 'any') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please select an area after choosing a state.',
          ),
        ),
      );
      return;
    }

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
      targetAreaId: areaId,
    );

    final effectivePropertyType =
    areaId == 'any'
        ? 'Any'
        : propertyType == 'Any' ||
        availableTypes.contains(propertyType)
        ? propertyType
        : 'Any';

    final effectiveAreaId = areaId;

    final priorities =
    goal == PropertyGoal.ownStay
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

    final totalPriority =
    priorities.fold<double>(
      0,
          (sum, value) => sum + value,
    );

    if (totalPriority <= 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Please set at least one scoring priority.',
          ),
        ),
      );

      return;
    }

    final normalisedWeights =
    _normalisePriorities(
      priorities,
    );

    state.updatePreferences(
      state.preferences.copyWith(
        goal: goal,
        budget: budget,
        preferredAreaId: effectiveAreaId,
        propertyType: effectivePropertyType,

        ownStaySafetyPriority:
        ownStaySafetyPriority,

        ownStayEducationPriority:
        ownStayEducationPriority,

        ownStayTransportPriority:
        ownStayTransportPriority,

        investmentIncomePriority:
        investmentIncomePriority,

        investmentTransportPriority:
        investmentTransportPriority,

        investmentAffordabilityPriority:
        investmentAffordabilityPriority,
      ),
    );

    setState(() {
      areaId = effectiveAreaId;
      propertyType = effectivePropertyType;
      appliedWeights = normalisedWeights;
      scoringLocked = true;
      selectedComparisonIds.clear();
      showResults = true;
      _recommendationPageIndex = 0;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_recommendationPageController.hasClients) {
        _recommendationPageController.jumpToPage(0);
      }
    });
  }

  List<double> _normalisePriorities(
      List<double> priorities,
      ) {
    final total =
    priorities.fold<double>(
      0,
          (sum, value) =>
      sum +
          value.clamp(
            0,
            100,
          ),
    );

    if (total <= 0) {
      final equal =
          1.0 / priorities.length;

      return List<double>.filled(
        priorities.length,
        equal,
      );
    }

    return priorities
        .map(
          (value) =>
      value.clamp(
        0,
        100,
      ) /
          total,
    )
        .toList();
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
      showResults = false;
    });
  }

  void _toggleComparison(
      PropertyRecommendation recommendation,
      ) {
    final id =
        recommendation.property.id;

    setState(() {
      if (selectedComparisonIds.contains(id)) {
        selectedComparisonIds.remove(id);
        return;
      }

      if (selectedComparisonIds.length >= 3) {
        ScaffoldMessenger.of(context)
            .showSnackBar(
          const SnackBar(
            content: Text(
              'You can compare a maximum of 3 properties.',
            ),
          ),
        );

        return;
      }

      selectedComparisonIds.add(id);
    });
  }

  void _showMethod(
      BuildContext context,
      ) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) =>
      const Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          4,
          24,
          28,
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize:
            MainAxisSize.min,
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              Text(
                'Transparent recommendation method',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight:
                  FontWeight.w800,
                ),
              ),

              SizedBox(height: 16),

              Text(
                'Own Stay',
                style: TextStyle(
                  fontWeight:
                  FontWeight.w800,
                ),
              ),

              SizedBox(height: 6),

              Text(
                'Safety • Education Facilities • Transportation',
              ),

              SizedBox(height: 16),

              Text(
                'Investment',
                style: TextStyle(
                  fontWeight:
                  FontWeight.w800,
                ),
              ),

              SizedBox(height: 6),

              Text(
                'Income / Economic Indicator • Transportation • Property Affordability',
              ),

              SizedBox(height: 16),

              Text(
                'Before generating, the sliders represent priority levels rather than percentages. After Generate Matches is pressed, the priorities are normalised into percentages that total 100%. The sliders are then locked until Reset to default is selected.',
                style: TextStyle(
                  color: AppTheme.muted,
                ),
              ),

              SizedBox(height: 12),

              Text(
                'Switching between Own Stay and Investment starts that goal again using its default editable priorities.',
                style: TextStyle(
                  color: AppTheme.muted,
                ),
              ),

              SizedBox(height: 12),

              Text(
                'AI only explains the calculated recommendation and does not determine or modify the suitability score.',
                style: TextStyle(
                  color: AppTheme.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdvisorIntro extends StatelessWidget {
  const _AdvisorIntro({
    required this.goal,
  });

  final PropertyGoal goal;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.navy,
            AppTheme.blue,
            AppTheme.teal,
          ],
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
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  goal == PropertyGoal.ownStay
                      ? 'Find a home that fits your life'
                      : 'Explore investment potential',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight:
                    FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 5),

                const Text(
                  'Set your goal and adjust what matters most to you.',
                  style: TextStyle(
                    color: Colors.white70,
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

class _PreferencePanel extends StatelessWidget {
  const _PreferencePanel({
    required this.goal,
    required this.budget,
    required this.selectedState,
    required this.areaId,
    required this.propertyType,

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

  final bool scoringLocked;
  final List<double> appliedWeights;

  final double ownStaySafetyPriority;
  final double ownStayEducationPriority;
  final double ownStayTransportPriority;

  final double investmentIncomePriority;
  final double investmentTransportPriority;
  final double investmentAffordabilityPriority;

  final ValueChanged<PropertyGoal>
  onGoalChanged;

  final ValueChanged<double>
  onBudgetChanged;

  final ValueChanged<String>
  onStateChanged;

  final ValueChanged<String>
  onAreaChanged;

  final ValueChanged<String>
  onTypeChanged;

  final ValueChanged<double>
  onOwnStaySafetyChanged;

  final ValueChanged<double>
  onOwnStayEducationChanged;

  final ValueChanged<double>
  onOwnStayTransportChanged;

  final ValueChanged<double>
  onInvestmentIncomeChanged;

  final ValueChanged<double>
  onInvestmentTransportChanged;

  final ValueChanged<double>
  onInvestmentAffordabilityChanged;

  final VoidCallback onResetWeights;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);

    final validAreaIds = state.areas.map((area) => area.id).toSet();

    // Only properties with a valid Advisor area, valid price and
    // price within the selected budget participate in the location cascade.
    final areaIdsWithProperties = state.properties
        .where((property) {
      final price = property.price;

      return price != null &&
          price <= budget &&
          validAreaIds.contains(property.areaId);
    })
        .map((property) => property.areaId)
        .toSet();

    // Level 1: State.
    // Only states that contain at least one usable area/property are shown.
    final availableStates = state.areas
        .where((area) => areaIdsWithProperties.contains(area.id))
        .map((area) => area.state.trim())
        .where((stateName) => stateName.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    final effectiveSelectedState =
    selectedState == 'any' ||
        availableStates.contains(selectedState)
        ? selectedState
        : 'any';

    // Level 2: Area.
    // The long area list is hidden until a state has been selected.
    final availableAreas = effectiveSelectedState == 'any'
        ? <dynamic>[]
        : state.areas
        .where(
          (area) =>
      area.state == effectiveSelectedState &&
          areaIdsWithProperties.contains(area.id),
    )
        .toList()
      ..sort(
            (a, b) => a.name.toLowerCase().compareTo(
          b.name.toLowerCase(),
        ),
      );

    final availableAreaIds =
    availableAreas.map((area) => area.id).toSet();

    final effectiveAreaId =
    areaId != 'any' && availableAreaIds.contains(areaId)
        ? areaId
        : 'any';

    // Level 3: Property Type.
    // Types are derived only from the selected area, so an unavailable
    // type such as Semi-D is never offered for an area that has none.
    final availablePropertyTypes = effectiveAreaId == 'any'
        ? <String>[]
        : state.properties
        .where((property) {
      final price = property.price;

      return price != null &&
          price <= budget &&
          property.areaId == effectiveAreaId;
    })
        .expand(
          (property) => property.normalizedPropertyTypes,
    )
        .toSet()
        .toList()
      ..sort();

    final effectivePropertyType =
    propertyType == 'Any' ||
        availablePropertyTypes.contains(propertyType)
        ? propertyType
        : 'Any';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            Text(
              'Your property goal',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium,
            ),

            const SizedBox(height: 11),

            SegmentedButton<PropertyGoal>(
              segments: const [
                ButtonSegment(
                  value:
                  PropertyGoal.ownStay,
                  icon: Icon(
                    Icons.home_rounded,
                  ),
                  label:
                  Text('Own stay'),
                ),
                ButtonSegment(
                  value:
                  PropertyGoal.investment,
                  icon: Icon(
                    Icons.trending_up_rounded,
                  ),
                  label:
                  Text('Investment'),
                ),
              ],
              selected: {goal},
              onSelectionChanged:
                  (values) {
                onGoalChanged(
                  values.first,
                );
              },
            ),

            const SizedBox(height: 24),

            Row(
              children: [
                Text(
                  'Maximum budget',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium,
                ),

                const Spacer(),

                Text(
                  formatRinggit(
                    budget,
                  ),
                  style: const TextStyle(
                    color: AppTheme.blue,
                    fontWeight:
                    FontWeight.w800,
                  ),
                ),
              ],
            ),

            Slider(
              min: 350000,
              max: 1600000,
              divisions: 25,
              value: budget,
              onChanged: onBudgetChanged,
            ),

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
                    decoration: const InputDecoration(
                      labelText: 'State',
                    ),
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
                    decoration: const InputDecoration(
                      labelText: 'Area',
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 'any',
                        child: Text(
                          effectiveSelectedState == 'any'
                              ? 'Select state first'
                              : 'Select area',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      ...availableAreas.map(
                            (item) => DropdownMenuItem<String>(
                          value: item.id,
                          child: Text(
                            item.name,
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
                'type-$effectivePropertyType-$effectiveAreaId-${budget.round()}',
              ),
              initialValue: effectivePropertyType,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Property type',
              ),
              items: [
                DropdownMenuItem(
                  value: 'Any',
                  child: Text(
                    effectiveAreaId == 'any'
                        ? 'Select area first'
                        : 'Any',
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
              onChanged: effectiveAreaId == 'any'
                  ? null
                  : (value) {
                onTypeChanged(value ?? 'Any');
              },
            ),

            const SizedBox(height: 24),

            Text(
              'Scoring priorities',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium,
            ),

            const SizedBox(height: 6),

            Text(
              scoringLocked
                  ? 'These percentages are the applied weights used for the current recommendation. Press Reset to default to adjust the priorities again.'
                  : 'Move each slider independently from low to high importance. Percentages are calculated after Generate matches.',
              style: const TextStyle(
                color: AppTheme.muted,
                fontSize: 12,
              ),
            ),

            const SizedBox(height: 14),

            _PrioritySliders(
              goal: goal,

              scoringLocked:
              scoringLocked,

              appliedWeights:
              appliedWeights,

              ownStaySafetyPriority:
              ownStaySafetyPriority,

              ownStayEducationPriority:
              ownStayEducationPriority,

              ownStayTransportPriority:
              ownStayTransportPriority,

              investmentIncomePriority:
              investmentIncomePriority,

              investmentTransportPriority:
              investmentTransportPriority,

              investmentAffordabilityPriority:
              investmentAffordabilityPriority,

              onOwnStaySafetyChanged:
              onOwnStaySafetyChanged,

              onOwnStayEducationChanged:
              onOwnStayEducationChanged,

              onOwnStayTransportChanged:
              onOwnStayTransportChanged,

              onInvestmentIncomeChanged:
              onInvestmentIncomeChanged,

              onInvestmentTransportChanged:
              onInvestmentTransportChanged,

              onInvestmentAffordabilityChanged:
              onInvestmentAffordabilityChanged,

              onResetWeights:
              onResetWeights,
            ),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed:
                scoringLocked
                    ? null
                    : onGenerate,

                icon: Icon(
                  scoringLocked
                      ? Icons.lock_outline_rounded
                      : Icons.auto_awesome_rounded,
                ),

                label: Text(
                  scoringLocked
                      ? 'Scoring applied'
                      : 'Generate matches',
                ),
              ),
            ),
          ],
        ),
      ),
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

  final ValueChanged<double>
  onOwnStaySafetyChanged;

  final ValueChanged<double>
  onOwnStayEducationChanged;

  final ValueChanged<double>
  onOwnStayTransportChanged;

  final ValueChanged<double>
  onInvestmentIncomeChanged;

  final ValueChanged<double>
  onInvestmentTransportChanged;

  final ValueChanged<double>
  onInvestmentAffordabilityChanged;

  final VoidCallback onResetWeights;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.blue.withValues(
          alpha: 0.05,
        ),
        borderRadius:
        BorderRadius.circular(8),
        border: Border.all(
          color: AppTheme.blue.withValues(
            alpha: 0.15,
          ),
        ),
      ),
      child: Column(
        children: [
          if (goal ==
              PropertyGoal.ownStay) ...[
            _PrioritySlider(
              label: 'Safety',
              value:
              ownStaySafetyPriority,
              appliedWeight:
              _weightAt(0),
              locked:
              scoringLocked,
              onChanged:
              onOwnStaySafetyChanged,
            ),

            _PrioritySlider(
              label:
              'Education facilities',
              value:
              ownStayEducationPriority,
              appliedWeight:
              _weightAt(1),
              locked:
              scoringLocked,
              onChanged:
              onOwnStayEducationChanged,
            ),

            _PrioritySlider(
              label:
              'Transportation',
              value:
              ownStayTransportPriority,
              appliedWeight:
              _weightAt(2),
              locked:
              scoringLocked,
              onChanged:
              onOwnStayTransportChanged,
            ),
          ] else ...[
            _PrioritySlider(
              label:
              'Income / economic indicator',
              value:
              investmentIncomePriority,
              appliedWeight:
              _weightAt(0),
              locked:
              scoringLocked,
              onChanged:
              onInvestmentIncomeChanged,
            ),

            _PrioritySlider(
              label:
              'Transportation',
              value:
              investmentTransportPriority,
              appliedWeight:
              _weightAt(1),
              locked:
              scoringLocked,
              onChanged:
              onInvestmentTransportChanged,
            ),

            _PrioritySlider(
              label:
              'Property affordability',
              value:
              investmentAffordabilityPriority,
              appliedWeight:
              _weightAt(2),
              locked:
              scoringLocked,
              onChanged:
              onInvestmentAffordabilityChanged,
            ),
          ],

          if (scoringLocked &&
              appliedWeights.length >= 3) ...[
            const Divider(),

            const Row(
              children: [
                Text(
                  'Total weight',
                  style: TextStyle(
                    fontWeight:
                    FontWeight.w800,
                  ),
                ),
                Spacer(),
                Text(
                  '100.0%',
                  style: TextStyle(
                    color:
                    AppTheme.green,
                    fontWeight:
                    FontWeight.w900,
                  ),
                ),
              ],
            ),
          ],

          const Divider(),

          Align(
            alignment:
            Alignment.centerRight,
            child: TextButton.icon(
              onPressed:
              onResetWeights,
              icon: const Icon(
                Icons.refresh_rounded,
              ),
              label: const Text(
                'Reset to default',
              ),
            ),
          ),
        ],
      ),
    );
  }

  double? _weightAt(
      int index,
      ) {
    if (!scoringLocked ||
        appliedWeights.length <= index) {
      return null;
    }

    return appliedWeights[index];
  }
}

class _PrioritySlider extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final displayValue =
    locked && appliedWeight != null
        ? appliedWeight! * 100
        : value;

    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 6,
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
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
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight:
                    FontWeight.w600,
                  ),
                ),
              ),

              if (locked &&
                  appliedWeight != null)
                Text(
                  '${(appliedWeight! * 100).toStringAsFixed(1)}%',
                  style: const TextStyle(
                    color: AppTheme.blue,
                    fontWeight:
                    FontWeight.w800,
                  ),
                ),
            ],
          ),

          const SizedBox(height: 2),

          Slider(
            min: 0,
            max: 100,
            divisions: 100,

            value: displayValue
                .clamp(
              0.0,
              100.0,
            )
                .toDouble(),

            onChanged:
            locked
                ? null
                : onChanged,
          ),

          Padding(
            padding:
            const EdgeInsets.symmetric(
              horizontal: 24,
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Low',
                    textAlign:
                    TextAlign.left,
                    style: TextStyle(
                      color:
                      AppTheme.muted,
                      fontSize: 9,
                    ),
                  ),
                ),

                Expanded(
                  child: locked
                      ? const Row(
                    mainAxisAlignment:
                    MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.lock_outline_rounded,
                        size: 10,
                        color:
                        AppTheme.muted,
                      ),
                      SizedBox(width: 3),
                      Text(
                        'Locked',
                        style:
                        TextStyle(
                          color:
                          AppTheme.muted,
                          fontSize: 9,
                        ),
                      ),
                    ],
                  )
                      : const SizedBox(),
                ),

                const Expanded(
                  child: Text(
                    'High',
                    textAlign:
                    TextAlign.right,
                    style: TextStyle(
                      color:
                      AppTheme.muted,
                      fontSize: 9,
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

class _AiAdvisorEntryCard
    extends StatelessWidget {
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
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color:
                    AppTheme.blue.withValues(
                      alpha: 0.10,
                    ),
                    borderRadius:
                    BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.psychology_alt_rounded,
                    color: AppTheme.blue,
                  ),
                ),

                const SizedBox(width: 13),

                Expanded(
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI Property Advisor',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(
                          fontWeight:
                          FontWeight.w800,
                        ),
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
              style: TextStyle(
                color: AppTheme.muted,
                fontSize: 11,
              ),
            ),

            const SizedBox(height: 14),

            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onOpen,
                icon: const Icon(
                  Icons.chat_bubble_outline_rounded,
                ),
                label: const Text(
                  'Open AI Property Advisor',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ComparisonSelectionBar
    extends StatelessWidget {
  const _ComparisonSelectionBar({
    required this.selectedCount,
    required this.canCompare,
    required this.onCompare,
  });

  final int selectedCount;
  final bool canCompare;
  final VoidCallback onCompare;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.blue.withValues(
          alpha: 0.06,
        ),
        borderRadius:
        BorderRadius.circular(8),
        border: Border.all(
          color: AppTheme.blue.withValues(
            alpha: 0.18,
          ),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.compare_arrows_rounded,
            color: AppTheme.blue,
          ),

          const SizedBox(width: 10),

          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                const Text(
                  'Select 2–3 properties to compare',
                  style: TextStyle(
                    fontWeight:
                    FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 2),

                Text(
                  '$selectedCount selected',
                  style: const TextStyle(
                    color:
                    AppTheme.muted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),

          FilledButton.icon(
            onPressed:
            canCompare
                ? onCompare
                : null,
            icon: const Icon(
              Icons.compare_rounded,
              size: 18,
            ),
            label: const Text(
              'Compare',
            ),
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
    final price = property.price;

    final badgeText =
    rank == 1 ? 'HIGHEST MATCH' : 'MATCH #$rank';

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              PropertyArt(
                palette: property.palette,
                height: 165,
              ),
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
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _ScoreBadge(
                        score: recommendation.score,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    property.address,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.muted,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    price == null
                        ? 'Price unavailable'
                        : formatRinggit(price),
                    style: TextStyle(
                      color: price == null
                          ? AppTheme.muted
                          : AppTheme.green,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Why this matches you',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 7),
                  ...recommendation.reasons.take(2).map(
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
                              style: const TextStyle(
                                fontSize: 10,
                              ),
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
                            builder: (_) => PropertyDetailScreen(
                              propertyId: property.id,
                            ),
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
  const _ScoreBadge({
    required this.score,
  });

  final double score;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 54,
      height: 54,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppTheme.blue.withValues(
          alpha: 0.09,
        ),
        shape: BoxShape.circle,
        border: Border.all(
          color: AppTheme.blue.withValues(
            alpha: 0.25,
          ),
          width: 2,
        ),
      ),
      child: Column(
        mainAxisAlignment:
        MainAxisAlignment.center,
        children: [
          Text(
            score.round().toString(),
            style: const TextStyle(
              color: AppTheme.blue,
              fontSize: 17,
              fontWeight:
              FontWeight.w900,
            ),
          ),
          const Text(
            '/100',
            style: TextStyle(
              color: AppTheme.muted,
              fontSize: 8,
            ),
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
            Icon(
              Icons.filter_alt_off_rounded,
              color: AppTheme.muted,
            ),
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

class _DecisionNotice extends StatelessWidget {
  const _DecisionNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(
          0xFFFFF7E6,
        ),
        borderRadius:
        BorderRadius.circular(8),
        border: Border.all(
          color: const Color(
            0xFFF4D89A,
          ),
        ),
      ),
      child: const Row(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.fact_check_outlined,
            color: Color(
              0xFF9B6A08,
            ),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Decision support only. Scores are calculated using user-selected priority levels, normalised weighted criteria and available data, not a professional property valuation.',
              style: TextStyle(
                color: Color(
                  0xFF70500C,
                ),
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
