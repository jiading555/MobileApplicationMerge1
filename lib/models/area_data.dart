import 'area_profile.dart';

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
    this.source = 'Local JSON sample',
    this.sourceUrl,
    this.populationYear,
    this.incomeYear,
    this.crimeYear,
    this.educationYear,
    this.transportYear,
    this.retrievedAt,
    this.isGovernmentProfile = false,
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
  final String source;
  final String? sourceUrl;
  final int? populationYear;
  final int? incomeYear;
  final int? crimeYear;
  final int? educationYear;
  final int? transportYear;
  final DateTime? retrievedAt;
  final bool isGovernmentProfile;

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

  factory AreaData.fromProfile(AreaProfile profile, {AreaData? fallback}) {
    final population = profile.population ?? fallback?.population ?? 0;
    final crimeCount = profile.crimeCount;
    final crimeRate = population <= 0 || crimeCount == null
        ? null
        : crimeCount / population * 100000;
    final safetyScore = crimeRate == null
        ? fallback?.safetyScore ?? 75.0
        : (100 - crimeRate / 35).clamp(45, 95).toDouble();
    final schoolCount =
        profile.educationInstitutionCount ?? fallback?.schools ?? 0;
    final transportCount =
        profile.transportStopCount ?? fallback?.transportScore.round() ?? 0;
    final transportScore = profile.transportStopCount == null
        ? fallback?.transportScore ?? 70.0
        : (transportCount / 2).clamp(35, 100).toDouble();

    return AreaData(
      id: _normaliseId(profile.district),
      name: profile.district,
      state: profile.state,
      population: population,
      populationGrowth: fallback?.populationGrowth ?? 0,
      medianIncome:
          profile.medianHouseholdIncome?.round() ?? fallback?.medianIncome ?? 0,
      safetyScore: safetyScore,
      connectivityScore: fallback?.connectivityScore ?? transportScore,
      transportScore: transportScore,
      schools: schoolCount,
      hospitals: fallback?.hospitals ?? 0,
      averagePricePsf: fallback?.averagePricePsf ?? 0,
      rentalYield: fallback?.rentalYield ?? 0,
      priceGrowth: fallback?.priceGrowth ?? 0,
      priceHistory: fallback?.priceHistory ?? const [0, 0, 0, 0, 0, 0, 0],
      snapshotDate: (profile.dataYear ?? fallback?.snapshotDate ?? '')
          .toString(),
      source: profile.source ?? 'OpenDOSM; data.gov.my',
      sourceUrl: profile.sourceUrl,
      populationYear: profile.populationYear,
      incomeYear: profile.incomeYear,
      crimeYear: profile.crimeYear,
      educationYear: profile.educationYear,
      transportYear: profile.transportYear,
      retrievedAt: profile.retrievedAt,
      isGovernmentProfile: true,
    );
  }

  static String _normaliseId(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
  }
}
