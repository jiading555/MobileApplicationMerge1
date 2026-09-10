import 'area_profile.dart';

class AreaData {
  static const double safetyCrimeRateCeilingPer100k = 2000;
  static const double schoolsPer10kAtFullScore = 1.5;
  static const double hospitalBedsPer10kAtFullScore = 20;
  static const double transportStopsPer10kAtFullScore = 5;
  static const double marketGrowthFloor = -20;
  static const double marketGrowthCeiling = 20;

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
    this.hospitalBeds,
    this.transportStopCount,
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
    this.hospitalYear,
    this.transportYear,
    this.marketPricePeriods = const [],
    this.marketPriceHistoryByType = const {},
    this.marketPricePeriodsByType = const {},
    this.marketAreaPriceHistoryByType = const {},
    this.marketAreaPricePeriodsByType = const {},
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
  final int? population;
  final double? populationGrowth;
  final int? medianIncome;
  final double? safetyScore;
  final double? connectivityScore;
  final double? transportScore;
  final int? schools;
  final int? hospitals;
  final int? hospitalBeds;
  final int? transportStopCount;
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
  final int? hospitalYear;
  final int? transportYear;
  final List<String> marketPricePeriods;
  final Map<String, List<double>> marketPriceHistoryByType;
  final Map<String, List<String>> marketPricePeriodsByType;
  final Map<String, Map<String, List<double>>> marketAreaPriceHistoryByType;
  final Map<String, Map<String, List<String>>> marketAreaPricePeriodsByType;
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
  final bool isGovernmentProfile;

  bool get hasMarketPrice => medianResidentialPrice != null;

  bool get hasMarketHistory =>
      marketPricePeriods.length == priceHistory.length &&
      priceHistory.length >= 2;

  bool get hasPriceHistory =>
      priceHistory.length >= 2 && priceHistory.every((value) => value > 0);

  bool get hasCompleteInfrastructureData {
    final populationValue = population;
    return populationValue != null &&
        populationValue > 0 &&
        educationYear != null &&
        schools != null &&
        schools! >= 0 &&
        hospitalYear != null &&
        hospitalBeds != null &&
        hospitalBeds! >= 0 &&
        transportYear != null &&
        transportScore != null;
  }

  double? get infrastructureScore {
    if (!hasCompleteInfrastructureData) return null;

    final populationValue = population!;
    final schoolsPer10k = schools! / populationValue * 10000;
    final bedsPer10k = hospitalBeds! / populationValue * 10000;
    final schoolScore =
        (schoolsPer10k / schoolsPer10kAtFullScore * 100)
            .clamp(0, 100)
            .toDouble();
    final bedScore =
        (bedsPer10k / hospitalBedsPer10kAtFullScore * 100)
            .clamp(0, 100)
            .toDouble();
    final transitScore = transportScore!.clamp(0, 100).toDouble();

    return (schoolScore * 0.35 + bedScore * 0.35 + transitScore * 0.30)
        .clamp(0, 100)
        .toDouble();
  }

  List<String> get marketPropertyTypes {
    final types = marketPriceHistoryByType.keys.where((type) {
      final values = marketPriceHistoryByType[type] ?? const [];
      final periods = marketPricePeriodsByType[type] ?? const [];
      return values.isNotEmpty && values.length == periods.length;
    }).toList()..sort();
    return types;
  }

  List<String> get marketAreas {
    final areas = marketAreaPriceHistoryByType.keys.where((marketArea) {
      final histories = marketAreaPriceHistoryByType[marketArea];
      return histories != null &&
          histories.values.any((values) => values.isNotEmpty);
    }).toList()..sort();
    return areas;
  }

  List<String> propertyTypesForMarketArea(String marketArea) {
    if (marketArea == 'Overall') return marketPropertyTypes;
    final histories = marketAreaPriceHistoryByType[marketArea] ?? const {};
    final periods = marketAreaPricePeriodsByType[marketArea] ?? const {};
    final types = histories.keys.where((type) {
      final values = histories[type] ?? const [];
      final labels = periods[type] ?? const [];
      return values.isNotEmpty && values.length == labels.length;
    }).toList()..sort();
    return types;
  }

  List<double> priceHistoryFor(
    String propertyType, {
    String marketArea = 'Overall',
  }) {
    if (marketArea != 'Overall') {
      return marketAreaPriceHistoryByType[marketArea]?[propertyType] ??
          const [];
    }
    return propertyType == 'All residential'
        ? priceHistory
        : marketPriceHistoryByType[propertyType] ?? const [];
  }

  List<String> pricePeriodsFor(
    String propertyType, {
    String marketArea = 'Overall',
  }) {
    if (marketArea != 'Overall') {
      return marketAreaPricePeriodsByType[marketArea]?[propertyType] ??
          const [];
    }
    return propertyType == 'All residential'
        ? marketPricePeriods
        : marketPricePeriodsByType[propertyType] ?? const [];
  }

  double? latestPriceFor(String propertyType, {String marketArea = 'Overall'}) {
    if (marketArea == 'Overall' && propertyType == 'All residential') {
      return medianResidentialPrice;
    }
    final values = priceHistoryFor(propertyType, marketArea: marketArea);
    return values.isEmpty ? null : values.last;
  }

  bool hasPriceHistoryFor(
    String propertyType, {
    String marketArea = 'Overall',
  }) {
    final values = priceHistoryFor(propertyType, marketArea: marketArea);
    final periods = pricePeriodsFor(propertyType, marketArea: marketArea);
    return values.length >= 2 && values.length == periods.length;
  }

  double? priceGrowthFor(String propertyType, {String marketArea = 'Overall'}) {
    final values = priceHistoryFor(propertyType, marketArea: marketArea);
    if (values.length < 2 || values[values.length - 2] == 0) return null;
    return (values.last - values[values.length - 2]) /
        values[values.length - 2] *
        100;
  }

  double? get transactionVolumeGrowth {
    final current = transactionCount;
    final previous = previousTransactionCount;
    if (current == null || current < 0 || previous == null || previous <= 0) {
      return null;
    }
    return (current - previous) / previous * 100;
  }

  double? get transactionValueGrowth {
    final current = transactionValueMillion;
    final previous = previousTransactionValueMillion;
    if (current == null || current < 0 || previous == null || previous <= 0) {
      return null;
    }
    return (current - previous) / previous * 100;
  }

  double? get marketDemandScore {
    final volume = transactionVolumeGrowth;
    final value = transactionValueGrowth;
    if (volume == null || value == null) return null;

    double normalise(double growth) {
      final capped = growth.clamp(marketGrowthFloor, marketGrowthCeiling);
      return ((capped - marketGrowthFloor) /
              (marketGrowthCeiling - marketGrowthFloor) *
              100)
          .toDouble();
    }

    return (normalise(volume) * 0.60 + normalise(value) * 0.40)
        .clamp(0, 100)
        .toDouble();
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
    'marketAreaPriceHistoryByType': marketAreaPriceHistoryByType,
    'marketAreaPricePeriodsByType': marketAreaPricePeriodsByType,
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
    return AreaData(
      id: json['id']?.toString() ?? 'unknown',
      name: json['name']?.toString() ?? 'Unknown area',
      state: json['state']?.toString() ?? 'Unknown',
      population: _intFromJson(json['population']),
      populationGrowth: _doubleFromJson(json['populationGrowth']),
      medianIncome: _intFromJson(json['medianIncome']),
      safetyScore: _doubleFromJson(json['safetyScore']),
      connectivityScore: _doubleFromJson(json['connectivityScore']),
      transportScore: _doubleFromJson(json['transportScore']),
      schools: _intFromJson(json['schools']),
      hospitals: _intFromJson(json['hospitals']),
      hospitalBeds: _intFromJson(json['hospitalBeds']),
      transportStopCount: _intFromJson(json['transportStopCount']),
      averagePricePsf: _intFromJson(json['averagePricePsf']),
      rentalYield: _doubleFromJson(json['rentalYield']),
      priceGrowth: _doubleFromJson(json['priceGrowth']),
      priceHistory: _doubleListFromJson(json['priceHistory']),
      snapshotDate: json['snapshotDate']?.toString(),
      source: json['source']?.toString() ?? 'SQLite cache',
      sourceUrl: json['sourceUrl']?.toString(),
      populationYear: _intFromJson(json['populationYear']),
      incomeYear: _intFromJson(json['incomeYear']),
      crimeYear: _intFromJson(json['crimeYear']),
      educationYear: _intFromJson(json['educationYear']),
      hospitalYear: _intFromJson(json['hospitalYear']),
      transportYear: _intFromJson(json['transportYear']),
      marketPricePeriods: _stringListFromJson(json['marketPricePeriods']),
      marketPriceHistoryByType: _doubleListMapFromJson(
        json['marketPriceHistoryByType'],
      ),
      marketPricePeriodsByType: _stringListMapFromJson(
        json['marketPricePeriodsByType'],
      ),
      marketAreaPriceHistoryByType: _nestedDoubleListMapFromJson(
        json['marketAreaPriceHistoryByType'],
      ),
      marketAreaPricePeriodsByType: _nestedStringListMapFromJson(
        json['marketAreaPricePeriodsByType'],
      ),
      medianResidentialPrice: _doubleFromJson(json['medianResidentialPrice']),
      marketPriceYear: _intFromJson(json['marketPriceYear']),
      transactionCount: _intFromJson(json['transactionCount']),
      previousTransactionCount: _intFromJson(json['previousTransactionCount']),
      transactionValueMillion: _doubleFromJson(json['transactionValueMillion']),
      previousTransactionValueMillion: _doubleFromJson(
        json['previousTransactionValueMillion'],
      ),
      marketPeriod: json['marketPeriod']?.toString(),
      marketSourceUrl: json['marketSourceUrl']?.toString(),
      marketRetrievedAt: _dateTimeFromJson(json['marketRetrievedAt']),
      retrievedAt: _dateTimeFromJson(json['retrievedAt']),
      isGovernmentProfile: json['isGovernmentProfile'] as bool? ?? false,
    );
  }

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
      hospitalBeds: _intFromJson(json['hospitalBeds']),
      transportStopCount: _intFromJson(json['transportStopCount']),
      averagePricePsf: _intFromJson(json['averagePricePsf']),
      rentalYield: _doubleFromJson(json['rentalYield']),
      priceGrowth: _doubleFromJson(json['priceGrowth']),
      priceHistory: _doubleListFromJson(json['priceHistory']),
      snapshotDate: json['snapshotDate'] as String?,
      source: json['source'] as String? ?? 'Static metadata',
      sourceUrl: json['sourceUrl'] as String?,
      retrievedAt: _dateTimeFromJson(json['retrievedAt']),
    );
  }

  factory AreaData.fromProfile(AreaProfile profile, {AreaData? fallback}) {
    final canonicalProfile = profile.canonicalized();
    final population = canonicalProfile.population;
    final crimeCount = canonicalProfile.crimeCount;
    final crimeRate =
        population == null ||
            population <= 0 ||
            crimeCount == null ||
            crimeCount < 0 ||
            canonicalProfile.crimeYear == null
        ? null
        : crimeCount / population * 100000;
    final safetyScore = crimeRate == null
        ? null
        : (100 * (1 - crimeRate / safetyCrimeRateCeilingPer100k))
              .clamp(0, 100)
              .toDouble();
    final transportCount = canonicalProfile.transportStopCount;
    final transportScore =
        transportCount == null ||
            transportCount < 0 ||
            population == null ||
            population <= 0 ||
            canonicalProfile.transportYear == null
        ? null
        : ((transportCount / population * 10000) /
                  transportStopsPer10kAtFullScore *
                  100)
              .clamp(0, 100)
              .toDouble();

    return AreaData(
      id: canonicalProfile.areaId,
      name: canonicalProfile.district,
      state: canonicalProfile.state,
      population: population,
      populationGrowth: null,
      medianIncome: canonicalProfile.medianHouseholdIncome?.round(),
      safetyScore: safetyScore,
      connectivityScore: transportScore,
      transportScore: transportScore,
      schools: canonicalProfile.educationInstitutionCount,
      hospitals: null,
      hospitalBeds: canonicalProfile.hospitalBedCount,
      transportStopCount: canonicalProfile.transportStopCount,
      averagePricePsf: null,
      rentalYield: null,
      priceGrowth: canonicalProfile.marketPriceHistory.isEmpty
          ? null
          : _marketGrowth(canonicalProfile),
      priceHistory: canonicalProfile.marketPriceHistory,
      snapshotDate:
          canonicalProfile.dataYear?.toString() ?? fallback?.snapshotDate,
      source: canonicalProfile.source ?? 'OpenDOSM; data.gov.my',
      sourceUrl: canonicalProfile.sourceUrl,
      populationYear: canonicalProfile.populationYear,
      incomeYear: canonicalProfile.incomeYear,
      crimeYear: canonicalProfile.crimeCount == null
          ? null
          : canonicalProfile.crimeYear,
      educationYear: canonicalProfile.educationYear,
      hospitalYear: canonicalProfile.hospitalYear,
      transportYear: canonicalProfile.transportYear,
      marketPricePeriods: canonicalProfile.marketPricePeriods,
      marketPriceHistoryByType: canonicalProfile.marketPriceHistoryByType,
      marketPricePeriodsByType: canonicalProfile.marketPricePeriodsByType,
      marketAreaPriceHistoryByType:
          canonicalProfile.marketAreaPriceHistoryByType,
      marketAreaPricePeriodsByType:
          canonicalProfile.marketAreaPricePeriodsByType,
      medianResidentialPrice: canonicalProfile.medianResidentialPrice,
      marketPriceYear: canonicalProfile.marketPriceYear,
      transactionCount: canonicalProfile.transactionCount,
      previousTransactionCount: canonicalProfile.previousTransactionCount,
      transactionValueMillion: canonicalProfile.transactionValueMillion,
      previousTransactionValueMillion:
          canonicalProfile.previousTransactionValueMillion,
      marketPeriod: canonicalProfile.marketPeriod,
      marketSourceUrl: canonicalProfile.marketSourceUrl,
      marketRetrievedAt: canonicalProfile.marketRetrievedAt,
      retrievedAt: canonicalProfile.retrievedAt,
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

  static double? _marketGrowth(AreaProfile profile) {
    final values = profile.marketPriceHistory;
    if (values.length < 2 || values[values.length - 2] == 0) return null;
    return (values.last - values[values.length - 2]) /
        values[values.length - 2] *
        100;
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

  static List<double> _doubleListFromJson(Object? value) {
    if (value is! List) return const [];
    return value.map(_doubleFromJson).whereType<double>().toList();
  }

  static List<String> _stringListFromJson(Object? value) {
    if (value is! List) return const [];
    return value.map((item) => item.toString()).toList();
  }

  static Map<String, List<double>> _doubleListMapFromJson(Object? value) {
    if (value is! Map) return const {};
    return {
      for (final entry in value.entries)
        entry.key.toString(): _doubleListFromJson(entry.value),
    };
  }

  static Map<String, List<String>> _stringListMapFromJson(Object? value) {
    if (value is! Map) return const {};
    return {
      for (final entry in value.entries)
        entry.key.toString(): _stringListFromJson(entry.value),
    };
  }

  static Map<String, Map<String, List<double>>> _nestedDoubleListMapFromJson(
    Object? value,
  ) {
    if (value is! Map) return const {};
    return {
      for (final entry in value.entries)
        entry.key.toString(): _doubleListMapFromJson(entry.value),
    };
  }

  static Map<String, Map<String, List<String>>> _nestedStringListMapFromJson(
    Object? value,
  ) {
    if (value is! Map) return const {};
    return {
      for (final entry in value.entries)
        entry.key.toString(): _stringListMapFromJson(entry.value),
    };
  }

  static DateTime? _dateTimeFromJson(Object? value) {
    if (value == null) {
      return null;
    }
    return DateTime.tryParse(value.toString());
  }

  static String _titleCase(String value) {
    if (value.isEmpty) {
      return value;
    }
    return '${value[0].toUpperCase()}${value.substring(1).toLowerCase()}';
  }
}
