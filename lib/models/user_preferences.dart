enum PropertyGoal { ownStay, investment }

class UserPreferences {
  const UserPreferences({
    this.goal = PropertyGoal.ownStay,
    this.budget = 900000,
    this.preferredAreaId = 'any',
    this.propertyType = 'Any',
    this.preferredState = '',
    this.preferredDistrict = '',
    this.minimumBudget = 350000,
    this.maximumBudget = 900000,
    this.ownStaySafetyPriority = 30,
    this.ownStayEducationPriority = 25,
    this.ownStayTransportPriority = 20,
    this.investmentIncomePriority = 20,
    this.investmentTransportPriority = 15,
    this.investmentAffordabilityPriority = 15,
    this.safetyPriority = 0.8,
    this.transportPriority = 0.7,
    this.facilitiesPriority = 0.7,
  });

  final PropertyGoal goal;
  final double budget;
  final String preferredAreaId;
  final String propertyType;
  final String preferredState;
  final String preferredDistrict;
  final double minimumBudget;
  final double maximumBudget;
  final double ownStaySafetyPriority;
  final double ownStayEducationPriority;
  final double ownStayTransportPriority;
  final double investmentIncomePriority;
  final double investmentTransportPriority;
  final double investmentAffordabilityPriority;
  final double safetyPriority;
  final double transportPriority;
  final double facilitiesPriority;

  UserPreferences copyWith({
    PropertyGoal? goal,
    double? budget,
    String? preferredAreaId,
    String? propertyType,

    String? preferredState,
    String? preferredDistrict,
    double? minimumBudget,
    double? maximumBudget,

    double? ownStaySafetyPriority,
    double? ownStayEducationPriority,
    double? ownStayTransportPriority,

    double? investmentIncomePriority,
    double? investmentTransportPriority,
    double? investmentAffordabilityPriority,

    double? safetyPriority,
    double? transportPriority,
    double? facilitiesPriority,
  }) {
    return UserPreferences(
      goal: goal ?? this.goal,
      budget: budget ?? this.budget,
      preferredAreaId: preferredAreaId ?? this.preferredAreaId,
      propertyType: propertyType ?? this.propertyType,

      preferredState: preferredState ?? this.preferredState,
      preferredDistrict: preferredDistrict ?? this.preferredDistrict,
      minimumBudget: minimumBudget ?? this.minimumBudget,
      maximumBudget: maximumBudget ?? this.maximumBudget,

      ownStaySafetyPriority:
          ownStaySafetyPriority ?? this.ownStaySafetyPriority,

      ownStayEducationPriority:
          ownStayEducationPriority ?? this.ownStayEducationPriority,

      ownStayTransportPriority:
          ownStayTransportPriority ?? this.ownStayTransportPriority,

      investmentIncomePriority:
          investmentIncomePriority ?? this.investmentIncomePriority,

      investmentTransportPriority:
          investmentTransportPriority ?? this.investmentTransportPriority,

      investmentAffordabilityPriority:
          investmentAffordabilityPriority ??
          this.investmentAffordabilityPriority,

      safetyPriority: safetyPriority ?? this.safetyPriority,

      transportPriority: transportPriority ?? this.transportPriority,

      facilitiesPriority: facilitiesPriority ?? this.facilitiesPriority,
    );
  }
}
