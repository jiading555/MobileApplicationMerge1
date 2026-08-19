import 'property.dart';

class ScoreFactor {
  const ScoreFactor({
    required this.label,
    required this.score,
    required this.weight,
  });

  final String label;
  final double score;
  final double weight;

  double get contribution => score * weight;
}

class PropertyRecommendation {
  const PropertyRecommendation({
    required this.property,
    required this.score,
    required this.factors,
    required this.reasons,
    required this.cautions,
  });

  final Property property;
  final double score;
  final List<ScoreFactor> factors;
  final List<String> reasons;
  final List<String> cautions;
}
