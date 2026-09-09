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
    this.hospitalBeds = 0,
    this.transportStopCount = 0,
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
    this.hospitalYear,
    this.transportYear,
    this.marketPricePeriods = const [],
    this.marketPriceHistoryByType = const {},
    this.marketPricePeriodsByType = const {},
    this.medianResidentialPrice,
    this.marketPriceYear,
    this.transactionCount,
    this.previousTransactionCount,
    this.transactionValueMillion,
    this.previousTransactionValueMillion,
    this.marketPeriod,
    this.marketSourceUrl,
    this.marketRetrievedAt,
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
  final int hospitalBeds;
  final int transportStopCount;
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
  final int? hospitalYear;
  final int? transportYear;
  final List<String> marketPricePeriods;
  final Map<String, List<double>> marketPriceHistoryByType;
  final Map<String, List<String>> marketPricePeriodsByType;
  final double? medianResidentialPrice;
  final int? marketPriceYear;
  final int? transactionCount;
  final int? previousTransactionCount;
  final double? transactionValueMillion;
  final double? previousTransactionValueMillion;
  final String? marketPeriod;
  final String? marketSourceUrl;
  final DateTime? marketRetrievedAt;
  final DateTime? retrievedAt;

  bool get hasMarketPrice => medianResidentialPrice != null;

  bool get hasMarketHistory =>
      marketPricePeriods.length == priceHistory.length && priceHistory.length >= 2;

  List<String> get marketPropertyTypes {
    final types = marketPriceHistoryByType.keys
        .where((type) {
          final values = marketPriceHistoryByType[type] ?? const [];
          final periods = marketPricePeriodsByType[type] ?? const [];
          return values.isNotEmpty && values.length == periods.length;
        })
        .toList()
      ..sort();
    return types;
  }

  List<double> priceHistoryFor(String propertyType) =>
      propertyType == 'All residential'
      ? priceHistory
      : marketPriceHistoryByType[propertyType] ?? const [];

  List<String> pricePeriodsFor(String propertyType) =>
      propertyType == 'All residential'
      ? marketPricePeriods
      : marketPricePeriodsByType[propertyType] ?? const [];

  double? latestPriceFor(String propertyType) {
    if (propertyType == 'All residential') return medianResidentialPrice;
    final values = priceHistoryFor(propertyType);
    return values.isEmpty ? null : values.last;
  }

  bool hasPriceHistoryFor(String propertyType) {
    final values = priceHistoryFor(propertyType);
    final periods = pricePeriodsFor(propertyType);
    return values.length >= 2 && values.length == periods.length;
  }

  double? priceGrowthFor(String propertyType) {
    final values = priceHistoryFor(propertyType);
    if (values.length < 2 || values[values.length - 2] == 0) return null;
    return (values.last - values[values.length - 2]) /
        values[values.length - 2] *
        100;
  }

  double? get transactionVolumeGrowth {
    final current = transactionCount;
    final previous = previousTransactionCount;
    if (current == null || previous == null || previous <= 0) return null;
    return (current - previous) / previous * 100;
  }

  double? get transactionValueGrowth {
    final current = transactionValueMillion;
    final previous = previousTransactionValueMillion;
    if (current == null || previous == null || previous <= 0) return null;
    return (current - previous) / previous * 100;
  }

  double? get marketDemandScore {
    final volume = transactionVolumeGrowth;
    final value = transactionValueGrowth;
    if (volume == null || value == null) return null;
    double normalise(double growth) =>
        ((growth.clamp(-20, 20) + 20) / 40 * 100).toDouble();
    return (normalise(volume) * 0.60 + normalise(value) * 0.40)
        .clamp(0, 100)
        .toDouble();
  }
  final bool isGovernmentProfile;

  double get infrastructureScore {
    if (population <= 0) return 0;

    var weightedScore = 0.0;
    var availableWeight = 0.0;
    if (educationYear != null) {
      final schoolsPer10k = schools / population * 10000;
      final schoolScore = (schoolsPer10k / 1.5 * 100)
          .clamp(0, 100)
          .toDouble();
      weightedScore += schoolScore * 0.35;
      availableWeight += 0.35;
    }
    if (hospitalYear != null) {
      final bedsPer10k = hospitalBeds / population * 10000;
      final bedScore = (bedsPer10k / 20 * 100)
          .clamp(0, 100)
          .toDouble();
      weightedScore += bedScore * 0.35;
      availableWeight += 0.35;
    }
    if (transportYear != null) {
      weightedScore += transportScore.clamp(0, 100).toDouble() * 0.30;
      availableWeight += 0.30;
    }
    if (availableWeight == 0) return 0;
    return (weightedScore / availableWeight).clamp(0, 100).toDouble();
  }

  Map<String, dynamic> toCacheJson() => {
    'id': id,
    'name': name,
    'state': state,
    'population': population,
    'populationGrowth': populationGrowth,
    'medianIncome': medianIncome,
    'safetyScore': safetyScore,
    'connectivityScore': connectivityScore,
    'transportScore': transportScore,
    'schools': schools,
    'hospitals': hospitals,
    'hospitalBeds': hospitalBeds,
    'transportStopCount': transportStopCount,
    'averagePricePsf': averagePricePsf,
    'rentalYield': rentalYield,
    'priceGrowth': priceGrowth,
    'priceHistory': priceHistory,
    'snapshotDate': snapshotDate,
    'source': source,
    'sourceUrl': sourceUrl,
    'populationYear': populationYear,
    'incomeYear': incomeYear,
    'crimeYear': crimeYear,
    'educationYear': educationYear,
    'hospitalYear': hospitalYear,
    'transportYear': transportYear,
    'marketPricePeriods': marketPricePeriods,
    'marketPriceHistoryByType': marketPriceHistoryByType,
    'marketPricePeriodsByType': marketPricePeriodsByType,
    'medianResidentialPrice': medianResidentialPrice,
    'marketPriceYear': marketPriceYear,
    'transactionCount': transactionCount,
    'previousTransactionCount': previousTransactionCount,
    'transactionValueMillion': transactionValueMillion,
    'previousTransactionValueMillion': previousTransactionValueMillion,
    'marketPeriod': marketPeriod,
    'marketSourceUrl': marketSourceUrl,
    'marketRetrievedAt': marketRetrievedAt?.toIso8601String(),
    'retrievedAt': retrievedAt?.toIso8601String(),
    'isGovernmentProfile': isGovernmentProfile,
  };

  factory AreaData.fromCacheJson(Map<String, dynamic> json) {
    int integer(String key, [int fallback = 0]) =>
        (json[key] as num?)?.round() ?? fallback;
    double decimal(String key, [double fallback = 0]) =>
        (json[key] as num?)?.toDouble() ?? fallback;
    int? optionalInteger(String key) => (json[key] as num?)?.round();
    double? optionalDecimal(String key) => (json[key] as num?)?.toDouble();
    DateTime? dateTime(String key) {
      final value = json[key]?.toString();
      return value == null ? null : DateTime.tryParse(value);
    }
    Map<String, List<double>> doubleListMap(String key) {
      final value = json[key];
      if (value is! Map) return const {};
      return {
        for (final entry in value.entries)
          entry.key.toString(): (entry.value as List<dynamic>? ?? const [])
              .whereType<num>()
              .map((item) => item.toDouble())
              .toList(),
      };
    }
    Map<String, List<String>> stringListMap(String key) {
      final value = json[key];
      if (value is! Map) return const {};
      return {
        for (final entry in value.entries)
          entry.key.toString(): (entry.value as List<dynamic>? ?? const [])
              .map((item) => item.toString())
              .toList(),
      };
    }

    return AreaData(
      id: json['id'] as String,
      name: json['name'] as String,
      state: json['state'] as String,
      population: integer('population'),
      populationGrowth: decimal('populationGrowth'),
      medianIncome: integer('medianIncome'),
      safetyScore: decimal('safetyScore'),
      connectivityScore: decimal('connectivityScore'),
      transportScore: decimal('transportScore'),
      schools: integer('schools'),
      hospitals: integer('hospitals'),
      hospitalBeds: integer('hospitalBeds'),
      transportStopCount: integer('transportStopCount'),
      averagePricePsf: integer('averagePricePsf'),
      rentalYield: decimal('rentalYield'),
      priceGrowth: decimal('priceGrowth'),
      priceHistory: (json['priceHistory'] as List<dynamic>? ?? const [])
          .map((value) => (value as num).toDouble())
          .toList(),
      snapshotDate: json['snapshotDate']?.toString() ?? '',
      source: json['source']?.toString() ?? 'SQLite cache',
      sourceUrl: json['sourceUrl']?.toString(),
      populationYear: optionalInteger('populationYear'),
      incomeYear: optionalInteger('incomeYear'),
      crimeYear: optionalInteger('crimeYear'),
      educationYear: optionalInteger('educationYear'),
      hospitalYear: optionalInteger('hospitalYear'),
      transportYear: optionalInteger('transportYear'),
      marketPricePeriods:
          (json['marketPricePeriods'] as List<dynamic>? ?? const [])
              .map((value) => value.toString())
              .toList(),
      marketPriceHistoryByType: doubleListMap('marketPriceHistoryByType'),
      marketPricePeriodsByType: stringListMap('marketPricePeriodsByType'),
      medianResidentialPrice: optionalDecimal('medianResidentialPrice'),
      marketPriceYear: optionalInteger('marketPriceYear'),
      transactionCount: optionalInteger('transactionCount'),
      previousTransactionCount: optionalInteger('previousTransactionCount'),
      transactionValueMillion: optionalDecimal('transactionValueMillion'),
      previousTransactionValueMillion:
          optionalDecimal('previousTransactionValueMillion'),
      marketPeriod: json['marketPeriod']?.toString(),
      marketSourceUrl: json['marketSourceUrl']?.toString(),
      marketRetrievedAt: dateTime('marketRetrievedAt'),
      retrievedAt: dateTime('retrievedAt'),
      isGovernmentProfile: json['isGovernmentProfile'] as bool? ?? false,
    );
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
      transportStopCount: (json['transportStopCount'] as num?)?.round() ?? 0,
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
        ? 0.0
        : (100 - crimeRate / 35).clamp(45, 95).toDouble();
    final schoolCount =
        profile.educationInstitutionCount ?? fallback?.schools ?? 0;
    final transportCount =
        profile.transportStopCount ?? fallback?.transportScore.round() ?? 0;
    final transportScore = profile.transportStopCount == null
        ? fallback?.transportScore ?? 0.0
        : population <= 0
        ? 0.0
        : ((transportCount / population * 10000) * 100)
              .clamp(0, 100)
              .toDouble();

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
      hospitalBeds: profile.hospitalBedCount ?? fallback?.hospitalBeds ?? 0,
      transportStopCount:
          profile.transportStopCount ?? fallback?.transportStopCount ?? 0,
      averagePricePsf: fallback?.averagePricePsf ?? 0,
      rentalYield: fallback?.rentalYield ?? 0,
      priceGrowth: profile.marketPriceHistory.isNotEmpty
          ? _marketGrowth(profile) ?? 0
          : fallback?.priceGrowth ?? 0,
      priceHistory: profile.marketPriceHistory.isNotEmpty
          ? profile.marketPriceHistory
          : fallback?.priceHistory ?? const [0, 0, 0, 0, 0, 0, 0],
      snapshotDate: (profile.dataYear ?? fallback?.snapshotDate ?? '')
          .toString(),
      source: profile.source ?? 'OpenDOSM; data.gov.my',
      sourceUrl: profile.sourceUrl,
      populationYear: profile.populationYear ?? fallback?.populationYear,
      incomeYear: profile.incomeYear ?? fallback?.incomeYear,
      crimeYear: profile.crimeCount == null ? null : profile.crimeYear,
      educationYear: profile.educationYear ?? fallback?.educationYear,
      hospitalYear: profile.hospitalYear ?? fallback?.hospitalYear,
      transportYear: profile.transportYear ?? fallback?.transportYear,
      marketPricePeriods: profile.marketPricePeriods.isNotEmpty
          ? profile.marketPricePeriods
          : fallback?.marketPricePeriods ?? const [],
      marketPriceHistoryByType: profile.marketPriceHistoryByType.isNotEmpty
          ? profile.marketPriceHistoryByType
          : fallback?.marketPriceHistoryByType ?? const {},
      marketPricePeriodsByType: profile.marketPricePeriodsByType.isNotEmpty
          ? profile.marketPricePeriodsByType
          : fallback?.marketPricePeriodsByType ?? const {},
      medianResidentialPrice:
          profile.medianResidentialPrice ?? fallback?.medianResidentialPrice,
      marketPriceYear: profile.marketPriceYear ?? fallback?.marketPriceYear,
      transactionCount: profile.transactionCount ?? fallback?.transactionCount,
      previousTransactionCount:
          profile.previousTransactionCount ?? fallback?.previousTransactionCount,
      transactionValueMillion:
          profile.transactionValueMillion ?? fallback?.transactionValueMillion,
      previousTransactionValueMillion:
          profile.previousTransactionValueMillion ??
          fallback?.previousTransactionValueMillion,
      marketPeriod: profile.marketPeriod ?? fallback?.marketPeriod,
      marketSourceUrl: profile.marketSourceUrl ?? fallback?.marketSourceUrl,
      marketRetrievedAt:
          profile.marketRetrievedAt ?? fallback?.marketRetrievedAt,
      retrievedAt: profile.retrievedAt,
      isGovernmentProfile: true,
    );
  }

  static double? _marketGrowth(AreaProfile profile) {
    final values = profile.marketPriceHistory;
    if (values.length < 2 || values[values.length - 2] == 0) return null;
    return (values.last - values[values.length - 2]) /
        values[values.length - 2] *
        100;
  }

  static String _normaliseId(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
  }
}
