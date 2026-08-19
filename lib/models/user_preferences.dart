enum PropertyGoal { ownStay, investment }

class UserPreferences {
  const UserPreferences({
    this.goal = PropertyGoal.ownStay,
    this.budget = 900000,
    this.preferredAreaId = 'any',
    this.propertyType = 'Any',
    this.safetyPriority = 0.8,
    this.transportPriority = 0.7,
    this.facilitiesPriority = 0.7,
  });

  final PropertyGoal goal;
  final double budget;
  final String preferredAreaId;
  final String propertyType;
  final double safetyPriority;
  final double transportPriority;
  final double facilitiesPriority;

  UserPreferences copyWith({
    PropertyGoal? goal,
    double? budget,
    String? preferredAreaId,
    String? propertyType,
    double? safetyPriority,
    double? transportPriority,
    double? facilitiesPriority,
  }) {
    return UserPreferences(
      goal: goal ?? this.goal,
      budget: budget ?? this.budget,
      preferredAreaId: preferredAreaId ?? this.preferredAreaId,
      propertyType: propertyType ?? this.propertyType,
      safetyPriority: safetyPriority ?? this.safetyPriority,
      transportPriority: transportPriority ?? this.transportPriority,
      facilitiesPriority: facilitiesPriority ?? this.facilitiesPriority,
    );
  }
}
