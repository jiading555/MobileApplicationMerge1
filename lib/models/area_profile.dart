import '../core/utils/location_normalizer.dart';

class AreaProfile {
  const AreaProfile({
    required this.areaId,
    required this.state,
    required this.district,
    this.population,
    this.populationYear,
    this.medianHouseholdIncome,
    this.incomeYear,
    this.crimeCount,
    this.crimeYear,
    this.educationInstitutionCount,
    this.educationYear,
    this.hospitalBedCount,
    this.hospitalYear,
    this.transportStopCount,
    this.transportYear,
    this.marketPriceHistory = const [],
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
    this.dataYear,
    this.source,
    this.sourceUrl,
    this.retrievedAt,
  });

  final String areaId;
  final String state;
  final String district;
  final int? population;
  final int? populationYear;
  final double? medianHouseholdIncome;
  final int? incomeYear;
  final int? crimeCount;
  final int? crimeYear;
  final int? educationInstitutionCount;
  final int? educationYear;
  final int? hospitalBedCount;
  final int? hospitalYear;
  final int? transportStopCount;
  final int? transportYear;
  final List<double> marketPriceHistory;
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
  final int? dataYear;
  final String? source;
  final String? sourceUrl;
  final DateTime? retrievedAt;

  AreaProfile copyWith({
    String? areaId,
    String? state,
    String? district,
    int? population,
    int? populationYear,
    double? medianHouseholdIncome,
    int? incomeYear,
    int? crimeCount,
    int? crimeYear,
    int? educationInstitutionCount,
    int? educationYear,
    int? hospitalBedCount,
    int? hospitalYear,
    int? transportStopCount,
    int? transportYear,
    List<double>? marketPriceHistory,
    List<String>? marketPricePeriods,
    Map<String, List<double>>? marketPriceHistoryByType,
    Map<String, List<String>>? marketPricePeriodsByType,
    Map<String, Map<String, List<double>>>? marketAreaPriceHistoryByType,
    Map<String, Map<String, List<String>>>? marketAreaPricePeriodsByType,
    double? medianResidentialPrice,
    int? marketPriceYear,
    int? transactionCount,
    int? previousTransactionCount,
    double? transactionValueMillion,
    double? previousTransactionValueMillion,
    String? marketPeriod,
    String? marketSourceUrl,
    DateTime? marketRetrievedAt,
    int? dataYear,
    String? source,
    String? sourceUrl,
    DateTime? retrievedAt,
  }) {
    return AreaProfile(
      areaId: areaId ?? this.areaId,
      state: state ?? this.state,
      district: district ?? this.district,
      population: population ?? this.population,
      populationYear: populationYear ?? this.populationYear,
      medianHouseholdIncome:
          medianHouseholdIncome ?? this.medianHouseholdIncome,
      incomeYear: incomeYear ?? this.incomeYear,
      crimeCount: crimeCount ?? this.crimeCount,
      crimeYear: crimeYear ?? this.crimeYear,
      educationInstitutionCount:
          educationInstitutionCount ?? this.educationInstitutionCount,
      educationYear: educationYear ?? this.educationYear,
      hospitalBedCount: hospitalBedCount ?? this.hospitalBedCount,
      hospitalYear: hospitalYear ?? this.hospitalYear,
      transportStopCount: transportStopCount ?? this.transportStopCount,
      transportYear: transportYear ?? this.transportYear,
      marketPriceHistory: marketPriceHistory ?? this.marketPriceHistory,
      marketPricePeriods: marketPricePeriods ?? this.marketPricePeriods,
      marketPriceHistoryByType:
          marketPriceHistoryByType ?? this.marketPriceHistoryByType,
      marketPricePeriodsByType:
          marketPricePeriodsByType ?? this.marketPricePeriodsByType,
      marketAreaPriceHistoryByType:
          marketAreaPriceHistoryByType ?? this.marketAreaPriceHistoryByType,
      marketAreaPricePeriodsByType:
          marketAreaPricePeriodsByType ?? this.marketAreaPricePeriodsByType,
      medianResidentialPrice:
          medianResidentialPrice ?? this.medianResidentialPrice,
      marketPriceYear: marketPriceYear ?? this.marketPriceYear,
      transactionCount: transactionCount ?? this.transactionCount,
      previousTransactionCount:
          previousTransactionCount ?? this.previousTransactionCount,
      transactionValueMillion:
          transactionValueMillion ?? this.transactionValueMillion,
      previousTransactionValueMillion:
          previousTransactionValueMillion ??
          this.previousTransactionValueMillion,
      marketPeriod: marketPeriod ?? this.marketPeriod,
      marketSourceUrl: marketSourceUrl ?? this.marketSourceUrl,
      marketRetrievedAt: marketRetrievedAt ?? this.marketRetrievedAt,
      dataYear: dataYear ?? this.dataYear,
      source: source ?? this.source,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      retrievedAt: retrievedAt ?? this.retrievedAt,
    );
  }

  AreaProfile canonicalized() {
    final displayState = LocationNormalizer.displayStateName(state);
    final displayDistrict = LocationNormalizer.displayDistrictName(
      district,
      state: displayState,
    );
    return copyWith(
      areaId: LocationNormalizer.canonicalAreaId(displayState, displayDistrict),
      state: displayState,
      district: displayDistrict,
    );
  }

  AreaProfile mergeWith(AreaProfile incoming) {
    final left = canonicalized();
    final right = incoming.canonicalized();
    return AreaProfile(
      areaId: right.areaId,
      state: right.state,
      district: right.district,
      population: right.population ?? left.population,
      populationYear: right.populationYear ?? left.populationYear,
      medianHouseholdIncome:
          right.medianHouseholdIncome ?? left.medianHouseholdIncome,
      incomeYear: right.incomeYear ?? left.incomeYear,
      crimeCount: right.crimeCount ?? left.crimeCount,
      crimeYear: right.crimeYear ?? left.crimeYear,
      educationInstitutionCount:
          right.educationInstitutionCount ?? left.educationInstitutionCount,
      educationYear: right.educationYear ?? left.educationYear,
      hospitalBedCount: right.hospitalBedCount ?? left.hospitalBedCount,
      hospitalYear: right.hospitalYear ?? left.hospitalYear,
      transportStopCount: right.transportStopCount ?? left.transportStopCount,
      transportYear: right.transportYear ?? left.transportYear,
      marketPriceHistory: _preferNonEmptyList(
        left.marketPriceHistory,
        right.marketPriceHistory,
      ),
      marketPricePeriods: _preferNonEmptyList(
        left.marketPricePeriods,
        right.marketPricePeriods,
      ),
      marketPriceHistoryByType: _preferNonEmptyMap(
        left.marketPriceHistoryByType,
        right.marketPriceHistoryByType,
      ),
      marketPricePeriodsByType: _preferNonEmptyMap(
        left.marketPricePeriodsByType,
        right.marketPricePeriodsByType,
      ),
      marketAreaPriceHistoryByType: _preferNonEmptyMap(
        left.marketAreaPriceHistoryByType,
        right.marketAreaPriceHistoryByType,
      ),
      marketAreaPricePeriodsByType: _preferNonEmptyMap(
        left.marketAreaPricePeriodsByType,
        right.marketAreaPricePeriodsByType,
      ),
      medianResidentialPrice:
          right.medianResidentialPrice ?? left.medianResidentialPrice,
      marketPriceYear: _maxInt(left.marketPriceYear, right.marketPriceYear),
      transactionCount: right.transactionCount ?? left.transactionCount,
      previousTransactionCount:
          right.previousTransactionCount ?? left.previousTransactionCount,
      transactionValueMillion:
          right.transactionValueMillion ?? left.transactionValueMillion,
      previousTransactionValueMillion:
          right.previousTransactionValueMillion ??
          left.previousTransactionValueMillion,
      marketPeriod: _preferLatestText(
        left.marketPeriod,
        right.marketPeriod,
        left.marketRetrievedAt,
        right.marketRetrievedAt,
      ),
      marketSourceUrl: _mergeText(left.marketSourceUrl, right.marketSourceUrl),
      marketRetrievedAt: _latestDate(
        left.marketRetrievedAt,
        right.marketRetrievedAt,
      ),
      dataYear: _maxInt(left.dataYear, right.dataYear),
      source: _mergeText(left.source, right.source),
      sourceUrl: _mergeText(left.sourceUrl, right.sourceUrl),
      retrievedAt: _latestDate(left.retrievedAt, right.retrievedAt),
    );
  }

  factory AreaProfile.fromJson(Map<String, dynamic> json) {
    return AreaProfile(
      areaId: _stringFromJson(json['area_id'] ?? json['areaId']),
      state: _stringFromJson(json['state']),
      district: _stringFromJson(json['district']),
      population: _intFromJson(json['population']),
      populationYear: _intFromJson(
        json['population_year'] ?? json['populationYear'],
      ),
      medianHouseholdIncome: _doubleFromJson(
        json['median_household_income'] ?? json['medianHouseholdIncome'],
      ),
      incomeYear: _intFromJson(json['income_year'] ?? json['incomeYear']),
      crimeCount: _intFromJson(json['crime_count'] ?? json['crimeCount']),
      crimeYear: _intFromJson(json['crime_year'] ?? json['crimeYear']),
      educationInstitutionCount: _intFromJson(
        json['education_institution_count'] ??
            json['educationInstitutionCount'],
      ),
      educationYear: _intFromJson(
        json['education_year'] ?? json['educationYear'],
      ),
      hospitalBedCount: _intFromJson(
        json['hospital_bed_count'] ?? json['hospitalBedCount'],
      ),
      hospitalYear: _intFromJson(json['hospital_year'] ?? json['hospitalYear']),
      transportStopCount: _intFromJson(
        json['transport_stop_count'] ?? json['transportStopCount'],
      ),
      transportYear: _intFromJson(
        json['transport_year'] ?? json['transportYear'],
      ),
      marketPriceHistory: _doubleListFromJson(
        json['market_price_history'] ?? json['marketPriceHistory'],
      ),
      marketPricePeriods: _stringListFromJson(
        json['market_price_periods'] ?? json['marketPricePeriods'],
      ),
      marketPriceHistoryByType: _doubleListMapFromJson(
        json['market_price_history_by_type'] ??
            json['marketPriceHistoryByType'],
      ),
      marketPricePeriodsByType: _stringListMapFromJson(
        json['market_price_periods_by_type'] ??
            json['marketPricePeriodsByType'],
      ),
      marketAreaPriceHistoryByType: _nestedDoubleListMapFromJson(
        json['market_area_price_history_by_type'] ??
            json['marketAreaPriceHistoryByType'],
      ),
      marketAreaPricePeriodsByType: _nestedStringListMapFromJson(
        json['market_area_price_periods_by_type'] ??
            json['marketAreaPricePeriodsByType'],
      ),
      medianResidentialPrice: _doubleFromJson(
        json['median_residential_price'] ?? json['medianResidentialPrice'],
      ),
      marketPriceYear: _intFromJson(
        json['market_price_year'] ?? json['marketPriceYear'],
      ),
      transactionCount: _intFromJson(
        json['transaction_count'] ?? json['transactionCount'],
      ),
      previousTransactionCount: _intFromJson(
        json['previous_transaction_count'] ?? json['previousTransactionCount'],
      ),
      transactionValueMillion: _doubleFromJson(
        json['transaction_value_million'] ?? json['transactionValueMillion'],
      ),
      previousTransactionValueMillion: _doubleFromJson(
        json['previous_transaction_value_million'] ??
            json['previousTransactionValueMillion'],
      ),
      marketPeriod: _nullableStringFromJson(
        json['market_period'] ?? json['marketPeriod'],
      ),
      marketSourceUrl: _nullableStringFromJson(
        json['market_source_url'] ?? json['marketSourceUrl'],
      ),
      marketRetrievedAt: _dateTimeFromJson(
        json['market_retrieved_at'] ?? json['marketRetrievedAt'],
      ),
      dataYear: _intFromJson(json['data_year'] ?? json['dataYear']),
      source: _nullableStringFromJson(json['source']),
      sourceUrl: _nullableStringFromJson(
        json['source_url'] ?? json['sourceUrl'],
      ),
      retrievedAt: _dateTimeFromJson(
        json['retrieved_at'] ?? json['retrievedAt'],
      ),
    );
  }

  Map<String, dynamic> toSupabaseJson({DateTime? updatedAt}) {
    return {
      'area_id': areaId,
      'state': state,
      'district': district,
      'population': population,
      'population_year': populationYear,
      'median_household_income': medianHouseholdIncome,
      'income_year': incomeYear,
      'crime_count': crimeCount,
      'crime_year': crimeYear,
      'education_institution_count': educationInstitutionCount,
      'education_year': educationYear,
      'hospital_bed_count': hospitalBedCount,
      'hospital_year': hospitalYear,
      'transport_stop_count': transportStopCount,
      'transport_year': transportYear,
      'market_price_history': marketPriceHistory,
      'market_price_periods': marketPricePeriods,
      'market_price_history_by_type': marketPriceHistoryByType,
      'market_price_periods_by_type': marketPricePeriodsByType,
      'market_area_price_history_by_type': marketAreaPriceHistoryByType,
      'market_area_price_periods_by_type': marketAreaPricePeriodsByType,
      'median_residential_price': medianResidentialPrice,
      'market_price_year': marketPriceYear,
      'transaction_count': transactionCount,
      'previous_transaction_count': previousTransactionCount,
      'transaction_value_million': transactionValueMillion,
      'previous_transaction_value_million': previousTransactionValueMillion,
      'market_period': marketPeriod,
      'market_source_url': marketSourceUrl,
      'market_retrieved_at': marketRetrievedAt?.toUtc().toIso8601String(),
      'data_year': dataYear,
      'source': source,
      'source_url': sourceUrl,
      'retrieved_at': retrievedAt?.toUtc().toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }

  static String _stringFromJson(Object? value) {
    return value?.toString() ?? '';
  }

  static String? _nullableStringFromJson(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  static int? _intFromJson(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value.toString());
  }

  static double? _doubleFromJson(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value.toString());
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

  static int? _maxInt(int? left, int? right) {
    if (left == null) {
      return right;
    }
    if (right == null) {
      return left;
    }
    return left > right ? left : right;
  }

  static DateTime? _latestDate(DateTime? left, DateTime? right) {
    if (left == null) {
      return right;
    }
    if (right == null) {
      return left;
    }
    return left.isAfter(right) ? left : right;
  }

  static String? _mergeText(String? left, String? right) {
    final values = [
      ...?left?.split(';'),
      ...?right?.split(';'),
    ].map((value) => value.trim()).where((value) => value.isNotEmpty);
    final seen = <String>{};
    final merged = <String>[];
    for (final value in values) {
      if (seen.add(value.toLowerCase())) {
        merged.add(value);
      }
    }
    return merged.isEmpty ? null : merged.join('; ');
  }

  static List<T> _preferNonEmptyList<T>(List<T> left, List<T> right) {
    return right.isNotEmpty ? right : left;
  }

  static Map<K, V> _preferNonEmptyMap<K, V>(Map<K, V> left, Map<K, V> right) {
    return right.isNotEmpty ? right : left;
  }

  static String? _preferLatestText(
    String? left,
    String? right,
    DateTime? leftDate,
    DateTime? rightDate,
  ) {
    if (left == null || left.isEmpty) {
      return right;
    }
    if (right == null || right.isEmpty) {
      return left;
    }
    if (leftDate == null || rightDate == null) {
      return right;
    }
    return rightDate.isAfter(leftDate) ? right : left;
  }
}
