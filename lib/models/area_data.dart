class AreaData {
  const AreaData({
    required this.id,
    required this.name,
    required this.state,
    required this.population,
    required this.populationGrowth,
    required this.medianIncome,
    required this.safetyScore,
    required this.connectivityScore,
    required this.transportScore,
    required this.schools,
    required this.hospitals,
    required this.averagePricePsf,
    required this.rentalYield,
    required this.priceGrowth,
    required this.priceHistory,
    required this.snapshotDate,
  });

  final String id;
  final String name;
  final String state;
  final int population;
  final double populationGrowth;
  final int medianIncome;
  final double safetyScore;
  final double connectivityScore;
  final double transportScore;
  final int schools;
  final int hospitals;
  final int averagePricePsf;
  final double rentalYield;
  final double priceGrowth;
  final List<double> priceHistory;
  final String snapshotDate;

  double get infrastructureScore {
    final facilityScore = ((schools / 130) * 60 + (hospitals / 15) * 40)
        .clamp(0, 100)
        .toDouble();
    return (facilityScore * 0.45 +
            transportScore * 0.35 +
            connectivityScore * 0.20)
        .clamp(0, 100)
        .toDouble();
  }

  factory AreaData.fromJson(Map<String, dynamic> json) {
    return AreaData(
      id: json['id'] as String,
      name: json['name'] as String,
      state: json['state'] as String,
      population: json['population'] as int,
      populationGrowth: (json['populationGrowth'] as num).toDouble(),
      medianIncome: json['medianIncome'] as int,
      safetyScore: (json['safetyScore'] as num).toDouble(),
      connectivityScore: (json['connectivityScore'] as num).toDouble(),
      transportScore: (json['transportScore'] as num).toDouble(),
      schools: json['schools'] as int,
      hospitals: json['hospitals'] as int,
      averagePricePsf: json['averagePricePsf'] as int,
      rentalYield: (json['rentalYield'] as num).toDouble(),
      priceGrowth: (json['priceGrowth'] as num).toDouble(),
      priceHistory: (json['priceHistory'] as List<dynamic>)
          .map((value) => (value as num).toDouble())
          .toList(),
      snapshotDate: json['snapshotDate'] as String,
    );
  }
}
