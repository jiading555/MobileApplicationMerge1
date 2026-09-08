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
      safetyPriority: safetyPriority ?? this.safetyPriority,
      transportPriority: transportPriority ?? this.transportPriority,
      facilitiesPriority: facilitiesPriority ?? this.facilitiesPriority,
    );
  }
}
