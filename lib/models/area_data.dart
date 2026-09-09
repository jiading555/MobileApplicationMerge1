import 'area_profile.dart';

class AreaData {
  const AreaData({
    required this.id,
    required this.name,
    required this.state,
    this.population,
    this.populationGrowth,
    this.medianIncome,
    this.safetyScore,
    this.connectivityScore,
    this.transportScore,
    this.schools,
    this.hospitals,
    this.averagePricePsf,
    this.rentalYield,
    this.priceGrowth,
    this.priceHistory = const [],
    this.snapshotDate,
    this.source = 'Static metadata',
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
  final int? population;
  final double? populationGrowth;
  final int? medianIncome;
  final double? safetyScore;
  final double? connectivityScore;
  final double? transportScore;
  final int? schools;
  final int? hospitals;
  final int? averagePricePsf;
  final double? rentalYield;
  final double? priceGrowth;
  final List<double> priceHistory;
  final String? snapshotDate;
  final String source;
  final String? sourceUrl;
  final int? populationYear;
  final int? incomeYear;
  final int? crimeYear;
  final int? educationYear;
  final int? transportYear;
  final DateTime? retrievedAt;
  final bool isGovernmentProfile;

  double? get infrastructureScore {
    final education = schools;
    final transport = transportScore;
    final connectivity = connectivityScore;
    if (education == null && transport == null && connectivity == null) {
      return null;
    }
    final scores = <double>[
      if (education != null) (education / 130 * 100).clamp(0, 100).toDouble(),
      if (transport != null) transport.clamp(0, 100).toDouble(),
      if (connectivity != null) connectivity.clamp(0, 100).toDouble(),
    ];
    return scores.reduce((sum, value) => sum + value) / scores.length;
  }

  bool get hasPriceHistory =>
      priceHistory.length >= 2 && priceHistory.every((value) => value > 0);

  factory AreaData.fromJson(Map<String, dynamic> json) {
    return AreaData(
      id: json['id'] as String,
      name: json['name'] as String,
      state: json['state'] as String,
      population: _intFromJson(json['population']),
      populationGrowth: _doubleFromJson(json['populationGrowth']),
      medianIncome: _intFromJson(json['medianIncome']),
      safetyScore: _doubleFromJson(json['safetyScore']),
      connectivityScore: _doubleFromJson(json['connectivityScore']),
      transportScore: _doubleFromJson(json['transportScore']),
      schools: _intFromJson(json['schools']),
      hospitals: _intFromJson(json['hospitals']),
      averagePricePsf: _intFromJson(json['averagePricePsf']),
      rentalYield: _doubleFromJson(json['rentalYield']),
      priceGrowth: _doubleFromJson(json['priceGrowth']),
      priceHistory: (json['priceHistory'] as List<dynamic>? ?? const [])
          .map((value) => (value as num).toDouble())
          .toList(),
      snapshotDate: json['snapshotDate'] as String?,
      source: json['source'] as String? ?? 'Static metadata',
    );
  }

  factory AreaData.fromProfile(AreaProfile profile, {AreaData? fallback}) {
    final canonicalProfile = profile.canonicalized();
    final population = profile.population;
    final crimeCount = profile.crimeCount;
    final crimeRate =
        population == null || population <= 0 || crimeCount == null
        ? null
        : crimeCount / population * 100000;
    final safetyScore = crimeRate == null
        ? null
        : (100 - crimeRate / 35).clamp(45, 95).toDouble();
    final transportCount = profile.transportStopCount;
    final transportScore = transportCount == null
        ? null
        : (transportCount / 2).clamp(35, 100).toDouble();

    return AreaData(
      id: canonicalProfile.areaId,
      name: canonicalProfile.district,
      state: canonicalProfile.state,
      population: population,
      populationGrowth: null,
      medianIncome: profile.medianHouseholdIncome?.round(),
      safetyScore: safetyScore,
      connectivityScore: null,
      transportScore: transportScore,
      schools: profile.educationInstitutionCount,
      hospitals: null,
      averagePricePsf: null,
      rentalYield: null,
      priceGrowth: null,
      priceHistory: const [],
      snapshotDate: profile.dataYear?.toString() ?? fallback?.snapshotDate,
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

  factory AreaData.unavailable(String areaId) {
    final parts = areaId.split('_');
    final name = parts.isEmpty
        ? 'Unknown area'
        : parts.map(_titleCase).join(' ');
    return AreaData(id: areaId, name: name, state: 'Unknown');
  }

  static int? _intFromJson(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.round();
    }
    return int.tryParse(value.toString().replaceAll(',', '').trim());
  }

  static double? _doubleFromJson(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value.toString().replaceAll(',', '').trim());
  }

  static String _titleCase(String value) {
    if (value.isEmpty) {
      return value;
    }
    return '${value[0].toUpperCase()}${value.substring(1).toLowerCase()}';
  }
}
